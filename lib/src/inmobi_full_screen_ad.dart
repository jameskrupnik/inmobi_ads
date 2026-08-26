import 'package:flutter/foundation.dart';
import 'package:inmobi_ads/src/inmobi_ad_error.dart';
import 'package:inmobi_ads/src/inmobi_ads_base.dart';
import 'package:inmobi_ads/src/inmobi_reward.dart';
import 'package:inmobi_ads/src/platform.dart';

/// Called when the user finishes a rewarded video.
typedef InMobiOnUserEarnedReward = void Function(
  InMobiRewardedAd ad,
  InMobiReward reward,
);

/// The outcome of asking for a full-screen ad.
///
/// Exactly one of [onAdLoaded] and [onAdFailedToLoad] runs, once.
@immutable
class InMobiFullScreenAdLoadCallback<T extends InMobiFullScreenAd> {
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

/// Events from an ad that has already loaded.
///
/// Every callback is optional. [onAdDismissedFullScreenContent] is the terminal
/// one in the normal path — by the time it runs, any reward callback has
/// already fired — and [onAdFailedToShowFullScreenContent] is terminal in the
/// abnormal one. An ad that reports neither is a bug in this package; the
/// five-minute timeout in your own code is the backstop.
@immutable
class InMobiFullScreenContentCallback<T extends InMobiFullScreenAd> {
  const InMobiFullScreenContentCallback({
    this.onAdShowedFullScreenContent,
    this.onAdDismissedFullScreenContent,
    this.onAdFailedToShowFullScreenContent,
    this.onAdImpression,
    this.onAdClicked,
  });

  final void Function(T ad)? onAdShowedFullScreenContent;
  final void Function(T ad)? onAdDismissedFullScreenContent;
  final void Function(T ad, InMobiAdError error)?
      onAdFailedToShowFullScreenContent;
  final void Function(T ad)? onAdImpression;
  final void Function(T ad)? onAdClicked;
}

/// Shared machinery for the two full-screen formats.
///
/// Both are the same native class — `InMobiInterstitial` on Android,
/// `IMInterstitial` on iOS — and which one you get is decided by how the
/// placement is configured in the InMobi dashboard, not by the SDK call. The
/// split into two Dart types exists so that the reward callback is only
/// reachable where a reward can actually arrive.
abstract class InMobiFullScreenAd {
  InMobiFullScreenAd._({required this.placementId}) {
    _adId = InMobiAdsPlatform.registerAd(_handleEvent);
  }

  /// The placement id from the InMobi dashboard.
  final int placementId;

  late final int _adId;

  bool _shown = false;
  bool _disposed = false;

  /// Events for an ad that has loaded. Set this before calling [show].
  InMobiFullScreenContentCallback<InMobiFullScreenAd>? fullScreenContentCallback;

  void _handleEvent(String event, Map<Object?, Object?> arguments);

  /// Presents the ad.
  ///
  /// Calling this twice on one ad is a no-op with a debug-mode complaint: both
  /// native SDKs require a fresh load after a dismissal, and showing a spent ad
  /// fails silently on iOS rather than reporting an error you could react to.
  Future<void> show() async {
    if (_disposed) {
      assert(false, 'show() called on a disposed InMobi ad');
      return;
    }
    if (_shown) {
      assert(false, 'InMobi ads are single-use — load a new one to show again');
      return;
    }
    _shown = true;
    await InMobiAdsPlatform.channel
        .invokeMethod<void>('showFullScreenAd', {'adId': _adId});
  }

  /// Releases the native ad. Call it once you are done, in every path.
  ///
  /// After this, late events for the ad are dropped rather than delivered.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    InMobiAdsPlatform.unregisterAd(_adId);
    await InMobiAdsPlatform.channel
        .invokeMethod<void>('disposeAd', {'adId': _adId});
  }

  static Future<void> _load({
    required int placementId,
    required int adId,
    required bool rewarded,
  }) {
    return InMobiAdsPlatform.channel.invokeMethod<void>('loadFullScreenAd', {
      'adId': adId,
      'placementId': placementId,
      'rewarded': rewarded,
    });
  }
}

/// A rewarded video ad.
///
/// ```dart
/// InMobiRewardedAd.load(
///   placementId: 1471550843414,
///   adLoadCallback: InMobiFullScreenAdLoadCallback(
///     onAdLoaded: (ad) {
///       ad.fullScreenContentCallback = InMobiFullScreenContentCallback(
///         onAdDismissedFullScreenContent: (ad) => ad.dispose(),
///       );
///       ad.show(onUserEarnedReward: (ad, reward) => grantCoins());
///     },
///     onAdFailedToLoad: (error) => fallBackToAnotherNetwork(error),
///   ),
/// );
/// ```
class InMobiRewardedAd extends InMobiFullScreenAd {
  InMobiRewardedAd._({
    required super.placementId,
    required InMobiFullScreenAdLoadCallback<InMobiRewardedAd> loadCallback,
  })  : _loadCallback = loadCallback,
        super._();

