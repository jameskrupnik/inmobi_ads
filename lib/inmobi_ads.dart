/// Direct Flutter bindings for the InMobi advertising SDK.
///
/// InMobi ships native Android, iOS and Unity SDKs but no Flutter plugin. The
/// only maintained Flutter package carrying their name is Google's
/// `gma_mediation_inmobi`, which reaches InMobi *through* the Google Mobile Ads
/// SDK — useful if you already run AdMob, useless if the reason you want InMobi
/// is to not run AdMob.
///
/// This package is the other thing: a direct wrapper over
/// `com.inmobi.monetization:inmobi-ads-kotlin` and the InMobi iOS SDK, with no
/// mediator in the path.
///
/// ```dart
/// await InMobiAds.instance.initialize(accountId: 'your-account-id');
///
/// InMobiRewardedAd.load(
///   placementId: 1471550843414,
///   adLoadCallback: InMobiFullScreenAdLoadCallback(
///     onAdLoaded: (ad) => ad.show(
///       onUserEarnedReward: (ad, reward) => grantCoins(reward.amount),
///     ),
///     onAdFailedToLoad: (error) => log('$error'),
///   ),
/// );
/// ```
///
/// Not affiliated with or endorsed by InMobi.
library;

export 'src/inmobi_ad_error.dart' show InMobiAdError;
export 'src/inmobi_ads_base.dart' show InMobiAds, InMobiLogLevel;
export 'src/inmobi_banner_ad.dart'
    show InMobiBannerAd, InMobiBannerListener, InMobiBannerSize;
export 'src/inmobi_consent.dart' show InMobiConsent;
export 'src/inmobi_full_screen_ad.dart'
    show
        InMobiFullScreenAd,
        InMobiFullScreenAdLoadCallback,
        InMobiFullScreenContentCallback,
        InMobiInterstitialAd,
        InMobiRewardedAd;
export 'src/inmobi_reward.dart' show InMobiReward;
