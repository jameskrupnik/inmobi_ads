import 'package:flutter/foundation.dart';
import 'package:inmobi_ads/src/inmobi_ad_error.dart';
import 'package:inmobi_ads/src/inmobi_full_screen_ad.dart';

/// Events from an ad that has already loaded.
///
/// Every callback is optional. [onAdDismissedFullScreenContent] is the terminal
/// one in the normal path — by the time it runs, any reward callback has
/// already fired — and [onAdFailedToShowFullScreenContent] is terminal in the
/// abnormal one. An ad that reports neither is a bug in this package; the
/// five-minute timeout in your own code is the backstop.
@immutable
class InMobiFullScreenContentCallback<T extends InMobiFullScreenAd> {
  /// Creates a content callback; every handler is optional.
  const InMobiFullScreenContentCallback({
    this.onAdShowedFullScreenContent,
    this.onAdDismissedFullScreenContent,
    this.onAdFailedToShowFullScreenContent,
    this.onAdImpression,
    this.onAdClicked,
  });

  /// Called when the ad has covered the screen.
  final void Function(T ad)? onAdShowedFullScreenContent;

  /// Called when the user closes the ad. Terminal in the normal path.
  final void Function(T ad)? onAdDismissedFullScreenContent;

  /// Called when the ad could not be shown. Terminal in the abnormal path.
  final void Function(T ad, InMobiAdError error)?
      onAdFailedToShowFullScreenContent;

  /// Called when InMobi counts an impression.
  final void Function(T ad)? onAdImpression;

  /// Called when the user taps the ad.
  final void Function(T ad)? onAdClicked;
}
