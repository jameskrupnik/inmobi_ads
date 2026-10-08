import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inmobi_ads/inmobi_ads.dart';
import 'package:inmobi_ads/src/platform.dart';

import 'support/fake_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final log = <MethodCall>[];
  const emit = emitAdEvent;

  setUp(() => setUpInMobiChannel(log));

  group('InMobiInterstitialAd', () {
    test('load does not ask for a rewarded placement', () {
      InMobiInterstitialAd.load(
        placementId: 7,
        adLoadCallback: InMobiFullScreenAdLoadCallback(
          onAdLoaded: (_) {},
          onAdFailedToLoad: (_) {},
        ),
      );

      expect(log.last.arguments, containsPair('rewarded', false));
    });

    test('routes every content event to its callback', () async {
      final events = <String>[];
      late InMobiInterstitialAd ad;
      InMobiInterstitialAd.load(
        placementId: 7,
        adLoadCallback: InMobiFullScreenAdLoadCallback(
          onAdLoaded: (loaded) => ad = loaded,
          onAdFailedToLoad: (_) => fail('should not fail'),
        ),
      );
      await emit(0, 'loaded');

      ad.fullScreenContentCallback = InMobiFullScreenContentCallback(
        onAdShowedFullScreenContent: (_) => events.add('showed'),
        onAdImpression: (_) => events.add('impression'),
        onAdClicked: (_) => events.add('clicked'),
        onAdFailedToShowFullScreenContent: (_, error) =>
            events.add('showFailed:${error.code}'),
        onAdDismissedFullScreenContent: (_) => events.add('dismissed'),
      );
      await ad.show();
      for (final event in ['displayed', 'impression', 'clicked', 'dismissed']) {
        await emit(0, event);
      }
      await emit(0, 'displayFailed', {'code': 'INTERNAL_ERROR'});

      expect(log.last.method, 'showFullScreenAd');
      expect(events, [
        'showed',
        'impression',
        'clicked',
        'dismissed',
        'showFailed:INTERNAL_ERROR',
      ]);
    });

    test('a load failure reaches the callback and releases the ad', () async {
      InMobiAdError? error;
      InMobiInterstitialAd.load(
        placementId: 7,
        adLoadCallback: InMobiFullScreenAdLoadCallback(
          onAdLoaded: (_) => fail('should not load'),
          onAdFailedToLoad: (e) => error = e,
        ),
      );

      await emit(0, 'loadFailed', {'code': 'SERVER_ERROR', 'message': 'x'});

      expect(error!.code, 'SERVER_ERROR');
      expect(log.last.method, 'disposeAd');
    });

    test('an ad shown twice, or after dispose, does not reach native',
        () async {
      late InMobiInterstitialAd ad;
      InMobiInterstitialAd.load(
        placementId: 7,
        adLoadCallback: InMobiFullScreenAdLoadCallback(
          onAdLoaded: (loaded) => ad = loaded,
          onAdFailedToLoad: (_) {},
        ),
      );
      await emit(0, 'loaded');

      await ad.show();
      await expectLater(ad.show(), throwsAssertionError);
      await ad.dispose();
      await ad.dispose();
      await expectLater(ad.show(), throwsAssertionError);

      expect(
        log.map((c) => c.method),
        ['initialize', 'loadFullScreenAd', 'showFullScreenAd', 'disposeAd'],
      );
    });

    test('a missing plugin surfaces as a load failure', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(InMobiAdsPlatform.channel, null);

      InMobiAdError? error;
      InMobiInterstitialAd.load(
        placementId: 7,
        adLoadCallback: InMobiFullScreenAdLoadCallback(
          onAdLoaded: (_) => fail('should not load'),
          onAdFailedToLoad: (e) => error = e,
        ),
      );
      await pumpEventQueue();

      expect(error!.code, 'UNSUPPORTED');
    });
  });
}