  final InMobiFullScreenAdLoadCallback<InMobiRewardedAd> _loadCallback;

  InMobiOnUserEarnedReward? _onUserEarnedReward;

  /// Requests a rewarded ad for [placementId].
  ///
  /// The placement must be configured as rewarded in the InMobi dashboard. A
  /// non-rewarded placement loads and shows perfectly well here and simply
  /// never reports a reward, which is a difficult failure to spot — check the
  /// dashboard first when [InMobiOnUserEarnedReward] never runs.
  static void load({
    required int placementId,
    required InMobiFullScreenAdLoadCallback<InMobiRewardedAd> adLoadCallback,
  }) {
    InMobiAds.instance.debugAssertInitialized('rewarded ad');
    final ad = InMobiRewardedAd._(
      placementId: placementId,
      loadCallback: adLoadCallback,
    );
    InMobiFullScreenAd._load(
      placementId: placementId,
      adId: ad._adId,
      rewarded: true,
    );
  }

  /// Presents the ad, reporting the reward to [onUserEarnedReward].
  ///
  /// The reward callback fires before `onAdDismissedFullScreenContent`, so by
  /// the time dismissal arrives you already know whether one was earned.
  @override
  Future<void> show({InMobiOnUserEarnedReward? onUserEarnedReward}) {
    _onUserEarnedReward = onUserEarnedReward;
    return super.show();
  }

  @override
  void _handleEvent(String event, Map<Object?, Object?> arguments) {
    switch (event) {
      case 'loaded':
        _loadCallback.onAdLoaded(this);
      case 'loadFailed':
        _loadCallback.onAdFailedToLoad(InMobiAdError.fromMap(arguments));
        dispose();
      case 'rewards':
        final rewards = arguments['rewards'] as Map<Object?, Object?>? ?? {};
        _onUserEarnedReward?.call(this, InMobiReward.fromMap(rewards));
      default:
        _dispatchContentEvent(this, fullScreenContentCallback, event, arguments);
    }
  }
}

/// A full-screen interstitial ad.
class InMobiInterstitialAd extends InMobiFullScreenAd {
  InMobiInterstitialAd._({
    required super.placementId,
    required InMobiFullScreenAdLoadCallback<InMobiInterstitialAd> loadCallback,
  })  : _loadCallback = loadCallback,
        super._();

  final InMobiFullScreenAdLoadCallback<InMobiInterstitialAd> _loadCallback;

  /// Requests an interstitial ad for [placementId].
  static void load({
    required int placementId,
    required InMobiFullScreenAdLoadCallback<InMobiInterstitialAd> adLoadCallback,
  }) {
    InMobiAds.instance.debugAssertInitialized('interstitial ad');
    final ad = InMobiInterstitialAd._(
      placementId: placementId,
      loadCallback: adLoadCallback,
    );
    InMobiFullScreenAd._load(
      placementId: placementId,
      adId: ad._adId,
      rewarded: false,
    );
  }

  @override
  void _handleEvent(String event, Map<Object?, Object?> arguments) {
    switch (event) {
      case 'loaded':
        _loadCallback.onAdLoaded(this);
      case 'loadFailed':
        _loadCallback.onAdFailedToLoad(InMobiAdError.fromMap(arguments));
        dispose();
      default:
        _dispatchContentEvent(this, fullScreenContentCallback, event, arguments);
    }
  }
}

/// Routes the events both formats share onto [callback].
void _dispatchContentEvent<T extends InMobiFullScreenAd>(
  T ad,
  InMobiFullScreenContentCallback<InMobiFullScreenAd>? callback,
  String event,
  Map<Object?, Object?> arguments,
) {
  if (callback == null) return;
  switch (event) {
    case 'displayed':
      callback.onAdShowedFullScreenContent?.call(ad);
    case 'displayFailed':
      callback.onAdFailedToShowFullScreenContent
          ?.call(ad, InMobiAdError.fromMap(arguments));
    case 'dismissed':
      callback.onAdDismissedFullScreenContent?.call(ad);
    case 'impression':
      callback.onAdImpression?.call(ad);
    case 'clicked':
      callback.onAdClicked?.call(ad);
  }
}
