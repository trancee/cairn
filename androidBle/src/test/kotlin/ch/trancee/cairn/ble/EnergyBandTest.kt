package ch.trancee.cairn.ble

import ch.trancee.cairn.ble.EnergyBand.FULL
import ch.trancee.cairn.ble.EnergyBand.LOW
import ch.trancee.cairn.ble.EnergyBand.SAVE
import org.junit.Test
import kotlin.test.assertEquals

/** The energy bands of spec §10.4 (ADR 0027). */
class EnergyBandTest {
    private fun next(from: EnergyBand, level: Int, plugged: Boolean = false, saver: Boolean = false) =
        EnergyBand.next(from, level, plugged, saver)

    @Test
    fun levelSelectsTheBand() {
        assertEquals(
            listOf(LOW, SAVE, SAVE, FULL),
            listOf(19, 20, 50, 51).map { next(FULL, it) },
        )
    }

    @Test
    fun pluggedInIsFullAtAnyLevel() {
        assertEquals(FULL, next(LOW, 1, plugged = true))
    }

    @Test
    fun batterySaverIsSaveAboveTwentyPercent() {
        assertEquals(SAVE, next(FULL, 90, saver = true))
        assertEquals(LOW, next(FULL, 10, saver = true))
    }

    @Test
    fun lowEndsAtTwentyFivePercent() {
        assertEquals(listOf(LOW, SAVE), listOf(24, 25).map { next(LOW, it) })
    }

    @Test
    fun saveEndsAboveFiftyFivePercent() {
        assertEquals(listOf(SAVE, FULL), listOf(55, 56).map { next(SAVE, it) })
        assertEquals(SAVE, next(LOW, 55))
    }

    @Test
    fun saverOffEndsSaveAtOnceAboveFiftyFivePercent() {
        assertEquals(FULL, next(SAVE, 90))
    }
}
