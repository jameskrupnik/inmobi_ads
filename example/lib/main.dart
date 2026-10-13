import 'package:flutter/material.dart';
import 'package:inmobi_ads/inmobi_ads.dart';

part 'home_page.dart';

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
const interstitialPlacement = int.fromEnvironment(
  'INMOBI_INTERSTITIAL_PLACEMENT',
);
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
