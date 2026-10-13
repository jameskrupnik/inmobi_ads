# Changelog

## 0.1.0

First release.

- InMobi SDK 11.4.1 on Android and iOS, pinned exactly on Gradle, CocoaPods
  and Swift Package Manager
- `InMobiAds.initialize`, `setConsent`, `setLogLevel`
- `InMobiRewardedAd`: load, show, and a reward callback that fires before
  dismissal and survives a double-tapped show
- `InMobiInterstitialAd`: load, show
- `InMobiBannerAd`: a widget, hybrid composition on Android, with a
  configurable refresh interval (sub-second values round up, zero turns
  auto-refresh off)
- `fullScreenContentCallback` typed to the ad's own class, so handlers get an
  `InMobiRewardedAd` or `InMobiInterstitialAd` without a cast
- Status codes in one spelling on both platforms
- Refused loads arrive as `onAdFailedToLoad`, and refused shows as
  `onAdFailedToShowFullScreenContent`, rather than as unhandled exceptions
- Android presents full-screen ads from the foreground Activity at `show()`
  and reports `NO_ACTIVITY` when there is none
- The Android banner follows the ambient text direction and states its ad
  size to InMobi in dp
- R8 keeps ship in `consumer-rules.pro`, so an app gets them whether or not
  it references a rules file of its own
- A runnable example app
