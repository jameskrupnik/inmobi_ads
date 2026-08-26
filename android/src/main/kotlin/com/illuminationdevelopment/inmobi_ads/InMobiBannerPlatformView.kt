package com.illuminationdevelopment.inmobi_ads

import android.content.Context
import android.view.View
import android.view.ViewGroup
import com.inmobi.ads.AdMetaInfo
import com.inmobi.ads.InMobiAdRequestStatus
import com.inmobi.ads.InMobiBanner
import com.inmobi.ads.listeners.BannerAdEventListener
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/** Builds the [InMobiBannerPlatformView]s that back `InMobiBannerAd`. */
internal class InMobiBannerViewFactory(
    private val sendEvent: EventSink,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any?>()
        return InMobiBannerPlatformView(context, params, sendEvent)
    }
}

/**
 * One `InMobiBanner`, embedded in the Flutter view hierarchy.
 *
 * ### Sizing
 *
 * InMobi's Android banner takes its size from its layout params **in device
 * pixels**, not from a size constant the way AdMob does. Dart sends logical
 * pixels and the conversion happens here, against the density of the context
 * the view is actually attached to — reusing a density Flutter reported earlier
 * puts the banner at the wrong size on a second display or after a fold.
 *
 * A banner whose layout params do not match the creative size the placement
 * serves renders blank rather than scaling, which is the usual cause of a
 * banner that reports `loaded` and shows nothing.
 */
internal class InMobiBannerPlatformView(
    context: Context,
    params: Map<*, *>,
    private val sendEvent: EventSink,
) : PlatformView {

    private val adId = (params["adId"] as? Number)?.toInt() ?: -1
    private val banner: InMobiBanner?

    init {
        val placementId = (params["placementId"] as? Number)?.toLong()
        val density = context.resources.displayMetrics.density
        val widthPx = ((params["width"] as? Number)?.toFloat() ?: 320f) * density
        val heightPx = ((params["height"] as? Number)?.toFloat() ?: 50f) * density

        banner = if (placementId == null) {
            sendEvent(
                adId,
                "loadFailed",
                mapOf("code" to "INTERNAL_ERROR", "message" to "placementId is required"),
            )
            null
        } else {
            InMobiBanner(context, placementId).apply {
                setListener(BannerListener())
                setEnableAutoRefresh(true)

                // InMobi clamps anything under 20 seconds up to its floor rather
                // than honouring it, so a caller asking for 5 gets 20 and no
                // warning. Zero is this package's own signal for "off".
                when (val seconds = (params["refreshIntervalSeconds"] as? Number)?.toInt()) {
                    null -> Unit
                    0 -> setEnableAutoRefresh(false)
                    else -> setRefreshInterval(seconds)
                }

                // Banners live inside a Flutter layout that animates on its own
                // terms; InMobi's default axis rotation on refresh fights it.
                setAnimationType(InMobiBanner.AnimationType.ANIMATION_OFF)

                layoutParams = ViewGroup.LayoutParams(widthPx.toInt(), heightPx.toInt())
                load()
            }
        }
    }

    override fun getView(): View? = banner

    override fun dispose() {
        banner?.destroy()
    }

    private inner class BannerListener : BannerAdEventListener() {
        override fun onAdLoadSucceeded(ad: InMobiBanner, info: AdMetaInfo) =
            sendEvent(adId, "loaded", emptyMap())

        override fun onAdLoadFailed(ad: InMobiBanner, status: InMobiAdRequestStatus) =
            sendEvent(adId, "loadFailed", status.toEventMap())

        override fun onAdImpression(ad: InMobiBanner) =
            sendEvent(adId, "impression", emptyMap())

        override fun onAdClicked(ad: InMobiBanner, params: MutableMap<Any, Any>?) =
            sendEvent(adId, "clicked", emptyMap())
    }
}
