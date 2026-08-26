package com.illuminationdevelopment.inmobi_ads

import com.inmobi.ads.InMobiAdRequestStatus

/**
 * How this plugin hands an event back to Dart: the ad's id, an event name, and
 * whatever extra payload that event carries.
 */
internal typealias EventSink = (adId: Int, event: String, arguments: Map<String, Any?>) -> Unit

/**
 * InMobi's failure, flattened into the shape `InMobiAdError.fromMap` expects.
 *
 * [InMobiAdRequestStatus.statusCode] is an enum whose *name* is the stable part
 * — the message is human-facing text InMobi rewords between releases — so the
 * name is what crosses the channel.
 */
internal fun InMobiAdRequestStatus.toEventMap(): Map<String, Any?> = mapOf(
    "code" to statusCode.name,
    "message" to (message ?: "No message provided"),
)
