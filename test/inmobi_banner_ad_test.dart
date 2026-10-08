import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inmobi_ads/inmobi_ads.dart';
import 'package:inmobi_ads/src/platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final platformViewCalls = <MethodCall>[];

  /// Delivers a native banner event through the plugin's real incoming path.
  Future<void> emit(
    int adId,
    String event, [
    Map<String, Object?> extra = const {},
  ]) {
    return messenger.handlePlatformMessage(
      'inmobi_ads',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('onAdEvent', {...extra, 'adId': adId, 'event': event}),
      ),
      (_) {},
    );
  }

  Widget host(Widget banner) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: banner),
      );

  setUp(() async {
    platformViewCalls.clear();
    InMobiAdsPlatform.reset();
    InMobiAds.instance.debugReset();
    messenger
      ..setMockMethodCallHandler(
        InMobiAdsPlatform.channel,
        (call) async => null,
      )
      ..setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
        platformViewCalls.add(call);
        return call.method == 'create' ? 0 : null;
      });
    await InMobiAds.instance.initialize(accountId: 'test-account');
  });

  group('InMobiBannerAd', () {
    testWidgets('throws before initialize has completed', (tester) async {
      InMobiAds.instance.debugReset();

      await tester.pumpWidget(
        host(const InMobiBannerAd(placementId: 1)),
      );

      expect(tester.takeException(), isStateError);
    });

    testWidgets(
      'holds its size on a platform it cannot render on',
      (tester) async {
        await tester.pumpWidget(
          host(
            const InMobiBannerAd(
              placementId: 1,
              size: InMobiBannerSize.mediumRectangle,
            ),
          ),
        );

        expect(
          tester.getSize(find.byType(InMobiBannerAd)),
          const Size(300, 250),
        );
        expect(platformViewCalls, isEmpty);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets(
      'creates a UiKit view with the banner parameters on iOS',
      (tester) async {
        await tester.pumpWidget(
          host(
            const InMobiBannerAd(
              placementId: 1471550843416,
              refreshInterval: Duration(seconds: 30),
            ),
          ),
        );

        final create =
            platformViewCalls.firstWhere((c) => c.method == 'create');
        final arguments = create.arguments as Map<Object?, Object?>;
        expect(arguments['viewType'], 'inmobi_ads/banner');
        final params = const StandardMessageCodec().decodeMessage(
          ByteData.sublistView(arguments['params']! as Uint8List),
        ) as Map<Object?, Object?>;
        expect(params, {
          'adId': 0,
          'placementId': 1471550843416,
          'width': 320.0,
          'height': 50.0,
          'refreshIntervalSeconds': 30,
        });
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    Future<Map<Object?, Object?>> creationParams(
      WidgetTester tester,
      Duration? refreshInterval,
    ) async {
      await tester.pumpWidget(
        host(
          InMobiBannerAd(
            key: UniqueKey(),
            placementId: 1,
            refreshInterval: refreshInterval,
          ),
        ),
      );
      final create = platformViewCalls.lastWhere((c) => c.method == 'create');
      final arguments = create.arguments as Map<Object?, Object?>;
      return const StandardMessageCodec().decodeMessage(
        ByteData.sublistView(arguments['params']! as Uint8List),
      ) as Map<Object?, Object?>;
    }

    testWidgets(
      'only Duration.zero turns auto-refresh off',
      (tester) async {
        // inSeconds truncates, so 500 ms used to arrive as 0 — this
        // package's own "off" signal — and a caller asking for fast refresh
        // got none at all. A positive interval rounds up to whole seconds.
        final seconds = <Object?>[];
        for (final interval in const [
          Duration(milliseconds: 500),
          Duration(milliseconds: 20500),
          Duration.zero,
        ]) {
          final params = await creationParams(tester, interval);
          seconds.add(params['refreshIntervalSeconds']);
        }
        expect(seconds, [1, 21, 0]);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'rejects a negative refresh interval',
      (tester) async {
        await tester.pumpWidget(
          host(
            const InMobiBannerAd(
              placementId: 1,
              refreshInterval: Duration(seconds: -5),
            ),
          ),
        );
        expect(tester.takeException(), isAssertionError);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'passes the ambient text direction to the Android view',
      (tester) async {
        // Creatives are web content; an Arabic or Hebrew app laid out RTL
        // should not have its banner forced LTR.
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.rtl,
            child: Center(child: InMobiBannerAd(placementId: 1)),
          ),
        );
        await tester.pump();

        final create =
            platformViewCalls.firstWhere((c) => c.method == 'create');
        final arguments = create.arguments as Map<Object?, Object?>;
        // AndroidViewController encodes RTL as 1 (View.LAYOUT_DIRECTION_RTL).
        expect(arguments['direction'], 1);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'creates a hybrid-composition view on Android',
      (tester) async {
        await tester.pumpWidget(
          host(const InMobiBannerAd(placementId: 1)),
        );
        await tester.pump();

        final create =
            platformViewCalls.firstWhere((c) => c.method == 'create');
        final arguments = create.arguments as Map<Object?, Object?>;
        expect(arguments['viewType'], 'inmobi_ads/banner');
        expect(arguments['hybrid'], isTrue);

        // A tap on the native view reports focus back through the engine;
        // the banner has to pass it on or the creative cannot take input.
        await messenger.handlePlatformMessage(
          SystemChannels.platform_views.name,
          SystemChannels.platform_views.codec.encodeMethodCall(
            MethodCall('viewFocused', arguments['id']),
          ),
          (_) {},
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'routes native events to the listener',
      (tester) async {
        final events = <String>[];

        await tester.pumpWidget(
          host(
            InMobiBannerAd(
              placementId: 1,
              listener: InMobiBannerListener(
                onAdLoaded: () => events.add('loaded'),
                onAdFailedToLoad: (error) => events.add('failed:${error.code}'),
                onAdImpression: () => events.add('impression'),
                onAdClicked: () => events.add('clicked'),
              ),
            ),
          ),
        );

        await emit(0, 'loaded');
        await emit(0, 'impression');
        await emit(0, 'clicked');
        await emit(0, 'loadFailed', {'code': 'NO_FILL', 'message': 'empty'});

        expect(events, ['loaded', 'impression', 'clicked', 'failed:NO_FILL']);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets(
      'ignores events without a listener, and after disposal',
      (tester) async {
        var loads = 0;

        await tester.pumpWidget(
          host(const InMobiBannerAd(placementId: 1)),
        );
        await emit(0, 'loaded');

        await tester.pumpWidget(
          host(
            InMobiBannerAd(
              key: UniqueKey(),
              placementId: 1,
              listener: InMobiBannerListener(onAdLoaded: () => loads++),
            ),
          ),
        );
        await tester.pumpWidget(const SizedBox());
        await emit(1, 'loaded');

        expect(loads, 0);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
  });

  group('InMobiBannerSize', () {
    test('compares by value', () {
      // Built at runtime: two const instances would be identical, which
      // proves nothing about ==.
      InMobiBannerSize sized(double height) =>
          InMobiBannerSize(width: 320, height: height);
      final custom = sized(50);
      expect(custom, InMobiBannerSize.banner);
      expect(custom.hashCode, InMobiBannerSize.banner.hashCode);
      expect(InMobiBannerSize.leaderboard, isNot(InMobiBannerSize.banner));
    });

    test('describes itself by its dimensions', () {
      expect(
        InMobiBannerSize.leaderboard.toString(),
        'InMobiBannerSize(728.0x90.0)',
      );
    });
  });
}
