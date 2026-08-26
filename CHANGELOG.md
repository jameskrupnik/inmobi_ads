# Changelog

## 0.1.0

First release. Alpha — the Dart API is settled enough to build against, the
native code has not yet been exercised against a live InMobi account.

- InMobi SDK 11.4.1 on both platforms
- `InMobiAds.initialize`, `setConsent`, `setLogLevel`
- `InMobiRewardedAd` — load, show, reward callback
- `InMobiInterstitialAd` — load, show
- `InMobiBannerAd` — a widget, hybrid composition on Android
- Status codes normalised to one spelling across platforms
- R8 keeps shipped in `consumer-rules.pro`, so a consuming app gets them
  whether or not it references a rules file of its own
