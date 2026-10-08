import 'package:flutter/material.dart';
import 'package:inmobi_ads/inmobi_ads.dart';

/// Ids come from the InMobi publisher dashboard and are passed in at build
/// time so this file can be committed without them:
///
/// ```sh
/// flutter run --dart-define=INMOBI_ACCOUNT_ID=... \
///             --dart-define=INMOBI_BANNER_PLACEMENT=... \
///             --dart-define=INMOBI_INTERSTITIAL_PLACEMENT=... \
///             --dart-define=INMOBI_REWARDED_PLACEMENT=...
/// ```
///
/// **InMobi has no shared test placements.** Test mode is a per-placement
/// switch in the dashboard; turn it on for these before running.
const accountId = String.fromEnvironment('INMOBI_ACCOUNT_ID');
const bannerPlacement = int.fromEnvironment('INMOBI_BANNER_PLACEMENT');
const interstitialPlacement =
    int.fromEnvironment('INMOBI_INTERSTITIAL_PLACEMENT');
const rewardedPlacement = int.fromEnvironment('INMOBI_REWARDED_PLACEMENT');

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'inmobi_ads',
      theme: ThemeData(useMaterial3: true),
      home: const _HomePage(),
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  /// Null until [InMobiAds.initialize] has answered. Nothing may be requested
  /// before then — the plugin throws a [StateError] rather than letting an
  /// uninitialised SDK report a failure that looks exactly like no fill.
  bool? _started;

  String _log = 'Not initialised.';

  /// Whether the banner is in the tree at all.
  ///
  /// An InMobi banner always occupies its declared size — it does not collapse
  /// itself on failure — so the host decides. This mirrors what a real app
  /// wants: the slot disappears rather than sitting empty.
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (accountId.isEmpty) {
      setState(() {
        _started = false;
        _log = 'No account id. Pass --dart-define=INMOBI_ACCOUNT_ID=... '
            'and a placement id per format; see the example README.';
      });
      return;
    }

    final started = await InMobiAds.instance.initialize(
      accountId: accountId,
      logLevel: InMobiLogLevel.debug,
    );
    if (!mounted) return;
    setState(() {
      _started = started;
      _log = started ? 'SDK ready.' : 'SDK declined to start.';
    });
  }

  void _note(String message) {
    if (!mounted) return;
    setState(() => _log = message);
  }

  void _loadInterstitial() {
    _note('Loading interstitial…');
    InMobiInterstitialAd.load(
      placementId: interstitialPlacement,
      adLoadCallback: InMobiFullScreenAdLoadCallback(
        onAdLoaded: (ad) {
          _note('Interstitial loaded.');
          // Single-use on both platforms: dispose on dismissal and load a
          // fresh one to show again.
          ad.fullScreenContentCallback = InMobiFullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              _note('Interstitial dismissed.');
              ad.dispose();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              _note('Interstitial failed to show: ${error.code}');
              ad.dispose();
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (error) => _note('Interstitial $error'),
      ),
    );
  }

  void _loadRewarded() {
    _note('Loading rewarded…');
    InMobiRewardedAd.load(
      placementId: rewardedPlacement,
      adLoadCallback: InMobiFullScreenAdLoadCallback(
        onAdLoaded: (ad) {
          _note('Rewarded loaded.');
          ad.fullScreenContentCallback = InMobiFullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) => ad.dispose(),
            onAdFailedToShowFullScreenContent: (ad, error) {
              _note('Rewarded failed to show: ${error.code}');
              ad.dispose();
            },
          );
          // The map comes from a dashboard field, so it is logged and not
          // trusted: what a reward is worth is the app's business.
          ad.show(
            onUserEarnedReward: (ad, reward) =>
                _note('Reward earned: ${reward.rewards}'),
          );
        },
        onAdFailedToLoad: (error) => _note('Rewarded $error'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = _started ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('inmobi_ads')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_log),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: ready && bannerPlacement != 0
                  ? () => setState(() => _showBanner = !_showBanner)
                  : null,
              child: Text(_showBanner ? 'Hide banner' : 'Show banner'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: ready && interstitialPlacement != 0
                  ? _loadInterstitial
                  : null,
              child: const Text('Interstitial'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: ready && rewardedPlacement != 0 ? _loadRewarded : null,
              child: const Text('Rewarded'),
            ),
            const Spacer(),
            if (_showBanner)
              Center(
                child: InMobiBannerAd(
                  placementId: bannerPlacement,
                  listener: InMobiBannerListener(
                    onAdLoaded: () => _note('Banner loaded.'),
                    onAdFailedToLoad: (error) {
                      _note('Banner $error');
                      // There is no creative coming, so take the slot back
                      // rather than leaving a 320x50 hole.
                      setState(() => _showBanner = false);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
