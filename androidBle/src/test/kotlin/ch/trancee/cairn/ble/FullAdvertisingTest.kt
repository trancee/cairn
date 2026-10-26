package ch.trancee.cairn.ble

import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY
import android.bluetooth.le.AdvertiseSettings.ADVERTISE_MODE_LOW_POWER
import android.os.Build
import android.os.Looper
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadow.api.Shadow
import org.robolectric.shadows.ShadowLog
import java.time.Duration
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** A full radio advertises while it could evict, and evicts for a device that connects (spec §10.4, ADR 0032). */
@RunWith(RobolectricTestRunner::class)
@Config(shadows = [RecordingAdvertiser::class])
class FullAdvertisingTest {
    private val h = RadioHarness().also { it.radio.start() }
    private val slots = if (Build.VERSION.SDK_INT >= 35) 6 else 5
    private val quota = slots * 3 / 4
    private val newcomer = address(30)

    private fun address(i: Int) = "00:11:22:33:44:%02X".format(i)

    private fun advance(ms: Long) = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(ms))

    private fun modes() = Shadow.extract<RecordingAdvertiser>(h.adapter.bluetoothLeAdvertiser).modes

    private fun advertising() = shadowOf(h.adapter.bluetoothLeAdvertiser).advertisementRequestCount

    private fun downs() = h.listener.events.filter { it.startsWith("down") }

    private fun logs() = ShadowLog.getLogsForTag("CairnRadio").map { it.msg }

    /** Links 1..[quota] are the strongest and stay; the rest rotate. */
    private fun link(i: Int): BluetoothGatt =
        h.discover(address(i))!!.also { h.shadow(it).setRssi(if (i <= quota) -40 else -90) }.also(h::connect)

    private fun fill() = (1..slots).map(::link)

    private fun serverConnect(address: String) {
        h.serverCallback().onConnectionStateChange(h.device(address), 0, BluetoothProfile.STATE_CONNECTED)
        h.idle()
    }

    private fun cancelled(address: String) = shadowOf(h.server).isConnectionCancelled(h.device(address))

    @Test
    fun stopsAdvertisingWhileNoLinkCanBeEvicted() {
        fill()

        assertEquals(0, advertising())
    }

    @Test
    fun advertisesAtLowPowerOnceALinkCanBeEvicted() {
        fill()

        advance(30_000)

        assertEquals(1, advertising())
        assertEquals(ADVERTISE_MODE_LOW_POWER, modes().last())
    }

    @Test
    fun staysStoppedWhileEveryLinkIsStable() {
        (1..quota).forEach(::link)
        (quota + 1..slots).forEach { serverConnect(address(40 + it)) }

        advance(120_000)

        assertEquals(0, advertising())
    }

    @Test
    fun stopsForFifteenSecondsAfterAnEviction() {
        fill()
        advance(30_000)
        serverConnect(newcomer)
        val afterEviction = advertising()

        advance(15_000)

        assertEquals(0, afterEviction)
        assertEquals(1, advertising())
    }

    @Test
    fun returnsToTheBandModeOnceASlotFrees() {
        val gatts = fill()
        advance(30_000)

        h.callback(gatts.last()).onConnectionStateChange(gatts.last(), 0, BluetoothProfile.STATE_DISCONNECTED)
        h.idle()

        assertEquals(1, advertising())
        assertEquals(ADVERTISE_MODE_LOW_LATENCY, modes().last())
    }

    @Test
    fun rotatesTheAdvertWhileFull() {
        fill()
        advance(30_000)
        val started = modes().size

        advance(330_000)

        assertTrue(modes().size > started)
        assertEquals(setOf(ADVERTISE_MODE_LOW_POWER), modes().drop(started).toSet())
    }

    @Test
    fun logsWhenItStopsSlowsAndResumes() {
        val gatts = fill()
        advance(30_000)
        h.callback(gatts.last()).onConnectionStateChange(gatts.last(), 0, BluetoothProfile.STATE_DISCONNECTED)
        h.idle()

        assertEquals(
            listOf("slots full; advertising stopped", "slots full; advertising slowed", "slot free; advertising resumed"),
            logs().filter { it.startsWith("slot") && "advertising" in it },
        )
    }

    @Test
    fun evictsAnIdleRotatingLinkForADeviceThatConnects() {
        fill()
        advance(30_000)

        serverConnect(newcomer)

        assertEquals(listOf("down ${quota + 1}"), downs())
        assertFalse(cancelled(newcomer))
    }

    @Test
    fun logsAnEvictionForADeviceThatConnects() {
        fill()
        advance(30_000)

        serverConnect(newcomer)

        assertTrue(logs().single { it.startsWith("slots full; evicting") }.endsWith("for ${newcomer.takeLast(5)} (connect)"))
    }

    @Test
    fun logsADeviceThatItDisconnects() {
        fill()
        advance(29_999)

        serverConnect(newcomer)

        assertEquals("slots full; disconnecting ${newcomer.takeLast(5)}", logs().last())
    }

    @Test
    fun disconnectsADeviceThatConnectsWhileNoLinkIsIdle() {
        fill()
        advance(29_999)

        serverConnect(newcomer)

        assertEquals(emptyList(), downs())
        assertTrue(cancelled(newcomer))
    }

    @Test
    fun evictsForADeviceThatConnectsAtMostOnceEveryFifteenSeconds() {
        fill()
        advance(30_000)
        serverConnect(newcomer)
        advance(14_999)

        serverConnect(address(31))

        assertEquals(1, downs().size)
        assertTrue(cancelled(address(31)))
    }
}
