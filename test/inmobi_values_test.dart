import 'package:flutter_test/flutter_test.dart';
import 'package:inmobi_ads/inmobi_ads.dart';

void main() {
  group('InMobiAdError', () {
    test('fills in a code and message native left out', () {
      expect(
        InMobiAdError.fromMap(const {}),
        const InMobiAdError(code: 'UNKNOWN', message: 'No message provided'),
      );
    });

    test('compares by value and prints its code', () {
      const error = InMobiAdError(code: 'NO_FILL', message: 'empty');

      expect(
        error.hashCode,
        InMobiAdError.fromMap(const {'code': 'NO_FILL', 'message': 'empty'})
            .hashCode,
      );
      expect(error.toString(), 'InMobiAdError(NO_FILL): empty');
    });
  });

  group('InMobiReward', () {
    test('reads a string amount, which one platform sends instead of a number',
        () {
      final reward = InMobiReward.fromMap(const {'coins': '25'});
      expect(reward.amount, 25);
      expect(reward.name, 'coins');
    });

    test('is empty rather than throwing when the placement configured nothing',
        () {
      final reward = InMobiReward.fromMap(const {});
      expect(reward.amount, 0);
      expect(reward.name, '');
    });

    test('reads a numeric amount as is, and nothing from a non-number', () {
      expect(InMobiReward.fromMap(const {'coins': 10}).amount, 10);
      expect(InMobiReward.fromMap(const {'coins': true}).amount, 0);
      expect(
        InMobiReward.fromMap(const {'coins': 10}).toString(),
        'InMobiReward({coins: 10})',
      );
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

    test('does not print the consent string itself', () {
      const consent = InMobiConsent(gdprApplies: true, consentString: 'CPX');

      expect(consent.toString(), isNot(contains('CPX')));
      expect(
        const InMobiConsent.notApplicable().toString(),
        contains('consentString: null'),
      );
    });
  });
}
