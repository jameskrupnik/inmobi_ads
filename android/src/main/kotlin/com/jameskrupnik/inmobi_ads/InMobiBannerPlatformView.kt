package com.jameskrupnik.inmobi_ads

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
import kotlin.math.roundToInt

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
 * The view's layout params are **device pixels**, converted here from the
 * logical pixels Dart sends against the density of the context the view is
 * actually attached to. The ad size InMobi requests is set separately, in dp,
 * through `setBannerSize`.
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
        val widthDp = (params["width"] as? Number)?.toFloat() ?: 320f
        val heightDp = (params["height"] as? Number)?.toFloat() ?: 50f

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

                layoutParams = ViewGroup.LayoutParams(
                    (widthDp * density).roundToInt(),
                    (heightDp * density).roundToInt(),
                )
                // Without this InMobi derives the ad size back from the layout
                // params, dividing by a display density it caches once per
                // process — which is not the density of this context after a
                // display-size change or on a second display. Stating the size
                // in dp leaves nothing to derive.
                setBannerSize(widthDp.roundToInt(), heightDp.roundToInt())
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
