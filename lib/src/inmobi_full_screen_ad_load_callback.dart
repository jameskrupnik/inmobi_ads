import 'package:flutter/foundation.dart';
import 'package:inmobi_ads/src/inmobi_ad_error.dart';
import 'package:inmobi_ads/src/inmobi_full_screen_ad.dart';

/// The outcome of asking for a full-screen ad.
///
/// Exactly one of [onAdLoaded] and [onAdFailedToLoad] runs, once.
@immutable
class InMobiFullScreenAdLoadCallback<T extends InMobiFullScreenAd> {
  /// Creates a load callback; both handlers are required.
  const InMobiFullScreenAdLoadCallback({
    required this.onAdLoaded,
    required this.onAdFailedToLoad,
  });

  /// The ad is ready. It is yours to `show()` and then `dispose()`.
  final void Function(T ad) onAdLoaded;

  /// Nothing will be shown. [InMobiAdError.isNoFill] distinguishes an empty
  /// auction from an actual failure.
  final void Function(InMobiAdError error) onAdFailedToLoad;
}
