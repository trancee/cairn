package ch.trancee.cairn.ble

/** The energy band of spec §10.4 (ADR 0027), from battery level, plug state and Battery Saver. */
internal enum class EnergyBand {
    FULL,
    SAVE,
    LOW,
    ;

    companion object {
        /**
         * The band after [from], at battery [level] in percent. A band set by level ends only
         * [HYSTERESIS] points above its threshold; plugging in and Battery Saver act at once.
         */
        fun next(from: EnergyBand, level: Int, plugged: Boolean, saver: Boolean): EnergyBand {
            val low = LOW_BELOW + if (from == LOW) HYSTERESIS else 0
            val save = SAVE_AT_MOST + if (from != FULL) HYSTERESIS else 0
            return when {
                plugged -> FULL
                level < low -> LOW
                saver || level <= save -> SAVE
                else -> FULL
            }
        }

        private const val LOW_BELOW = 20
        private const val SAVE_AT_MOST = 50
        private const val HYSTERESIS = 5
    }
}
