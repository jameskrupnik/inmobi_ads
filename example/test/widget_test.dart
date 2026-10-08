import 'package:flutter_test/flutter_test.dart';
import 'package:inmobi_ads_example/main.dart';

/// The example builds without an account, and says so rather than failing.
///
/// A plugin example that throws on a machine with no publisher account is one
/// nobody can open, and this one is run by pub.dev's analyzer as well as by
/// people evaluating the package. `String.fromEnvironment` is empty here, so
/// this exercises the same path a first-time reader hits.
void main() {
  testWidgets('renders its controls and reports the missing ids', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    expect(find.text('inmobi_ads'), findsOneWidget);
    expect(find.text('Show banner'), findsOneWidget);
    expect(find.text('Interstitial'), findsOneWidget);
    expect(find.text('Rewarded'), findsOneWidget);
    expect(find.textContaining('No account id'), findsOneWidget);
  });
}
