package com.illuminationdevelopment.inmobi_ads

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.inmobi.ads.AdMetaInfo
import com.inmobi.ads.InMobiAdRequestStatus
import com.inmobi.ads.InMobiInterstitial
import com.inmobi.ads.listeners.InterstitialAdEventListener
import com.inmobi.sdk.InMobiSdk
import com.inmobi.sdk.SdkInitializationListener
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * Bridges the InMobi Android SDK onto one method channel.
 *
 * Two constraints from the SDK shape everything here:
 *
 *  - `InMobiInterstitial` is **not thread-safe and must be constructed and
 *    called on the UI thread**. Every entry point below hops to the main
 *    looper rather than trusting the caller, because Flutter guarantees method
 *    calls arrive on the platform thread but says nothing about which thread
 *    that is on every embedding.
 *  - Its listener is bound to the ad instance, not the request, so ads are held
 *    in [fullScreenAds] against the id Dart minted and events carry that id back.
 */
class InMobiAdsPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var applicationContext: Context
    private var activity: Activity? = null

    private val fullScreenAds = mutableMapOf<Int, InMobiInterstitial>()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)

        binding.platformViewRegistry.registerViewFactory(
            BANNER_VIEW_TYPE,
            InMobiBannerViewFactory { adId, event, arguments ->
                sendEvent(adId, event, arguments)
            },
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        mainHandler.post {
            fullScreenAds.clear()
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "setConsent" -> {
                InMobiSdk.updateGDPRConsent(consentJson(call.arguments as? Map<*, *>))
                result.success(null)
            }
            "setLogLevel" -> {
                InMobiSdk.setLogLevel(logLevel(call.argument<String>("logLevel")))
                result.success(null)
            }
            "loadFullScreenAd" -> loadFullScreenAd(call, result)
            "showFullScreenAd" -> showFullScreenAd(call, result)
            "disposeAd" -> {
                val adId = call.argument<Int>("adId")
                mainHandler.post { adId?.let(fullScreenAds::remove) }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun initialize(call: MethodCall, result: MethodChannel.Result) {
        val accountId = call.argument<String>("accountId")
        if (accountId.isNullOrBlank()) {
            result.error("INVALID_ACCOUNT_ID", "accountId must not be empty", null)
            return
        }

        InMobiSdk.setLogLevel(logLevel(call.argument<String>("logLevel")))

        mainHandler.post {
            InMobiSdk.init(
                applicationContext,
                accountId,
                consentJson(call.argument<Map<*, *>>("consent")),
                object : SdkInitializationListener {
                    override fun onInitializationComplete(error: Error?) {
                        if (error == null) {
                            result.success(null)
                        } else {
                            result.error(
                                "INIT_FAILED",
                                error.message ?: "InMobi SDK failed to initialize",
                                null,
                            )
                        }
                    }
                },
            )
        }
    }

    private fun loadFullScreenAd(call: MethodCall, result: MethodChannel.Result) {
        val adId = call.argument<Int>("adId")
        // Dart sends this as a 64-bit int; MethodChannel narrows small values to
        // Integer, so read it as Number and widen rather than casting to Long.
        val placementId = (call.argument<Any>("placementId") as? Number)?.toLong()

        if (adId == null || placementId == null) {
            result.error("INVALID_ARGUMENTS", "adId and placementId are required", null)
            return
        }

        // InMobi needs an Activity to present a full-screen ad. Failing here
        // rather than at show() means the caller learns about it while it can
        // still fall through to another network.
        val context = activity ?: run {
            result.error(
                "NO_ACTIVITY",
                "InMobi full-screen ads need a foreground Activity; none is attached",
                null,
            )
            return
        }

        mainHandler.post {
            val ad = InMobiInterstitial(context, placementId, FullScreenListener(adId))
            fullScreenAds[adId] = ad
            ad.load()
        }
        result.success(null)
    }

    private fun showFullScreenAd(call: MethodCall, result: MethodChannel.Result) {
        val adId = call.argument<Int>("adId")
        if (adId == null) {
            result.error("INVALID_ARGUMENTS", "adId is required", null)
            return
        }

        mainHandler.post {
            val ad = fullScreenAds[adId]
            when {
                ad == null -> sendEvent(
                    adId,
                    "displayFailed",
                    mapOf("code" to "INTERNAL_ERROR", "message" to "Ad $adId is gone"),
                )
                !ad.isReady -> sendEvent(
                    adId,
                    "displayFailed",
                    mapOf("code" to "INTERNAL_ERROR", "message" to "Ad $adId is not ready"),
                )
                else -> ad.show()
            }
        }
        result.success(null)
    }

    /** Bridges one ad's listener callbacks onto [sendEvent]. */
    private inner class FullScreenListener(private val adId: Int) :
        InterstitialAdEventListener() {

        override fun onAdLoadSucceeded(ad: InMobiInterstitial, info: AdMetaInfo) =
            sendEvent(adId, "loaded")

        override fun onAdLoadFailed(ad: InMobiInterstitial, status: InMobiAdRequestStatus) =
            sendEvent(adId, "loadFailed", status.toEventMap())

        override fun onAdDisplayed(ad: InMobiInterstitial, info: AdMetaInfo) =
            sendEvent(adId, "displayed")

        override fun onAdDisplayFailed(ad: InMobiInterstitial) = sendEvent(
            adId,
            "displayFailed",
            mapOf(
                "code" to "INTERNAL_ERROR",
                "message" to "InMobi reported onAdDisplayFailed",
            ),
        )

        override fun onAdImpression(ad: InMobiInterstitial) = sendEvent(adId, "impression")

        override fun onAdClicked(ad: InMobiInterstitial, params: MutableMap<Any, Any>?) =
            sendEvent(adId, "clicked")

        /**
         * Fires before [onAdDismissed], which is what lets a caller treat
         * dismissal as terminal and still know whether a reward was earned.
         */
        override fun onRewardsUnlocked(ad: InMobiInterstitial, rewards: MutableMap<Any, Any>) =
            sendEvent(
                adId,
                "rewards",
                mapOf("rewards" to rewards.entries.associate { it.key.toString() to it.value }),
            )

        override fun onAdDismissed(ad: InMobiInterstitial) = sendEvent(adId, "dismissed")
    }

    private fun sendEvent(
        adId: Int,
        event: String,
        arguments: Map<String, Any?> = emptyMap(),
    ) {
        val payload = HashMap<String, Any?>(arguments).apply {
            put("adId", adId)
            put("event", event)
        }
        mainHandler.post { channel.invokeMethod("onAdEvent", payload) }
    }

    private companion object {
        const val CHANNEL_NAME = "inmobi_ads"
        const val BANNER_VIEW_TYPE = "inmobi_ads/banner"

        fun logLevel(name: String?): InMobiSdk.LogLevel = when (name) {
            "error" -> InMobiSdk.LogLevel.ERROR
            "debug" -> InMobiSdk.LogLevel.DEBUG
            else -> InMobiSdk.LogLevel.NONE
        }

        /**
         * Translates this package's normalised consent model into InMobi's JSON.
         *
         * The key names live here, and only here, because InMobi has renamed
         * them across SDK releases and the Dart API should not have to move
         * when they do.
         */
        fun consentJson(consent: Map<*, *>?): JSONObject {
            val json = JSONObject()
            if (consent == null) return json

            val gdprApplies = consent["gdprApplies"] as? Boolean ?: false
            json.put("gdpr", if (gdprApplies) "1" else "0")

            (consent["consentString"] as? String)?.let { json.put("gdpr_consent", it) }
            (consent["consentGiven"] as? Boolean)?.let {
                json.put("gdpr_consent_available", it)
            }
            return json
        }
    }
}
