package app.lolados.duesp.data.api

import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive

// plan.php (journey planner). The legacy shape has `legs`/`data`; planner v2 adds
// door-to-door `summary` fields, `segments` (walking and transit in order) and `walk`.
// `segments` and `walk` are kept as raw JSON and decoded separately, so a surprise
// in them never fails the whole response.

@Serializable
data class PlanResponse(val result: PlanResultDto)

@Serializable
data class PlanResultDto(
    val alternatives: List<PlanAlternativeDto> = emptyList(),
    val rankingPriority: String? = null,
    val walk: JsonElement? = null,
    val departure: JsonElement? = null,
)

@Serializable
data class PlanDepartureDto(
    @Serializable(with = LenientStringSerializer::class) val date: String? = null,
    @Serializable(with = LenientStringSerializer::class) val time: String? = null,
)

@Serializable
data class PlanWalkOptionDto(
    @Serializable(with = LenientIntSerializer::class) val distanceMeters: Int? = null,
    @Serializable(with = LenientIntSerializer::class) val durationMinutes: Int? = null,
    @Serializable(with = LenientStringSerializer::class) val arrivalTime: String? = null,
)

@Serializable
data class PlanAlternativeDto(
    val type: String = "unknown",
    val summary: PlanSummaryDto? = null,
    val legs: List<PlanLegDto>? = null,
    val data: PlanLegacyDataDto? = null,
    val segments: JsonElement? = null,
)

@Serializable
data class PlanSummaryDto(
    @Serializable(with = LenientStringSerializer::class) val departureTime: String? = null,
    @Serializable(with = LenientStringSerializer::class) val arrivalTime: String? = null,
    @Serializable(with = LenientIntSerializer::class) val legCount: Int? = null,
    @Serializable(with = LenientIntSerializer::class) val stopCount: Int? = null,
    @Serializable(with = LenientStringSerializer::class) val lineSummary: String? = null,
    @Serializable(with = LenientIntSerializer::class) val transferCount: Int? = null,
    @Serializable(with = LenientStringSerializer::class) val startTime: String? = null,
    @Serializable(with = LenientStringSerializer::class) val endTime: String? = null,
    @Serializable(with = LenientIntSerializer::class) val durationMinutes: Int? = null,
    @Serializable(with = LenientIntSerializer::class) val walkMeters: Int? = null,
    @Serializable(with = LenientIntSerializer::class) val walkMinutes: Int? = null,
)

@Serializable
data class PlanLegacyDataDto(
    val route: PlanRouteDto? = null,
    val originRoute: PlanRouteDto? = null,
    val destinationRoute: PlanRouteDto? = null,
    @Serializable(with = LenientStringSerializer::class) val tripId: String? = null,
    @Serializable(with = LenientStringSerializer::class) val originTripId: String? = null,
    @Serializable(with = LenientStringSerializer::class) val destinationTripId: String? = null,
    val originStop: PlanStopDto? = null,
    val destinationStop: PlanStopDto? = null,
    val transferStop: PlanStopDto? = null,
)

@Serializable
data class PlanLegDto(
    val route: PlanRouteDto? = null,
    @Serializable(with = LenientStringSerializer::class) val tripId: String? = null,
    val originStop: PlanStopDto? = null,
    val destinationStop: PlanStopDto? = null,
    @Serializable(with = LenientStringSerializer::class) val mode: String? = null,
    @Serializable(with = LenientStringSerializer::class) val headsign: String? = null,
    @Serializable(with = LenientStringSerializer::class) val departureTime: String? = null,
    @Serializable(with = LenientStringSerializer::class) val arrivalTime: String? = null,
    @Serializable(with = LenientIntSerializer::class) val durationMinutes: Int? = null,
    @Serializable(with = LenientIntSerializer::class) val stopCount: Int? = null,
    @Serializable(with = LenientIntSerializer::class) val headwayMinutes: Int? = null,
    val intermediateStops: List<PlanStopDto>? = null,
)

