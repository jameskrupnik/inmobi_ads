import Flutter
import InMobiSDK
import UIKit

/// Bridges the InMobi iOS SDK onto one method channel.
///
/// The iOS SDK binds its delegate to the ad object rather than to the request,
/// so ads are held in `fullScreenAds` against the id Dart minted, and every
/// event carries that id back. `AdDelegate` is a separate object per ad for the
/// same reason — the delegate callbacks do not identify which request they
/// belong to.
public class InMobiAdsPlugin: NSObject, FlutterPlugin {

    private let channel: FlutterMethodChannel
    private var fullScreenAds: [Int: IMInterstitial] = [:]
    private var delegates: [Int: FullScreenAdDelegate] = [:]

    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "inmobi_ads",
            binaryMessenger: registrar.messenger()
        )
        let instance = InMobiAdsPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)

        registrar.register(
            InMobiBannerViewFactory(messenger: registrar.messenger()) {
                [weak instance] adId, event, arguments in
                instance?.sendEvent(adId: adId, event: event, arguments: arguments)
            },
            withId: "inmobi_ads/banner"
        )
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any] ?? [:]

        switch call.method {
        case "initialize":
            initialize(arguments, result)
        case "setConsent":
            IMSdk.updateGDPRConsent(Self.consentDictionary(arguments))
            result(nil)
        case "setLogLevel":
            IMSdk.setLogLevel(Self.logLevel(arguments["logLevel"] as? String))
            result(nil)
        case "loadFullScreenAd":
            loadFullScreenAd(arguments, result)
        case "showFullScreenAd":
            showFullScreenAd(arguments, result)
        case "disposeAd":
            if let adId = arguments["adId"] as? Int {
                fullScreenAds.removeValue(forKey: adId)
                delegates.removeValue(forKey: adId)
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initialize(_ arguments: [String: Any], _ result: @escaping FlutterResult) {
        guard let accountId = arguments["accountId"] as? String, !accountId.isEmpty else {
            result(FlutterError(
                code: "INVALID_ACCOUNT_ID",
                message: "accountId must not be empty",
                details: nil
            ))
            return
        }

        IMSdk.setLogLevel(Self.logLevel(arguments["logLevel"] as? String))

        let consent = Self.consentDictionary(arguments["consent"] as? [String: Any] ?? [:])
        IMSdk.initWithAccountID(accountId, consentDictionary: consent) { error in
            if let error = error {
                result(FlutterError(
                    code: "INIT_FAILED",
                    message: error.localizedDescription,
                    details: nil
                ))
            } else {
                result(nil)
            }
        }
    }

    private func loadFullScreenAd(_ arguments: [String: Any], _ result: @escaping FlutterResult) {
        guard
            let adId = arguments["adId"] as? Int,
            let placementId = (arguments["placementId"] as? NSNumber)?.int64Value
        else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "adId and placementId are required",
                details: nil
            ))
            return
        }

        let delegate = FullScreenAdDelegate(adId: adId) { [weak self] adId, event, arguments in
            self?.sendEvent(adId: adId, event: event, arguments: arguments)
        }
        let ad = IMInterstitial(placementId: placementId)
        ad.delegate = delegate

        // The delegate is held here rather than by the ad, because IMInterstitial
        // keeps its delegate weakly — letting it go out of scope means the ad
        // loads and no callback ever arrives.
        delegates[adId] = delegate
        fullScreenAds[adId] = ad

        ad.load()
        result(nil)
    }

    private func showFullScreenAd(_ arguments: [String: Any], _ result: @escaping FlutterResult) {
        guard let adId = arguments["adId"] as? Int else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "adId is required",
                details: nil
            ))
            return
        }

        guard let ad = fullScreenAds[adId] else {
            sendEvent(
                adId: adId,
                event: "displayFailed",
                arguments: ["code": "INTERNAL_ERROR", "message": "Ad \(adId) is gone"]
            )
            result(nil)
            return
        }

        guard let presenter = Self.topViewController() else {
            sendEvent(
                adId: adId,
                event: "displayFailed",
                arguments: [
                    "code": "INTERNAL_ERROR",
                    "message": "No view controller available to present from",
                ]
            )
            result(nil)
            return
        }

        // isReady is checked here because show() on a spent or unloaded
        // IMInterstitial fails silently — no delegate callback at all — which
        // would leave the caller's await hanging until its own timeout.
        guard ad.isReady() else {
            sendEvent(
                adId: adId,
                event: "displayFailed",
                arguments: ["code": "INTERNAL_ERROR", "message": "Ad \(adId) is not ready"]
            )
            result(nil)
            return
        }

        ad.show(from: presenter)
        result(nil)
    }

    private func sendEvent(adId: Int, event: String, arguments: [String: Any?]) {
        var payload = arguments
        payload["adId"] = adId
        payload["event"] = event
        DispatchQueue.main.async { [weak self] in
            self?.channel.invokeMethod("onAdEvent", arguments: payload)
        }
    }

    /// The frontmost view controller, walking past anything already presented.
    ///
    /// Presenting from a controller that is itself covered throws a UIKit
    /// warning and shows nothing, which is easy to hit when an ad is triggered
    /// from a Flutter route shown over a native modal.
    private static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController

        var top = root
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    private static func logLevel(_ name: String?) -> IMSDKLogLevel {
        switch name {
        case "error": return .error
        case "debug": return .debug
        default: return .none
        }
    }

    /// Translates this package's normalised consent model into InMobi's
    /// dictionary. The key names live here, and only here.
    private static func consentDictionary(_ consent: [String: Any]) -> [String: Any] {
        var dictionary: [String: Any] = [:]
        let gdprApplies = consent["gdprApplies"] as? Bool ?? false
        dictionary["gdpr"] = gdprApplies ? "1" : "0"

        if let consentString = consent["consentString"] as? String {
            dictionary["gdpr_consent"] = consentString
        }
        if let consentGiven = consent["consentGiven"] as? Bool {
            dictionary["gdpr_consent_available"] = consentGiven
        }
        return dictionary
    }
}

