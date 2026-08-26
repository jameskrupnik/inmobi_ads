import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inmobi_ads/inmobi_ads.dart';
import 'package:inmobi_ads/src/platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final log = <MethodCall>[];

  /// Delivers a native event the way the plugin does, through the channel's own
  /// incoming path, so the routing under test is the real one.
  Future<void> emit(int adId, String event, [Map<String, Object?> extra = const {}]) {
    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'inmobi_ads',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('onAdEvent', {...extra, 'adId': adId, 'event': event}),
      ),
      (_) {},
    );
  }

  setUp(() async {
    log.clear();
    InMobiAdsPlatform.reset();
    InMobiAds.instance.debugReset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(InMobiAdsPlatform.channel, (call) async {
      log.add(call);
      return null;
    });
    await InMobiAds.instance.initialize(accountId: 'test-account');
  });

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
  });

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
  });

  group('InMobiReward', () {
    test('reads a string amount, which one platform sends instead of a number', () {
      final reward = InMobiReward.fromMap({'coins': '25'});
      expect(reward.amount, 25);
      expect(reward.name, 'coins');
    });

    test('is empty rather than throwing when the placement configured nothing', () {
      final reward = InMobiReward.fromMap({});
      expect(reward.amount, 0);
      expect(reward.name, '');
    });
  });

  group('InMobiConsent', () {
    test('omits absent fields so native cannot read a null as a false', () {
      expect(
        const InMobiConsent.notApplicable().toMap(),
        {'gdprApplies': false},
      );
    });

    test('carries the IAB string when there is one', () {
      final map = const InMobiConsent(
        gdprApplies: true,
        consentGiven: true,
        consentString: 'CPX',
      ).toMap();

      expect(map, {
        'gdprApplies': true,
        'consentGiven': true,
        'consentString': 'CPX',
      });
    });
  });
}
