import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:inmobi_ads/src/inmobi_ad_error.dart';
import 'package:inmobi_ads/src/inmobi_ads_base.dart';
import 'package:inmobi_ads/src/platform.dart';

/// A banner size, in logical pixels.
///
/// InMobi does not enforce a fixed set the way AdMob does — a placement serves
/// whatever creative sizes it is configured for — but these three are the ones
/// worth asking for, and a mismatch between the widget's size and the
/// placement's is the usual reason a banner loads and renders blank.
@immutable
class InMobiBannerSize {
  const InMobiBannerSize({required this.width, required this.height});

  /// 320×50. The standard phone banner.
  static const InMobiBannerSize banner =
      InMobiBannerSize(width: 320, height: 50);

  /// 728×90. Tablets only; it will not fit a phone in portrait.
  static const InMobiBannerSize leaderboard =
      InMobiBannerSize(width: 728, height: 90);

  /// 300×250. The in-feed rectangle.
  static const InMobiBannerSize mediumRectangle =
      InMobiBannerSize(width: 300, height: 250);

  final double width;
  final double height;

  @override
  bool operator ==(Object other) =>
      other is InMobiBannerSize &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'InMobiBannerSize(${width}x$height)';
}

/// Events from an [InMobiBannerAd].
///
/// With auto-refresh on — the default — [onAdLoaded] runs again on every
/// refresh, not just the first. Anything you do here should be idempotent.
@immutable
class InMobiBannerListener {
  const InMobiBannerListener({
    this.onAdLoaded,
    this.onAdFailedToLoad,
    this.onAdImpression,
    this.onAdClicked,
  });

  final VoidCallback? onAdLoaded;
  final void Function(InMobiAdError error)? onAdFailedToLoad;
  final VoidCallback? onAdImpression;
  final VoidCallback? onAdClicked;
}

/// A banner ad, sized by [size] and filled by the native InMobi SDK.
///
/// The widget always occupies [size], loaded or not. It does not collapse on
/// failure, because a banner slot that changes height when an auction comes
/// back empty reflows the screen under the user's thumb. Wrap it yourself if
/// you want it to disappear — [InMobiBannerListener.onAdFailedToLoad] is the
/// signal.
class InMobiBannerAd extends StatefulWidget {
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
    InMobiAds.instance.debugAssertInitialized('banner ad');
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
        'refreshIntervalSeconds': widget.refreshInterval?.inSeconds,
      };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size.width,
      height: widget.size.height,
      child: switch (defaultTargetPlatform) {
        TargetPlatform.android => _buildAndroidView(),
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
  Widget _buildAndroidView() {
    return PlatformViewLink(
      viewType: _viewType,
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      ),
      onCreatePlatformView: (params) {
        return PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: _viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: _creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
      },
    );
  }
}
