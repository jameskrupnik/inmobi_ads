import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:inmobi_ads/src/inmobi_consent.dart';
import 'package:inmobi_ads/src/platform.dart';

/// How much the InMobi SDK writes to the platform log.
enum InMobiLogLevel {
  /// Silent. The right setting for a release build.
  none,

  /// Errors only.
  error,

  /// Everything, including request and response bodies.
  debug,
}

/// Entry point for the InMobi SDK.
///
/// [initialize] must complete before any ad is loaded. Ads loaded beforehand
/// fail rather than queue — InMobi's SDKs report an uninitialised request as an
/// ordinary load failure, which is indistinguishable from no fill, so this class
/// checks [isInitialized] itself and throws a [StateError] with a real
/// explanation instead.
class InMobiAds {
  InMobiAds._();

  /// The one instance. InMobi's SDKs are process-global singletons; pretending
  /// otherwise here would only invite two initialisations with two account ids.
  static final InMobiAds instance = InMobiAds._();

  Future<bool>? _initialization;
  bool _initialized = false;

  /// Whether [initialize] has completed successfully.
  bool get isInitialized => _initialized;

  /// Starts the InMobi SDK.
  ///
  /// Safe to call repeatedly: the first call does the work and every later one
  /// awaits the same future. A failed start is *not* cached — the next call
  /// retries, because a transient network failure at launch should not disable
  /// ads for the life of the process.
  ///
  /// [accountId] is the publisher account id from the InMobi dashboard, not a
  /// placement id. Returns false rather than throwing when the SDK declines to
  /// start, since a monetisation SDK that will not initialise is a condition to
  /// degrade around, not to crash on.
  Future<bool> initialize({
    required String accountId,
    InMobiConsent? consent,
    InMobiLogLevel logLevel = InMobiLogLevel.none,
  }) {
    return _initialization ??= () async {
      try {
        await InMobiAdsPlatform.channel.invokeMethod<void>('initialize', {
          'accountId': accountId,
          'consent': consent?.toMap(),
          'logLevel': logLevel.name,
        });
        _initialized = true;
        return true;
      } on PlatformException {
        _initialization = null;
        return false;
      } on MissingPluginException {
        _initialization = null;
        return false;
      }
    }();
  }

  /// Updates the privacy signal after initialisation.
  ///
  /// Call this when the user changes their choice in your consent UI. It has no
  /// effect on an ad already in flight.
  Future<void> setConsent(InMobiConsent consent) {
    return InMobiAdsPlatform.channel.invokeMethod<void>(
      'setConsent',
      consent.toMap(),
    );
  }

  /// Sets SDK log verbosity. Defaults to [InMobiLogLevel.none].
  Future<void> setLogLevel(InMobiLogLevel level) {
    return InMobiAdsPlatform.channel.invokeMethod<void>(
      'setLogLevel',
      {'logLevel': level.name},
    );
  }

  /// Forgets that the SDK was ever started, so the next [initialize] runs for
  /// real.
  ///
  /// This exists because [instance] is process-wide: without it, the first test
  /// in a suite initializes and every later one silently gets the cached
  /// future, which makes tests pass or fail depending on their order. It does
  /// not tear down the native SDK — nothing can, InMobi's `init` is one-way —
  /// so it is only useful against a mocked channel.
  @visibleForTesting
  void debugReset() {
    _initialization = null;
    _initialized = false;
  }

  /// Throws unless the SDK is up, with a message that says which call is
  /// missing rather than surfacing as a generic load failure.
  void debugAssertInitialized(String what) {
    if (_initialized) return;
    throw StateError(
      'InMobiAds.instance.initialize() must complete before loading a $what. '
      'An uninitialised InMobi SDK reports load failures that look exactly '
      'like no fill, so this is checked here instead.',
    );
  }
}
