import 'package:flutter/foundation.dart';

/// The privacy signal handed to the InMobi SDK.
///
/// InMobi takes consent as a loosely-typed JSON object whose keys have changed
/// across SDK versions. This class is deliberately *not* that object: it is a
/// normalised model, and the native side translates it into whatever keys the
/// linked SDK expects. That keeps a key rename in an InMobi release from being
/// a breaking change to your Dart code.
///
/// From SDK 10.7.5 onward InMobi reads TCF and GPP strings directly from an
/// integrated CMP, so if you already run one — Google's UMP included — you can
/// often pass nothing here at all. Pass a consent object when you gather
/// consent yourself, or when you need to be certain what was sent.
@immutable
class InMobiConsent {
  const InMobiConsent({
    required this.gdprApplies,
    this.consentGiven,
    this.consentString,
  });

  /// Consent for a user the GDPR does not cover.
  ///
  /// The honest default for traffic you know to be outside the EEA and UK. It
  /// is not a way to opt out of the GDPR for traffic that is inside it.
  const InMobiConsent.notApplicable()
      : gdprApplies = false,
        consentGiven = null,
        consentString = null;

  /// Whether the GDPR applies to this user.
  final bool gdprApplies;

  /// Whether the user granted consent, when you know it independently of the
  /// IAB string.
  final bool? consentGiven;

  /// The IAB TCF consent string, when you have one.
  final String? consentString;

  /// The payload sent across the platform channel.
  Map<String, Object?> toMap() => <String, Object?>{
        'gdprApplies': gdprApplies,
        if (consentGiven != null) 'consentGiven': consentGiven,
        if (consentString != null) 'consentString': consentString,
      };

  @override
  String toString() =>
      'InMobiConsent(gdprApplies: $gdprApplies, consentGiven: $consentGiven, '
      'consentString: ${consentString == null ? 'null' : '<set>'})';
}
