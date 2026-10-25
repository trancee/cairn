package ch.trancee.cairn.ble

/**
 * The crowd and channel levels of spec §10.4 (ADR 0026): the crowd from advert density, the
 * channel from the dial failure rate. Times are monotonic milliseconds, in non-decreasing order.
 */
internal class Congestion {
    enum class Level { CLEAR, BUSY, CROWDED }

    private val crowdLevel = Hysteresis()
    private val channelLevel = Hysteresis()

    val crowd get() = crowdLevel.level
    val channel get() = channelLevel.level

    /** Distinct addresses seen in the last [DENSITY_WINDOW_MS] at the last evaluation. */
    var density = 0
        private set

    /** Failed and all dials ended in the last [FAILURE_WINDOW_MS] at the last evaluation. */
    var failed = 0
        private set
    var ended = 0
        private set

    private val sightings = LinkedHashMap<String, Long>()
    private val outcomes = ArrayDeque<Pair<Long, Boolean>>()

    fun sighted(address: String, at: Long) {
        sightings[address] = at
    }

    fun dialEnded(at: Long, failed: Boolean) {
        outcomes.addLast(at to failed)
    }

    fun evaluate(now: Long) {
        sightings.values.removeAll { it < now - DENSITY_WINDOW_MS }
        while (outcomes.firstOrNull()?.let { it.first < now - FAILURE_WINDOW_MS } == true) outcomes.removeFirst()
        density = sightings.size
        ended = outcomes.size
        failed = outcomes.count { it.second }
        crowdLevel.step(
            when {
                density >= CROWDED_DENSITY -> Level.CROWDED
                density >= BUSY_DENSITY -> Level.BUSY
                else -> Level.CLEAR
            },
            now,
        )
        val counted = ended >= MIN_OUTCOMES
        channelLevel.step(
            when {
                counted && failed * 2 >= ended -> Level.CROWDED
                counted && failed * 4 >= ended -> Level.BUSY
                else -> Level.CLEAR
            },
            now,
        )
    }

    /** Rises at once; falls one level after a lower target held for [FALL_AFTER_MS]. */
    private class Hysteresis {
        var level = Level.CLEAR
            private set
        private var lowerSince: Long? = null

        fun step(target: Level, now: Long) {
            val since = lowerSince
            when {
                target >= level -> {
                    level = target
                    lowerSince = null
                }
                since == null -> lowerSince = now
                now - since >= FALL_AFTER_MS -> {
                    level = Level.entries[level.ordinal - 1]
                    lowerSince = now
                }
            }
        }
    }

    private companion object {
        const val DENSITY_WINDOW_MS = 30_000L
        const val FAILURE_WINDOW_MS = 60_000L
        const val FALL_AFTER_MS = 60_000L
        const val MIN_OUTCOMES = 4
        const val BUSY_DENSITY = 4
        const val CROWDED_DENSITY = 8
    }
}
