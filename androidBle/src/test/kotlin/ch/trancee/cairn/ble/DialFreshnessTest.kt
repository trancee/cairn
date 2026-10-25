package ch.trancee.cairn.ble

import android.bluetooth.BluetoothGatt
import android.content.Intent
import android.os.BatteryManager
import android.os.Looper
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.shadows.ShadowLog
import java.time.Duration
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** Spec §10.4 (ADR 0029): a dial fails once its target has gone unseen for the band's limit. */
@RunWith(RobolectricTestRunner::class)
class DialFreshnessTest {
    private val h = RadioHarness()
    private val target = "00:11:22:33:44:01"

    private fun advance(ms: Long) = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(ms))

    private fun closed(gatt: BluetoothGatt) = h.shadow(gatt).isClosed

    @Suppress("DEPRECATION")
    private fun battery(level: Int) {
        h.context.sendStickyBroadcast(
            Intent(Intent.ACTION_BATTERY_CHANGED)
                .putExtra(BatteryManager.EXTRA_LEVEL, level)
                .putExtra(BatteryManager.EXTRA_SCALE, 100)
                .putExtra(BatteryManager.EXTRA_PLUGGED, 0),
        )
        h.idle()
    }

    private fun dial(): BluetoothGatt {
        h.radio.start()
        return h.discover(target)!!
    }

    /** Keeps [target] in sight every second for [ms]. */
    private fun keepSeeing(ms: Long) = repeat((ms / 1_000).toInt()) {
        advance(1_000)
        h.sight(target)
    }

    @Test
    fun aDialToATargetUnseenForTwoSecondsInFullFails() {
        val gatt = dial()
        advance(2_000)
        assertFalse(closed(gatt))

        advance(500)

        assertTrue(closed(gatt))
        assertEquals(1_000L..5_000L, h.random.ranges.last())
        assertTrue(ShadowLog.getLogsForTag("CairnRadio").any { "dial 44:01 stale, unseen 2500 ms" in it.msg })
    }

    @Test
    fun aDialToATargetStillSeenStaysPending() {
        val gatt = dial()

        keepSeeing(9_000)

        assertFalse(closed(gatt))
    }

    @Test
    fun theLimitIsFiveSecondsInSave() {
        battery(40)
        val gatt = dial()
        advance(5_000)
        assertFalse(closed(gatt))

        advance(500)

        assertTrue(closed(gatt))
    }

    @Test
    fun theLimitIsSevenSecondsInLow() {
        battery(10)
        val gatt = dial()
        advance(7_000)
        assertFalse(closed(gatt))

        advance(500)

        assertTrue(closed(gatt))
    }

    @Test
    fun aBandChangeAppliesToADialInFlight() {
        battery(10)
        val gatt = dial()
        advance(2_000)
        assertFalse(closed(gatt))

        battery(100)
        advance(500)

        assertTrue(closed(gatt))
    }

    @Test
    fun aConnectedTargetNoLongerSeenStaysUp() {
        val gatt = dial()
        h.connect(gatt)

        advance(9_000)

        assertFalse(closed(gatt))
        assertEquals(listOf("up 1 CENTRAL"), h.listener.events.filter { it.startsWith("up") || it.startsWith("down") }.map { it.substringBeforeLast(" ").substringBeforeLast(" ") })
    }
}
