# Changelog

## 0.1.0

First release.

- InMobi SDK 11.4.1 on both platforms
- `InMobiAds.initialize`, `setConsent`, `setLogLevel`
- `InMobiRewardedAd` — load, show, reward callback
- `InMobiInterstitialAd` — load, show
- `InMobiBannerAd` — a widget, hybrid composition on Android
- Status codes normalised to one spelling across platforms
- R8 keeps shipped in `consumer-rules.pro`, so a consuming app gets them
  whether or not it references a rules file of its own
- iOS through CocoaPods or Swift Package Manager, both pinned to 11.4.x
- A load the native side refuses arrives as `onAdFailedToLoad`, not as an
  unhandled exception
- `fullScreenContentCallback` is typed to the ad's own class, so its handlers
  receive an `InMobiRewardedAd` or `InMobiInterstitialAd` without a cast
- A runnable example app
- Android presents a full-screen ad from the Activity in the foreground at
  `show()`, and reports `NO_ACTIVITY` there if there is none
- A second `show()` on a rewarded ad no longer replaces the first call's
  reward callback
- A sub-second banner `refreshInterval` rounds up instead of turning
  auto-refresh off; a negative one asserts
- The Android banner takes the ambient text direction instead of forcing LTR,
  and states its ad size to InMobi in dp