/// One ad's delegate, tagged with the id its events belong to.
final class FullScreenAdDelegate: NSObject, IMInterstitialDelegate {

    private let adId: Int
    private let sendEvent: (Int, String, [String: Any?]) -> Void

    init(adId: Int, sendEvent: @escaping (Int, String, [String: Any?]) -> Void) {
        self.adId = adId
        self.sendEvent = sendEvent
        super.init()
    }

    func interstitialDidFinishLoading(_ interstitial: IMInterstitial) {
        sendEvent(adId, "loaded", [:])
    }

    func interstitial(_ interstitial: IMInterstitial, didFailToLoadWithError error: IMRequestStatus) {
        sendEvent(adId, "loadFailed", InMobiStatus.eventMap(error))
    }

    func interstitialDidPresent(_ interstitial: IMInterstitial) {
        sendEvent(adId, "displayed", [:])
    }

    func interstitial(_ interstitial: IMInterstitial, didFailToPresentWithError error: IMRequestStatus) {
        sendEvent(adId, "displayFailed", InMobiStatus.eventMap(error))
    }

    func interstitialAdImpressed(_ interstitial: IMInterstitial) {
        sendEvent(adId, "impression", [:])
    }

    func interstitial(_ interstitial: IMInterstitial, didInteractWithParams params: [String: Any]?) {
        sendEvent(adId, "clicked", [:])
    }

    /// Fires before `interstitialDidDismiss`, which is what lets a caller treat
    /// dismissal as terminal and still know whether a reward was earned.
    func interstitial(_ interstitial: IMInterstitial, rewardActionCompletedWithRewards rewards: [String: Any]) {
        sendEvent(adId, "rewards", ["rewards": rewards])
    }

    func interstitialDidDismiss(_ interstitial: IMInterstitial) {
        sendEvent(adId, "dismissed", [:])
    }
}

/// Maps InMobi's iOS status codes onto the Android spelling.
///
/// The two SDKs report the same conditions under different names. Normalising
/// here means `InMobiAdError.code` means one thing in Dart, and a caller can
/// switch on `NO_FILL` without asking which platform it is on.
enum InMobiStatus {
    static func eventMap(_ status: IMRequestStatus) -> [String: Any?] {
        return [
            "code": name(for: status.code),
            "message": status.localizedDescription,
        ]
    }

    private static func name(for code: IMStatusCode) -> String {
        switch code {
        case .noFill: return "NO_FILL"
        case .networkUnReachable: return "NETWORK_UNREACHABLE"
        case .requestTimedOut: return "REQUEST_TIMED_OUT"
        case .requestInvalid: return "REQUEST_INVALID"
        case .requestPending: return "REQUEST_PENDING"
        case .serverError: return "SERVER_ERROR"
        case .internalError: return "INTERNAL_ERROR"
        case .adActive: return "AD_ACTIVE"
        case .earlyRefreshRequest: return "EARLY_REFRESH_REQUEST"
        case .monetizationDisabled: return "MONETIZATION_DISABLED"
        case .lowMemory: return "LOW_MEMORY"
        @unknown default: return "INTERNAL_ERROR"
        }
    }
}
