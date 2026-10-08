import 'dart:async';

import 'package:flutter/services.dart';
import 'package:inmobi_ads/src/inmobi_ad_error.dart';
import 'package:inmobi_ads/src/inmobi_ads_base.dart';
import 'package:inmobi_ads/src/inmobi_full_screen_ad_load_callback.dart';
import 'package:inmobi_ads/src/inmobi_full_screen_content_callback.dart';
import 'package:inmobi_ads/src/inmobi_reward.dart';
import 'package:inmobi_ads/src/platform.dart';

/// Called when the user finishes a rewarded video.
typedef InMobiOnUserEarnedReward = void Function(
  InMobiRewardedAd ad,
  InMobiReward reward,
);

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
    try {
      await InMobiAdsPlatform.channel
          .invokeMethod<void>('disposeAd', {'adId': _adId});
    } on MissingPluginException {
      // No native side, so nothing native to release. This is also the path a
      // failed load takes on an unsupported platform, where throwing would
      // turn an orderly load failure into an unhandled async error.
    }
  }

  /// Asks native for the ad, turning a refused request into a load failure.
  ///
  /// Native rejects some requests outright — no foreground Activity on
  /// Android, say — by failing the channel call rather than sending an event.
  /// Left alone, that would surface as an unhandled async error and neither
  /// load callback would ever run, so it is routed to `loadFailed` instead.
  Future<void> _load({required bool rewarded}) async {
    try {
      await InMobiAdsPlatform.channel.invokeMethod<void>('loadFullScreenAd', {
        'adId': _adId,
        'placementId': placementId,
        'rewarded': rewarded,
      });
    } on PlatformException catch (e) {
      _handleEvent('loadFailed', {'code': e.code, 'message': e.message});
    } on MissingPluginException catch (e) {
      _handleEvent('loadFailed', {'code': 'UNSUPPORTED', 'message': e.message});
    }
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

  /// Events for an ad that has loaded. Set this before calling [show].
  InMobiFullScreenContentCallback<InMobiRewardedAd>? fullScreenContentCallback;

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
    ensureInitialized('rewarded ad');
    unawaited(
      InMobiRewardedAd._(
        placementId: placementId,
        loadCallback: adLoadCallback,
      )._load(rewarded: true),
    );
  }

  /// Presents the ad, reporting the reward to [onUserEarnedReward].
  ///
  /// The reward callback fires before `onAdDismissedFullScreenContent`, so by
  /// the time dismissal arrives you already know whether one was earned.
  ///
  /// A call that [show] refuses — a second one, or one after [dispose] —
  /// leaves the callback from the first in place. Replacing it would let a
  /// double-tapped "watch ad" button drop the reward the user is earning.
  @override
  Future<void> show({InMobiOnUserEarnedReward? onUserEarnedReward}) {
    if (!_shown && !_disposed) _onUserEarnedReward = onUserEarnedReward;
    return super.show();
  }

  @override
  void _handleEvent(String event, Map<Object?, Object?> arguments) {
    switch (event) {
      case 'loaded':
        _loadCallback.onAdLoaded(this);
      case 'loadFailed':
        _loadCallback.onAdFailedToLoad(InMobiAdError.fromMap(arguments));
        unawaited(dispose());
      case 'rewards':
        final rewards = arguments['rewards'] as Map<Object?, Object?>? ?? {};
        _onUserEarnedReward?.call(this, InMobiReward.fromMap(rewards));
      default:
        _dispatchContentEvent(
          this,
          fullScreenContentCallback,
          event,
          arguments,
        );
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

  /// Events for an ad that has loaded. Set this before calling [show].
  InMobiFullScreenContentCallback<InMobiInterstitialAd>?
      fullScreenContentCallback;

  /// Requests an interstitial ad for [placementId].
  static void load({
    required int placementId,
    required InMobiFullScreenAdLoadCallback<InMobiInterstitialAd>
        adLoadCallback,
  }) {
    ensureInitialized('interstitial ad');
    unawaited(
      InMobiInterstitialAd._(
        placementId: placementId,
        loadCallback: adLoadCallback,
      )._load(rewarded: false),
    );
  }

  @override
  void _handleEvent(String event, Map<Object?, Object?> arguments) {
    switch (event) {
      case 'loaded':
        _loadCallback.onAdLoaded(this);
      case 'loadFailed':
        _loadCallback.onAdFailedToLoad(InMobiAdError.fromMap(arguments));
        unawaited(dispose());
      default:
        _dispatchContentEvent(
          this,
          fullScreenContentCallback,
          event,
          arguments,
        );
    }
  }
}

/// Routes the events both formats share onto [callback].
///
/// [callback] is typed to the ad's own class, so a caller's
/// `InMobiFullScreenContentCallback<InMobiRewardedAd>` receives an
/// `InMobiRewardedAd` without a cast.
void _dispatchContentEvent<T extends InMobiFullScreenAd>(
  T ad,
  InMobiFullScreenContentCallback<T>? callback,
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
