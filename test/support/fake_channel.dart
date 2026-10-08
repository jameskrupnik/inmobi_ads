import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inmobi_ads/inmobi_ads.dart';
import 'package:inmobi_ads/src/platform.dart';

/// Delivers a native event the way the plugin does, through the channel's own
/// incoming path, so the routing under test is the real one.
Future<void> emitAdEvent(
  int adId,
  String event, [
  Map<String, Object?> extra = const {},
]) {
  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    'inmobi_ads',
    const StandardMethodCodec().encodeMethodCall(
      MethodCall('onAdEvent', {...extra, 'adId': adId, 'event': event}),
    ),
    (_) {},
  );
}

/// Resets the plugin's process-wide state, records every outgoing call into
/// [log], and initializes the SDK against that mock.
Future<void> setUpInMobiChannel(List<MethodCall> log) async {
  log.clear();
  InMobiAdsPlatform.reset();
  InMobiAds.instance.debugReset();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(InMobiAdsPlatform.channel, (call) async {
    log.add(call);
    return null;
  });
  await InMobiAds.instance.initialize(accountId: 'test-account');
}
