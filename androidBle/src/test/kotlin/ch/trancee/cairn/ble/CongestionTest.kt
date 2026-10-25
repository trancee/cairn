package ch.trancee.cairn.ble

import ch.trancee.cairn.ble.Congestion.Level.BUSY
import ch.trancee.cairn.ble.Congestion.Level.CLEAR
import ch.trancee.cairn.ble.Congestion.Level.CROWDED
import org.junit.Test
import kotlin.test.assertEquals

/** The crowd and channel levels of spec §10.4 (ADR 0026). */
class CongestionTest {
    private val c = Congestion()

    private fun sight(n: Int, at: Long) = (1..n).forEach { c.sighted("peer$it", at) }

    private fun dials(ok: Int, failed: Int, at: Long) {
        repeat(ok) { c.dialEnded(at, failed = false) }
        repeat(failed) { c.dialEnded(at, failed = true) }
    }

    @Test
    fun startsClear() {
        assertEquals(CLEAR, c.crowd)
        assertEquals(CLEAR, c.channel)
    }

    @Test
    fun densityRaisesTheCrowdLevelOnly() {
        sight(3, 0)
        c.evaluate(0)
        val few = c.crowd
        sight(4, 0)
        c.evaluate(0)
        val busy = c.crowd
        sight(8, 0)
        c.evaluate(0)

        assertEquals(listOf(CLEAR, BUSY, CROWDED), listOf(few, busy, c.crowd))
        assertEquals(CLEAR, c.channel)
    }

    @Test
    fun densityCountsAddressesSeenInTheLast30Seconds() {
        sight(8, 0)
        c.sighted("peer1", 1)
        c.evaluate(30_000)
        val inWindow = c.crowd
        val late = Congestion().also { it.sighted("a", 0) }.also { it.evaluate(30_001) }

        assertEquals(CROWDED, inWindow)
        assertEquals(0, late.density)
    }

    @Test
    fun failureRateRaisesTheChannelLevelOnly() {
        dials(ok = 3, failed = 1, at = 0)
        c.evaluate(0)
        val busy = c.channel
        dials(ok = 0, failed = 2, at = 0)
        c.evaluate(0)

        assertEquals(listOf(BUSY, CROWDED), listOf(busy, c.channel))
        assertEquals(CLEAR, c.crowd)
    }

    @Test
    fun ignoresTheFailureRateOfFewerThanFourDials() {
        dials(ok = 0, failed = 3, at = 0)
        c.evaluate(0)

        assertEquals(CLEAR, c.channel)
    }

    @Test
    fun failureRateCoversTheLast60Seconds() {
        dials(ok = 0, failed = 4, at = 0)
        c.evaluate(60_000)
        val inWindow = c.ended
        c.evaluate(60_001)

        assertEquals(4, inWindow)
        assertEquals(0, c.ended)
    }

    @Test
    fun fallsOneLevelOnlyAfterTheLowerLevelHeldFor60Seconds() {
        sight(8, 0)
        c.evaluate(0)
        val levels = listOf(30_005L, 90_000L, 90_005L, 150_000L, 150_005L).map {
            c.evaluate(it)
            c.crowd
        }

        assertEquals(listOf(CROWDED, CROWDED, BUSY, BUSY, CLEAR), levels)
    }

    @Test
    fun aHigherEvaluationRestartsTheFall() {
        sight(8, 0)
        c.evaluate(0)
        c.evaluate(30_005)
        sight(8, 60_000)
        c.evaluate(60_000)
        c.evaluate(120_004)
        c.evaluate(150_000)

        assertEquals(CROWDED, c.crowd)
    }

    @Test
    fun aFallFromCrowdedStopsAtBusyEvenWhenTheTargetIsClear() {
        sight(8, 0)
        c.evaluate(0)
        c.evaluate(30_001)
        c.evaluate(90_001)

        assertEquals(BUSY, c.crowd)
    }

    @Test
    fun theChannelFallsOnItsOwnClock() {
        dials(ok = 0, failed = 4, at = 0)
        c.evaluate(0)
        c.evaluate(60_001)
        c.evaluate(120_000)
        val held = c.channel
        c.evaluate(120_001)

        assertEquals(CROWDED, held)
        assertEquals(BUSY, c.channel)
    }
}