/** A v2 segment: `type` is "walk" (from/to) or "transit" (the leg fields, inline). */
@Serializable
data class PlanSegmentDto(
    val type: String = "",
    val from: PlanStopDto? = null,
    val to: PlanStopDto? = null,
    @Serializable(with = LenientStringSerializer::class) val departureTime: String? = null,
    @Serializable(with = LenientStringSerializer::class) val arrivalTime: String? = null,
    @Serializable(with = LenientIntSerializer::class) val durationMinutes: Int? = null,
    @Serializable(with = LenientIntSerializer::class) val distanceMeters: Int? = null,
    // Transit fields
    val route: PlanRouteDto? = null,
    @Serializable(with = LenientStringSerializer::class) val tripId: String? = null,
    @Serializable(with = LenientStringSerializer::class) val mode: String? = null,
    @Serializable(with = LenientStringSerializer::class) val headsign: String? = null,
    val originStop: PlanStopDto? = null,
    val destinationStop: PlanStopDto? = null,
    @Serializable(with = LenientIntSerializer::class) val stopCount: Int? = null,
    @Serializable(with = LenientIntSerializer::class) val headwayMinutes: Int? = null,
    val intermediateStops: List<PlanStopDto>? = null,
)

@Serializable
data class PlanRouteDto(
    @Serializable(with = LenientStringSerializer::class) val routeId: String? = null,
    @Serializable(with = LenientStringSerializer::class) val shortName: String? = null,
    @Serializable(with = LenientStringSerializer::class) val longName: String? = null,
    @Serializable(with = LenientStringSerializer::class) val color: String? = null,
    @Serializable(with = LenientStringSerializer::class) val textColor: String? = null,
    @Serializable(with = LenientIntSerializer::class) val type: Int? = null,
)

@Serializable
data class PlanStopDto(
    @Serializable(with = LenientIntSerializer::class) val id: Int? = null,
    @Serializable(with = LenientStringSerializer::class) val name: String? = null,
    @Serializable(with = LenientDoubleSerializer::class) val lat: Double? = null,
    @Serializable(with = LenientDoubleSerializer::class) val lon: Double? = null,
    /** Passing time, on a v2 leg's intermediate stops. */
    @Serializable(with = LenientStringSerializer::class) val time: String? = null,
)

// The PHP API emits ids and numbers as strings or numbers depending on the source
// (e.g. non-numeric GTFS stop ids). These decode either form, and anything else as null.

private fun Decoder.primitiveContent(): String? {
    val element = (this as? JsonDecoder)?.decodeJsonElement() ?: return decodeString()
    if (element is JsonNull) return null
    return (element as? JsonPrimitive)?.content
}

object LenientIntSerializer : KSerializer<Int?> {
    override val descriptor = PrimitiveSerialDescriptor("LenientInt", PrimitiveKind.STRING)
    override fun deserialize(decoder: Decoder): Int? =
        decoder.primitiveContent()?.let { it.toIntOrNull() ?: it.toDoubleOrNull()?.toInt() }
    override fun serialize(encoder: Encoder, value: Int?) = encoder.encodeString(value?.toString().orEmpty())
}

object LenientDoubleSerializer : KSerializer<Double?> {
    override val descriptor = PrimitiveSerialDescriptor("LenientDouble", PrimitiveKind.STRING)
    override fun deserialize(decoder: Decoder): Double? = decoder.primitiveContent()?.toDoubleOrNull()
    override fun serialize(encoder: Encoder, value: Double?) = encoder.encodeString(value?.toString().orEmpty())
}

object LenientStringSerializer : KSerializer<String?> {
    override val descriptor = PrimitiveSerialDescriptor("LenientString", PrimitiveKind.STRING)
    override fun deserialize(decoder: Decoder): String? = decoder.primitiveContent()
    override fun serialize(encoder: Encoder, value: String?) = encoder.encodeString(value.orEmpty())
}

// share.php (shared journeys, https://sptrans.lolados.app/j/<token>). Requests carry references only.

@Serializable
data class ShareRequest(val date: String, val legs: List<ShareLeg>)

@Serializable
data class ShareLeg(val tripId: String, val from: String, val to: String, val departure: String)

@Serializable
data class ShareResponse(val token: String, val url: String)

@Serializable
data class SharedJourneyResponse(
    val token: String,
    val url: String,
    val from: String = "",
    val to: String = "",
    val state: String = "upcoming",
    @Serializable(with = LenientIntSerializer::class) val departsAt: Int? = null,
    val journey: PlanAlternativeDto,
)
