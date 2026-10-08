# inmobi_ads example

One button per format — banner, interstitial, rewarded — over the real InMobi
SDKs.

## Running it

The account id and one placement id per format come from your
[InMobi publisher dashboard](https://publisher.inmobi.com) and are passed at
build time, so this directory stays committable:

```console
$ flutter run --dart-define=INMOBI_ACCOUNT_ID=your-account-id \
              --dart-define=INMOBI_BANNER_PLACEMENT=1471550843416 \
              --dart-define=INMOBI_INTERSTITIAL_PLACEMENT=1471550843415 \
              --dart-define=INMOBI_REWARDED_PLACEMENT=1471550843414
```

The values above are placeholders — the numbers are the sample placement id
from InMobi's own integration docs, not working inventory. Substitute your own.

Without an account id the app still builds and runs, reports what is missing
and leaves every button disabled. A format whose placement id is missing keeps
its button disabled too. That is deliberate: a plugin example that throws on a
machine with no account is one nobody can open, and it is the path the widget
test covers.

## Test ads

**InMobi publishes no shared test placements** — nothing equivalent to AdMob's
test units. Test mode is a per-placement switch in the dashboard (for all
devices, or only the ones you list). Turn it on for the placements you pass
here before running against a live account, and remember an account that
InMobi has not yet approved answers `NO_FILL` to everything.

## What it demonstrates that the README only describes

- **The host collapses the banner slot, not the widget.** An InMobi banner
  always occupies its declared size; `onAdFailedToLoad` is the signal to take
  the space back, and this app removes the widget when it fires.
- **Full-screen ads are single-use.** Dispose on dismissal and load a fresh one
  to show again.
- **The reward is a signal, not an amount.** The map comes from a dashboard
  field anyone with access to the placement can edit, so the app logs it and
  decides nothing from it.
