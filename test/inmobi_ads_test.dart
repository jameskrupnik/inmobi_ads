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

  group('initialize', () {
    test('sends the account id and log level', () {
      expect(log.single.method, 'initialize');
      expect(log.single.arguments, containsPair('accountId', 'test-account'));
      expect(log.single.arguments, containsPair('logLevel', 'none'));
    });

    test('is idempotent — a second call does not re-initialize', () async {
      await InMobiAds.instance.initialize(accountId: 'other-account');
      expect(log, hasLength(1));
    });
  });

  group('InMobiAds', () {
    test('a failed start is not cached, so the next call retries', () async {
      InMobiAds.instance.debugReset();
      var attempts = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(InMobiAdsPlatform.channel, (call) async {
        attempts++;
        if (attempts == 1) throw PlatformException(code: 'INIT_FAILED');
        return null;
      });

      expect(await InMobiAds.instance.initialize(accountId: 'a'), isFalse);
      expect(InMobiAds.instance.isInitialized, isFalse);
      expect(await InMobiAds.instance.initialize(accountId: 'a'), isTrue);
      expect(InMobiAds.instance.isInitialized, isTrue);
    });

    test('reports false where the plugin is not registered', () async {
      InMobiAds.instance.debugReset();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(InMobiAdsPlatform.channel, null);

      expect(await InMobiAds.instance.initialize(accountId: 'a'), isFalse);
    });

    test('initialize carries consent gathered before start', () async {
      InMobiAds.instance.debugReset();
      log.clear();

      await InMobiAds.instance.initialize(
        accountId: 'a',
        consent: const InMobiConsent.notApplicable(),
      );

      expect(
        log.single.arguments,
        containsPair('consent', {'gdprApplies': false}),
      );
    });

    test('setConsent sends the normalised consent map', () async {
      await InMobiAds.instance.setConsent(
        const InMobiConsent(gdprApplies: true, consentGiven: false),
      );

      expect(log.last.method, 'setConsent');
      expect(log.last.arguments, {'gdprApplies': true, 'consentGiven': false});
    });

    test('setLogLevel sends the level by name', () async {
      await InMobiAds.instance.setLogLevel(InMobiLogLevel.debug);

      expect(log.last.method, 'setLogLevel');
      expect(log.last.arguments, {'logLevel': 'debug'});
    });
  });

  group('InMobiRewardedAd', () {
    test('load asks for a rewarded ad at the placement', () {
      InMobiRewardedAd.load(
        placementId: 1471550843414,
        adLoadCallback: InMobiFullScreenAdLoadCallback(
          onAdLoaded: (_) {},
          onAdFailedToLoad: (_) {},
        ),
      );

      final call = log.last;
      expect(call.method, 'loadFullScreenAd');
      expect(call.arguments, containsPair('placementId', 1471550843414));
      expect(call.arguments, containsPair('rewarded', true));
    });

    test('routes loaded to the load callback', () async {
      InMobiRewardedAd? loaded;
      InMobiRewardedAd.load(
        placementId: 1,
        adLoadCallback: InMobiFullScreenAdLoadCallback(
          onAdLoaded: (ad) => loaded = ad,
          onAdFailedToLoad: (_) => fail('should not fail'),
        ),
      );

      await emit(0, 'loaded');

      expect(loaded, isNotNull);
      expect(loaded!.placementId, 1);
    });

    test('surfaces no fill distinguishably', () async {
      InMobiAdError? error;
      InMobiRewardedAd.load(
        placementId: 1,
        adLoadCallback: InMobiFullScreenAdLoadCallback(
          onAdLoaded: (_) => fail('should not load'),
          onAdFailedToLoad: (e) => error = e,
        ),
      );

      await emit(0, 'loadFailed', {'code': 'NO_FILL', 'message': 'No ads'});

      expect(error!.isNoFill, isTrue);
      expect(error!.code, 'NO_FILL');
    });

    test('reward arrives before dismissal, so dismissal is terminal', () async {
      final order = <String>[];
      late InMobiRewardedAd ad;
      InMobiRewardedAd.load(
        placementId: 1,
        adLoadCallback: InMobiFullScreenAdLoadCallback(
          onAdLoaded: (loaded) => ad = loaded,
          onAdFailedToLoad: (_) => fail('should not fail'),
        ),
      );
      await emit(0, 'loaded');

      ad.fullScreenContentCallback = InMobiFullScreenContentCallback(
        onAdDismissedFullScreenContent: (_) => order.add('dismissed'),
      );
      await ad.show(
        onUserEarnedReward: (_, reward) =>
            order.add('rewarded:${reward.name}=${reward.amount}'),
      );

      await emit(0, 'rewards', {
        'rewards': {'coins': 10},
      });
      await emit(0, 'dismissed');

      expect(order, ['rewarded:coins=10', 'dismissed']);
    });

    test('a refused second show keeps the first reward callback', () async {
      // A double-tap on a "watch ad" button calls show() twice. The second
      // call is a no-op, so it must not replace — or, passing nothing, clear —
      // the callback the user is about to earn a reward through.
      final rewards = <String>[];
      late InMobiRewardedAd ad;
      InMobiRewardedAd.load(
        placementId: 1,
        adLoadCallback: InMobiFullScreenAdLoadCallback(
          onAdLoaded: (loaded) => ad = loaded,
          onAdFailedToLoad: (_) => fail('should not fail'),
        ),
      );
      await emit(0, 'loaded');

      await ad.show(onUserEarnedReward: (_, __) => rewards.add('first'));
      await expectLater(ad.show(), throwsAssertionError);
      await emit(0, 'rewards', {
        'rewards': {'coins': 10},
      });

      expect(rewards, ['first']);
    });

    test('a disposed ad stops receiving events', () async {
      var dismissals = 0;
      late InMobiRewardedAd ad;
      InMobiRewardedAd.load(
        placementId: 1,
        adLoadCallback: InMobiFullScreenAdLoadCallback(
          onAdLoaded: (loaded) => ad = loaded,
          onAdFailedToLoad: (_) => fail('should not fail'),
        ),
      );
      await emit(0, 'loaded');

      ad.fullScreenContentCallback = InMobiFullScreenContentCallback(
        onAdDismissedFullScreenContent: (_) => dismissals++,
      );
      await ad.dispose();
      await emit(0, 'dismissed');

      expect(dismissals, 0);
    });

    test('events reach the right ad when two are in flight', () async {
      final loadedPlacements = <int>[];
      for (final placementId in [111, 222]) {
        InMobiRewardedAd.load(
          placementId: placementId,
          adLoadCallback: InMobiFullScreenAdLoadCallback(
            onAdLoaded: (ad) => loadedPlacements.add(ad.placementId),
            onAdFailedToLoad: (_) {},
          ),
        );
      }

      await emit(1, 'loaded');

      expect(loadedPlacements, [222]);
    });
    test('a content callback typed to the ad receives the ad, uncast',
        () async {
      InMobiRewardedAd? dismissed;
      late InMobiRewardedAd ad;
      InMobiRewardedAd.load(
        placementId: 1,
        adLoadCallback: InMobiFullScreenAdLoadCallback(
          onAdLoaded: (loaded) => ad = loaded,
          onAdFailedToLoad: (_) => fail('should not fail'),
        ),
      );
      await emit(0, 'loaded');

      ad.fullScreenContentCallback =
          InMobiFullScreenContentCallback<InMobiRewardedAd>(
        onAdDismissedFullScreenContent: (ad) => dismissed = ad,
      );
      await emit(0, 'dismissed');

      expect(dismissed, same(ad));
    });

    test('a request native refuses reaches onAdFailedToLoad', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(InMobiAdsPlatform.channel, (call) async {
        if (call.method == 'loadFullScreenAd') {
          throw PlatformException(code: 'NO_ACTIVITY', message: 'none');
        }
        return null;
      });

      InMobiAdError? error;
      InMobiRewardedAd.load(
        placementId: 1,
        adLoadCallback: InMobiFullScreenAdLoadCallback(
          onAdLoaded: (_) => fail('should not load'),
          onAdFailedToLoad: (e) => error = e,
        ),
      );
      await pumpEventQueue();

      expect(error, const InMobiAdError(code: 'NO_ACTIVITY', message: 'none'));
    });

    test('loading before initialize throws a StateError', () {
      InMobiAds.instance.debugReset();

      expect(
        () => InMobiRewardedAd.load(
          placementId: 1,
          adLoadCallback: InMobiFullScreenAdLoadCallback(
            onAdLoaded: (_) {},
            onAdFailedToLoad: (_) {},
          ),
        ),
        throwsStateError,
      );
    });
  });
}
