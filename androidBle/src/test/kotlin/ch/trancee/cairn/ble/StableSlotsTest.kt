package ch.trancee.cairn.ble

import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothProfile
import android.content.Intent
import android.os.BatteryManager
import android.os.Build
import android.os.Looper
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.shadows.ShadowLog
import java.time.Duration
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** A full radio keeps its strongest links and evicts only the rest (spec §10.4, ADR 0031). */
@RunWith(RobolectricTestRunner::class)
class StableSlotsTest {
    private val h = RadioHarness().also { it.radio.start() }
    private val slots = if (Build.VERSION.SDK_INT >= 35) 6 else 5
    private val quota = slots * 3 / 4
    private val waiting = address(30)

    private fun address(i: Int) = "00:11:22:33:44:%02X".format(i)

    private fun advance(ms: Long) = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(ms))

    private fun central(i: Int, rssi: Int): BluetoothGatt =
        h.discover(address(i))!!.also { h.shadow(it).setRssi(rssi) }.also(h::connect)

    private fun peripheral(i: Int) {
        val device = h.device(address(i))
        h.serverCallback().onConnectionStateChange(device, 0, BluetoothProfile.STATE_CONNECTED)
        h.idle()
        h.subscribe(device)
    }

    private fun downs() = h.listener.events.filter { it.startsWith("down") }

    private fun logs() = ShadowLog.getLogsForTag("CairnRadio").map { it.msg }

    @Test
    fun keepsTheStrongestLinksUpSixtySeconds() {
        central(1, -41)
        advance(10_000)
        (2..slots).forEach { central(it, -40 - it) }
        advance(60_000)

        h.sight(waiting)

        assertEquals(listOf("down ${quota + 1}"), downs())
    }

    @Test
    fun aStrongLinkIsStableAsSoonAsItIsMeasured() {
        central(1, -41)
        advance(10_000)
        (2..slots).forEach { central(it, -40 - it) }
        advance(30_000)

        h.sight(waiting)

        assertEquals(listOf("down ${quota + 1}"), downs())
    }

    @Test
    fun ranksAPeripheralLinkByItsScanRssi() {
        peripheral(1)
        advance(10_000)
        (2..slots).forEach { central(it, -80 - it) }
        advance(60_000)
        h.sight(address(1), rssi = -30)

        h.sight(waiting)

        assertEquals(listOf("down ${quota + 1}"), downs())
    }

    @Test
    fun ranksLinksWithoutAFreshRssiAfterMeasuredOnes() {
        peripheral(1)
        advance(10_000)
        (2..slots).forEach { central(it, -80 - it) }
        advance(30_000)
        h.sight(address(1), rssi = -30)
        advance(30_001)

        h.sight(waiting)

        assertEquals(listOf("down 1"), downs())
    }

    @Test
    fun ranksUnmeasuredLinksByAge() {
        peripheral(1)
        advance(10_000)
        (2..slots).forEach(::peripheral)
        advance(60_000)

        h.sight(waiting)

        assertEquals(listOf("down ${quota + 1}"), downs())
    }

    @Test
    fun theQuotaFollowsTheEnergyBand() {
        (1..3).forEach { central(it, -40 - it) }
        advance(10_000)
        (4..slots).forEach { central(it, -40 - it) }
        @Suppress("DEPRECATION")
        h.context.sendStickyBroadcast(
            Intent(Intent.ACTION_BATTERY_CHANGED)
                .putExtra(BatteryManager.EXTRA_LEVEL, 10)
                .putExtra(BatteryManager.EXTRA_SCALE, 100),
        )
        advance(30_000)

        h.sight(waiting)

        assertEquals(listOf("down 3"), downs())
    }

    @Test
    fun evictsNothingWhenEveryLinkIsStable() {
        (1..quota).forEach { central(it, -50) }
        (quota + 1..slots).forEach {
            h.serverCallback().onConnectionStateChange(h.device(address(it)), 0, BluetoothProfile.STATE_CONNECTED)
        }
        h.idle()
        advance(60_000)

        h.sight(waiting)

        assertEquals(emptyList(), downs())
    }

    @Test
    fun ignoresAFailedRssiReading() {
        val gatt = central(1, -30)

        h.callback(gatt).onReadRemoteRssi(gatt, -20, BluetoothGatt.GATT_FAILURE)
        h.idle()

        assertTrue(logs().none { it.contains("rssi") })
    }

    @Test
    fun logsEachCentralRssiReading() {
        central(1, -55)

        advance(10_000)

        assertEquals("link 1 rssi -55", logs().last())
    }

    @Test
    fun logsTheRssiOfTheEvictedLink() {
        peripheral(1)
        advance(10_000)
        (2..slots).forEach { central(it, -80 - it) }
        advance(60_000)

        h.sight(waiting)

        assertEquals(
            "slots full; evicting link 1 idle 70000 ms rssi unknown for 44:1E",
            logs().single { it.startsWith("slots full; evicting") },
        )
    }
}
