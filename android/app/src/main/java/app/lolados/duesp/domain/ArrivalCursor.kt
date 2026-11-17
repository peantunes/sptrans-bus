package app.lolados.duesp.domain

import java.time.LocalDate

/**
 * Pagination cursor for `arrivals.php`, ported from the iOS `StopDetailViewModel.shiftedCursor`.
 * The cursor is the boundary arrival time shifted by ±1 second, keeping GTFS times (which may be ≥ 24h)
 * on their service date and rolling back a day when the time goes negative.
 */
data class ArrivalCursor(val date: String, val time: String) {
    companion object {
        fun shifted(serviceDate: String, gtfsTime: String, deltaSeconds: Int): ArrivalCursor? {
            val base = runCatching { LocalDate.parse(serviceDate) }.getOrNull() ?: return null
            val seconds = gtfsSeconds(gtfsTime) ?: return null
            var total = seconds + deltaSeconds
            var date = base
            while (total < 0) {
                total += 24 * 3600
                date = date.minusDays(1)
            }
            return ArrivalCursor(date.toString(), formatGtfs(total))
        }

        fun gtfsSeconds(value: String): Int? {
            val parts = value.trim().split(":")
            if (parts.size < 2) return null
            val h = parts[0].toIntOrNull() ?: return null
            val m = parts[1].toIntOrNull() ?: return null
            val s = parts.getOrNull(2)?.toIntOrNull() ?: 0
            return h * 3600 + m * 60 + s
        }

        fun formatGtfs(totalSeconds: Int): String =
            "%02d:%02d:%02d".format(totalSeconds / 3600, (totalSeconds % 3600) / 60, totalSeconds % 60)

        /** Next page starts after the last arrival. */
        fun next(arrivals: List<Arrival>): ArrivalCursor? =
            arrivals.lastOrNull()?.let { a -> a.serviceDate?.let { shifted(it, a.arrivalTime, 1) } }

        /** Previous page ends before the first arrival. */
        fun previous(arrivals: List<Arrival>): ArrivalCursor? =
            arrivals.firstOrNull()?.let { a -> a.serviceDate?.let { shifted(it, a.arrivalTime, -1) } }
    }
}
