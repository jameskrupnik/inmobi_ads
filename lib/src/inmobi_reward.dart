import 'package:flutter/foundation.dart';

/// The reward InMobi reports when a user finishes a rewarded video.
///
/// InMobi does not model a reward as a name/amount pair the way AdMob does. It
/// hands back whatever key/value map you configured on the placement in the
/// publisher dashboard, as `Map<Object, Object>` on Android and an `NSDictionary`
/// on iOS. [rewards] is that map, coerced to string keys.
///
/// [name] and [amount] read the first entry as a convenience, because a single
/// `{"coins": 10}` pair is what almost every placement is configured with. If
/// yours carries more than one entry, read [rewards] directly — [name] and
/// [amount] pick an arbitrary one, since neither platform guarantees map order.
///
/// **Do not trust these values to set a balance.** They come from a dashboard
/// field, which means anyone who can edit the placement can change what your
/// app grants. Use the callback as the signal that a reward was *earned* and
/// decide the amount in your own code.
@immutable
class InMobiReward {
  const InMobiReward(this.rewards);

  /// Builds a reward from the raw platform-channel payload.
  factory InMobiReward.fromMap(Map<Object?, Object?> map) {
    return InMobiReward(<String, Object?>{
      for (final entry in map.entries) entry.key.toString(): entry.value,
    });
  }

  /// The placement's configured reward map, verbatim.
  final Map<String, Object?> rewards;

  /// The first reward key, or the empty string when the map is empty.
  String get name => rewards.keys.firstOrNull ?? '';

  /// The first reward value parsed as a number, or 0 when absent or unparseable.
  ///
  /// InMobi returns dashboard values as strings on one platform and numbers on
  /// the other depending on SDK version, so this handles both rather than
  /// making callers guess which they got.
  num get amount {
    final value = rewards.values.firstOrNull;
    return switch (value) {
      final num n => n,
      final String s => num.tryParse(s) ?? 0,
      _ => 0,
    };
  }

  @override
  String toString() => 'InMobiReward($rewards)';
}
