import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:inmobi_ads/src/inmobi_ad_error.dart';
import 'package:inmobi_ads/src/inmobi_ads_base.dart';
import 'package:inmobi_ads/src/inmobi_banner_listener.dart';
import 'package:inmobi_ads/src/inmobi_banner_size.dart';
import 'package:inmobi_ads/src/platform.dart';

/// A banner ad, sized by [size] and filled by the native InMobi SDK.
///
/// The widget always occupies [size], loaded or not. It does not collapse on
/// failure, because a banner slot that changes height when an auction comes
/// back empty reflows the screen under the user's thumb. Wrap it yourself if
/// you want it to disappear — [InMobiBannerListener.onAdFailedToLoad] is the
/// signal.
class InMobiBannerAd extends StatefulWidget {
  /// Creates a banner for [placementId].
  ///
  /// The properties are read once, when the native view is created; changing
  /// them on a later rebuild has no effect. Give the widget a new [key] to
  /// load a different placement or size.
  ///
  /// Throws a [StateError] when built before [InMobiAds.initialize] has
  /// completed.
  const InMobiBannerAd({
    required this.placementId,
    this.size = InMobiBannerSize.banner,
    this.listener,
    this.refreshInterval,
    super.key,
  });

  /// The placement id from the InMobi dashboard.
  final int placementId;

  /// How much room the banner takes, in logical pixels.
  final InMobiBannerSize size;

  /// Where load and interaction events go.
  final InMobiBannerListener? listener;

  /// How often the banner fetches a new creative.
  ///
  /// InMobi's default is 60 seconds and its floor is 20 — a shorter interval is
  /// clamped up by the SDK, not honoured. Pass [Duration.zero] to turn
  /// auto-refresh off entirely and get exactly one creative.
  final Duration? refreshInterval;

  @override
  State<InMobiBannerAd> createState() => _InMobiBannerAdState();
}

class _InMobiBannerAdState extends State<InMobiBannerAd> {
  static const String _viewType = 'inmobi_ads/banner';

  late final int _adId;

  @override
  void initState() {
    super.initState();
    ensureInitialized('banner ad');
    assert(
      !(widget.refreshInterval?.isNegative ?? false),
      'refreshInterval must not be negative; pass Duration.zero for off.',
    );
    _adId = InMobiAdsPlatform.registerAd(_handleEvent);
  }

  @override
  void dispose() {
    InMobiAdsPlatform.unregisterAd(_adId);
    // The native view is torn down by the platform-view host, which disposes
    // the InMobiBanner with it, so there is no disposeAd call to make here.
    super.dispose();
  }

  void _handleEvent(String event, Map<Object?, Object?> arguments) {
    final listener = widget.listener;
    if (listener == null) return;
    switch (event) {
      case 'loaded':
        listener.onAdLoaded?.call();
      case 'loadFailed':
        listener.onAdFailedToLoad?.call(InMobiAdError.fromMap(arguments));
      case 'impression':
        listener.onAdImpression?.call();
      case 'clicked':
        listener.onAdClicked?.call();
    }
  }

  Map<String, Object?> get _creationParams => <String, Object?>{
        'adId': _adId,
        'placementId': widget.placementId,
        // Logical pixels. Android needs these in device pixels and converts on
        // its side, because the density it should use is the one attached to
        // the view's context, not whatever Flutter last reported.
        'width': widget.size.width,
        'height': widget.size.height,
        'refreshIntervalSeconds': _refreshSeconds,
      };

  /// [InMobiBannerAd.refreshInterval] in whole seconds, rounded up.
  ///
  /// Rounded up rather than truncated because zero is this package's "off"
  /// signal: truncating turned a 500 ms request into no refresh at all.
  int? get _refreshSeconds {
    final interval = widget.refreshInterval;
    if (interval == null) return null;
    final micros = interval.inMicroseconds;
    return (micros + Duration.microsecondsPerSecond - 1) ~/
        Duration.microsecondsPerSecond;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size.width,
      height: widget.size.height,
      child: switch (defaultTargetPlatform) {
        TargetPlatform.android => _buildAndroidView(
            Directionality.maybeOf(context) ?? TextDirection.ltr,
          ),
        TargetPlatform.iOS => UiKitView(
            viewType: _viewType,
            creationParams: _creationParams,
            creationParamsCodec: const StandardMessageCodec(),
          ),
        // A banner slot on an unsupported platform renders as empty space of
        // the right size rather than throwing, so a desktop debug run of an
        // app that embeds one still lays out correctly.
        _ => const SizedBox.shrink(),
      },
    );
  }

  /// Hybrid composition, deliberately.
  ///
  /// Ad creatives are WebViews that need real touch targets and their own
  /// input connection. Virtual display — the cheaper mode — mangles both, which
  /// shows up as banners that render correctly and cannot be tapped.
  ///
  /// [layoutDirection] is the ambient one: creatives are web content, and an
  /// RTL app should not have its banner forced LTR.
  Widget _buildAndroidView(TextDirection layoutDirection) {
    return PlatformViewLink(
      viewType: _viewType,
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      ),
      onCreatePlatformView: (params) {
        final controller = PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: _viewType,
          layoutDirection: layoutDirection,
          creationParams: _creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        )..addOnPlatformViewCreatedListener(params.onPlatformViewCreated);
        unawaited(controller.create());
        return controller;
      },
    );
  }
}
