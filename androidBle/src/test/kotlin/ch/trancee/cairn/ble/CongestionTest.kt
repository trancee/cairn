package ch.trancee.cairn.ble

import ch.trancee.cairn.ble.Congestion.Level.BUSY
import ch.trancee.cairn.ble.Congestion.Level.CLEAR
import ch.trancee.cairn.ble.Congestion.Level.CROWDED
import org.junit.Test
import kotlin.test.assertEquals

/** The congestion levels of spec §10.4 (ADR 0026). */
class CongestionTest {
    private val c = Congestion()

    private fun sight(n: Int, at: Long) = (1..n).forEach { c.sighted("peer$it", at) }

    private fun dials(ok: Int, failed: Int, at: Long) {
        repeat(ok) { c.dialEnded(at, failed = false) }
        repeat(failed) { c.dialEnded(at, failed = true) }
    }

    @Test
    fun startsClear() = assertEquals(CLEAR, c.level)

    @Test
    fun densityRaisesTheLevel() {
        sight(3, 0)
        assertEquals(CLEAR, c.evaluate(0))
        sight(4, 0)
        assertEquals(BUSY, c.evaluate(0))
        sight(8, 0)
        assertEquals(CROWDED, c.evaluate(0))
    }

    @Test
    fun densityCountsAddressesSeenInTheLast30Seconds() {
        sight(8, 0)
        c.sighted("peer1", 1)

        assertEquals(CROWDED, c.evaluate(30_000))
        assertEquals(CLEAR, Congestion().also { it.sighted("a", 0) }.evaluate(30_001))
    }

    @Test
    fun failureRateRaisesTheLevel() {
        dials(ok = 3, failed = 1, at = 0)
        assertEquals(BUSY, c.evaluate(0))
        dials(ok = 0, failed = 2, at = 0)
        assertEquals(CROWDED, c.evaluate(0))
    }

    @Test
    fun ignoresTheFailureRateOfFewerThanFourDials() {
        dials(ok = 0, failed = 3, at = 0)

        assertEquals(CLEAR, c.evaluate(0))
    }

    @Test
    fun failureRateCoversTheLast60Seconds() {
        dials(ok = 0, failed = 4, at = 0)

        assertEquals(CROWDED, c.evaluate(60_000))
        assertEquals(CLEAR, Congestion().also { x -> repeat(4) { x.dialEnded(0, failed = true) } }.evaluate(60_001))
    }

    @Test
    fun fallsOneLevelOnlyAfterTheLowerLevelHeldFor60Seconds() {
        sight(8, 0)
        c.evaluate(0)

        assertEquals(CROWDED, c.evaluate(30_005))
        assertEquals(CROWDED, c.evaluate(90_000))
        assertEquals(BUSY, c.evaluate(90_005))
        assertEquals(BUSY, c.evaluate(150_000))
        assertEquals(CLEAR, c.evaluate(150_005))
    }

    @Test
    fun aHigherEvaluationRestartsTheFall() {
        sight(8, 0)
        c.evaluate(0)
        c.evaluate(30_005)
        sight(8, 60_000)
        c.evaluate(60_000)

        assertEquals(CROWDED, c.evaluate(120_004))
        assertEquals(CROWDED, c.evaluate(150_000))
    }

    @Test
    fun aFallToBusyFromCrowdedWaitsEvenWhenTheTargetIsClear() {
        sight(8, 0)
        c.evaluate(0)

        assertEquals(CROWDED, c.evaluate(30_001))
        assertEquals(BUSY, c.evaluate(90_001))
    }
}
