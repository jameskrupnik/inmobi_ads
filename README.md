# inmobi_ads

Direct Flutter bindings for the InMobi advertising SDK — rewarded video,
interstitial and banner, on Android and iOS, with no mediation layer in the
path.

> **Unofficial.** Not affiliated with, authored by, or endorsed by InMobi.

## Why this exists

InMobi ships Android, iOS and Unity SDKs but no Flutter plugin. Search pub.dev
for `inmobi` and you get exactly one maintained result — Google's
[`gma_mediation_inmobi`](https://pub.dev/packages/gma_mediation_inmobi), which
reaches InMobi *through* the Google Mobile Ads SDK.

That package is the right answer if you already run AdMob and want InMobi as
extra demand. It is the wrong answer if the reason you want InMobi is to **not**
run AdMob: you keep `google_mobile_ads`, you keep the AdMob account, and InMobi
merely fills. Your app is still an AdMob publisher, still bound by AdMob's
policies.

The only other options were an
[archived 2021 plugin](https://github.com/nmfisher/inmobi_flutter_plugin)
supporting interstitials alone, and writing platform channels yourself.

This package is that last option, done once, in public.

## Install

```yaml
dependencies:
  inmobi_ads: ^0.1.0
```

You need an InMobi publisher account, an **Account ID**, and one **placement
ID per format**, all from [publisher.inmobi.com](https://publisher.inmobi.com).
Monetization stays disabled until InMobi approves the account, and an
unapproved account returns `NO_FILL` for everything — which looks exactly like
an empty auction. Check the account status before debugging your integration.

## Use

Initialize once, before any ad:

```dart
await InMobiAds.instance.initialize(accountId: 'your-account-id');
```

### Rewarded

```dart
InMobiRewardedAd.load(
  placementId: 1471550843414,
  adLoadCallback: InMobiFullScreenAdLoadCallback(
    onAdLoaded: (ad) {
      ad.fullScreenContentCallback = InMobiFullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) => ad.dispose(),
      );
      ad.show(onUserEarnedReward: (ad, reward) => grantCoins());
    },
    onAdFailedToLoad: (error) {
      if (error.isNoFill) tryAnotherNetwork();
    },
  ),
);
```

The reward callback fires **before** dismissal, so by the time
`onAdDismissedFullScreenContent` runs you already know whether one was earned.

Do not read the amount out of `reward` to set a balance. It comes from a field
in the InMobi dashboard, so anyone who can edit the placement can change what
your app grants. Treat the callback as the signal and decide the amount in your
own code.

### Interstitial

Same shape, without the reward:

```dart
InMobiInterstitialAd.load(
  placementId: 1471550843415,
  adLoadCallback: InMobiFullScreenAdLoadCallback(
    onAdLoaded: (ad) => ad.show(),
    onAdFailedToLoad: (error) => log('$error'),
  ),
);
```

Both formats are the same class natively — `InMobiInterstitial` on Android,
`IMInterstitial` on iOS — and which you get is decided by how the **placement**
is configured, not by which Dart class you call. A non-rewarded placement loaded
as `InMobiRewardedAd` works perfectly and simply never reports a reward. If
`onUserEarnedReward` never runs, check the dashboard before the code.

Ads are single-use. Load a new one to show again, and `dispose()` in every path.

### Banner

```dart
InMobiBannerAd(
  placementId: 1471550843416,
  size: InMobiBannerSize.banner,
  refreshInterval: const Duration(seconds: 30),
  listener: InMobiBannerListener(
    onAdFailedToLoad: (error) => setState(() => _showBanner = false),
  ),
)
```

The widget always occupies its `size`, loaded or not — a slot that collapses on
an empty auction reflows the screen under the user's thumb. Hide it yourself if
you want that.

With auto-refresh on (the default), `onAdLoaded` runs on **every** refresh, not
just the first. InMobi's floor is 20 seconds; anything shorter is clamped up
rather than honoured. Pass `Duration.zero` to get exactly one creative.

### Consent

From SDK 10.7.5 onward InMobi reads TCF and GPP strings from an integrated CMP
on its own, so if you run one you may not need this at all. When you gather
consent yourself:

```dart
await InMobiAds.instance.setConsent(
  InMobiConsent(gdprApplies: true, consentGiven: true, consentString: tcfString),
);
```

`InMobiConsent` is a normalised model, not InMobi's JSON. The key names live in
the native code and only there, because InMobi has renamed them across releases
and that shouldn't break your Dart.

## Platform setup

### Android

Nothing to add. `minSdk 21`, and the R8 keeps ship in `consumer-rules.pro` so
you get them whether or not your app references a `proguard-rules.pro` of its
own — worth knowing, because AGP 9 runs R8 on release by default, an
unreferenced rules file looks identical to a correct one in review, and the
failure mode is a crash at launch in a release build that CI never sees.

**InMobi 11.x requires AGP 8.9.3+ and Kotlin 2.x.** Below that you get a
dependency-resolution error pointing at InMobi's metadata rather than at your
AGP version, which is a confusing place to land.

The SDK pulls in `media3-exoplayer`, `okhttp` and `kotlinx-coroutines-android`.
If your app already pins any of those, expect to reconcile versions.

### iOS

Deployment target 13.0. Add InMobi's **SKAdNetwork identifiers** to your
`Info.plist` or you lose install attribution — InMobi publishes the current list
in their iOS integration docs. If you show the ATT prompt, do it before
initializing.

## Status

**Alpha.** The Dart API is settled enough to build against. The native code is
written against InMobi's published 11.4.1 API surface but **has not yet been
compiled or run against a live InMobi account** — expect signature drift on
first build, particularly in the iOS status-code enum and the delegate
signatures. Issues and PRs welcome; that first-build report is the most useful
thing you can send.

Not supported yet: native ads, and InMobi's own mediation.

## License

MIT
