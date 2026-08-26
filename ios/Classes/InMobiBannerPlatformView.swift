import Flutter
import InMobiSDK
import UIKit

/// Builds the platform views that back `InMobiBannerAd`.
final class InMobiBannerViewFactory: NSObject, FlutterPlatformViewFactory {

    private let messenger: FlutterBinaryMessenger
    private let sendEvent: (Int, String, [String: Any?]) -> Void

    init(
        messenger: FlutterBinaryMessenger,
        sendEvent: @escaping (Int, String, [String: Any?]) -> Void
    ) {
        self.messenger = messenger
        self.sendEvent = sendEvent
        super.init()
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return InMobiBannerPlatformView(
            frame: frame,
            params: args as? [String: Any] ?? [:],
            sendEvent: sendEvent
        )
    }
}

/// One `IMBanner`, embedded in the Flutter view hierarchy.
///
/// iOS takes the banner size from the frame in points, which is the same unit
/// Flutter's logical pixels are — so unlike Android there is no density
/// conversion here. A frame that does not match the creative size the placement
/// serves renders blank rather than scaling.
final class InMobiBannerPlatformView: NSObject, FlutterPlatformView, IMBannerDelegate {

    private let adId: Int
    private let sendEvent: (Int, String, [String: Any?]) -> Void
    private let container: UIView
    private var banner: IMBanner?

    init(
        frame: CGRect,
        params: [String: Any],
        sendEvent: @escaping (Int, String, [String: Any?]) -> Void
    ) {
        self.adId = params["adId"] as? Int ?? -1
        self.sendEvent = sendEvent

        let width = (params["width"] as? NSNumber)?.doubleValue ?? 320
        let height = (params["height"] as? NSNumber)?.doubleValue ?? 50
        let bannerFrame = CGRect(x: 0, y: 0, width: width, height: height)

        self.container = UIView(frame: bannerFrame)
        super.init()

        guard let placementId = (params["placementId"] as? NSNumber)?.int64Value else {
            sendEvent(
                adId,
                "loadFailed",
                ["code": "INTERNAL_ERROR", "message": "placementId is required"]
            )
            return
        }

        let banner = IMBanner(frame: bannerFrame, placementId: placementId)
        banner.delegate = self

        // InMobi clamps anything under 20 seconds up to its floor rather than
        // honouring it. Zero is this package's own signal for "off".
        switch (params["refreshIntervalSeconds"] as? NSNumber)?.intValue {
        case .none:
            break
        case .some(0):
            banner.shouldAutoRefresh(false)
        case .some(let seconds):
            banner.refreshInterval = seconds
        }

        // Banners live inside a Flutter layout that animates on its own terms;
        // InMobi's default transition on refresh fights it.
        banner.transitionAnimation = .none

        self.banner = banner
        container.addSubview(banner)
        banner.load()
    }

    func view() -> UIView {
        return container
    }

    // MARK: - IMBannerDelegate

    func bannerDidFinishLoading(_ banner: IMBanner) {
        sendEvent(adId, "loaded", [:])
    }

    func banner(_ banner: IMBanner, didFailToLoadWithError error: IMRequestStatus) {
        sendEvent(adId, "loadFailed", InMobiStatus.eventMap(error))
    }

    func bannerAdImpressed(_ banner: IMBanner) {
        sendEvent(adId, "impression", [:])
    }

    func banner(_ banner: IMBanner, didInteractWithParams params: [String: Any]?) {
        sendEvent(adId, "clicked", [:])
    }
}
