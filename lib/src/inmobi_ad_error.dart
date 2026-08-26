import 'package:flutter/foundation.dart';

/// A failure reported by the InMobi SDK.
///
/// [code] is InMobi's own `InMobiAdRequestStatus.StatusCode` name on Android
/// and the `IMStatusCode` value on iOS, normalised to the Android spelling so
/// one switch works on both platforms — `NO_FILL`, `NETWORK_UNREACHABLE`,
/// `REQUEST_TIMED_OUT`, `SERVER_ERROR`, `INTERNAL_ERROR`, and so on.
///
/// Treat an unrecognised [code] as retryable-once and nothing more. The set is
/// not stable across SDK versions, and matching on [message] is worse — it is
/// human-facing text InMobi changes freely.
@immutable
class InMobiAdError {
  const InMobiAdError({required this.code, required this.message});

  /// Builds an error from the raw platform-channel payload.
  factory InMobiAdError.fromMap(Map<Object?, Object?> map) {
    return InMobiAdError(
      code: map['code'] as String? ?? 'UNKNOWN',
      message: map['message'] as String? ?? 'No message provided',
    );
  }

  /// InMobi's status code name, e.g. `NO_FILL`.
  final String code;

  /// InMobi's human-facing description. Do not branch on this.
  final String message;

  /// Whether the request failed because InMobi had nothing to serve.
  ///
  /// The common case, and the one worth distinguishing: no fill is not a bug,
  /// it is an empty auction, and it is the signal to fall through to another
  /// network rather than to retry.
  bool get isNoFill => code == 'NO_FILL';

  @override
  String toString() => 'InMobiAdError($code): $message';

  @override
  bool operator ==(Object other) =>
      other is InMobiAdError && other.code == code && other.message == message;

  @override
  int get hashCode => Object.hash(code, message);
}
