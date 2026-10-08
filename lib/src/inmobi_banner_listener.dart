/// @docImport 'package:inmobi_ads/src/inmobi_banner_ad.dart';
library;

import 'package:flutter/foundation.dart';
import 'package:inmobi_ads/src/inmobi_ad_error.dart';

/// Events from an [InMobiBannerAd].
///
/// With auto-refresh on — the default — [onAdLoaded] runs again on every
/// refresh, not just the first. Anything you do here should be idempotent.
@immutable
class InMobiBannerListener {
  /// Creates a listener; every callback is optional.
  const InMobiBannerListener({
    this.onAdLoaded,
    this.onAdFailedToLoad,
    this.onAdImpression,
    this.onAdClicked,
  });

  /// Called when a creative has loaded, including on every auto-refresh.
  final VoidCallback? onAdLoaded;

  /// Called when a request comes back without a creative.
  ///
  /// [InMobiAdError.isNoFill] separates an empty auction from a real failure.
  /// The widget keeps its size either way.
  final void Function(InMobiAdError error)? onAdFailedToLoad;

  /// Called when InMobi counts an impression for the current creative.
  final VoidCallback? onAdImpression;

  /// Called when the user taps the banner.
  final VoidCallback? onAdClicked;
}
