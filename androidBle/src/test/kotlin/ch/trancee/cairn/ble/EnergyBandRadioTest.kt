package ch.trancee.cairn.ble

import android.bluetooth.BluetoothProfile
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.ScanSettings
import android.content.Intent
import android.os.BatteryManager
import android.os.Looper
import android.os.PowerManager
import java.time.Duration
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadow.api.Shadow
import org.robolectric.shadows.ShadowLog

/** Spec §10.4 (ADR 0027): the radio's modes and slot budget follow the energy band. */
@RunWith(RobolectricTestRunner::class)
@Config(shadows = [RecordingAdvertiser::class])
class EnergyBandRadioTest {
    private val h = RadioHarness()

    @Suppress("DEPRECATION")
    private fun battery(level: Int, plugged: Boolean = false) {
        h.context.sendStickyBroadcast(
            Intent(Intent.ACTION_BATTERY_CHANGED)
                .putExtra(BatteryManager.EXTRA_LEVEL, level)
                .putExtra(BatteryManager.EXTRA_SCALE, 100)
                .putExtra(BatteryManager.EXTRA_PLUGGED, if (plugged) BatteryManager.BATTERY_PLUGGED_AC else 0),
        )
        h.idle()
    }

    private fun saver(on: Boolean) {
        shadowOf(h.context.getSystemService(PowerManager::class.java)).setIsPowerSaveMode(on)
        h.context.sendBroadcast(Intent(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED))
        h.idle()
    }

    private fun advance(ms: Long) = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(ms))

    private fun scanMode() = shadowOf(h.adapter.bluetoothLeScanner).activeScans.single().scanSettings()!!.scanMode

    private fun advertiseModes() = Shadow.extract<RecordingAdvertiser>(h.adapter.bluetoothLeAdvertiser).modes

    private fun advertising() = shadowOf(h.adapter.bluetoothLeAdvertiser).advertisementRequestCount

    private fun connectServer(n: Int) = (1..n).map { h.device("00:11:22:33:66:%02X".format(it)) }.onEach {
        h.serverCallback().onConnectionStateChange(it, 0, BluetoothProfile.STATE_CONNECTED)
        h.idle()
    }

    private fun logged(text: String) = ShadowLog.getLogsForTag("CairnRadio").any { text in it.msg }

    @Test
    fun unknownBatteryIsFull() {
        h.radio.start()

        assertEquals(ScanSettings.SCAN_MODE_LOW_LATENCY, scanMode())
        assertEquals(listOf(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY), advertiseModes())
    }

    @Test
    fun saveStartsBalanced() {
        battery(40)
        h.radio.start()

        assertEquals(ScanSettings.SCAN_MODE_BALANCED, scanMode())
        assertEquals(listOf(AdvertiseSettings.ADVERTISE_MODE_BALANCED), advertiseModes())
    }

    @Test
    fun lowStartsAtLowPower() {
        battery(10)
        h.radio.start()

        assertEquals(ScanSettings.SCAN_MODE_LOW_POWER, scanMode())
        assertEquals(listOf(AdvertiseSettings.ADVERTISE_MODE_LOW_POWER), advertiseModes())
    }

    @Test
    fun pluggedInIsFull() {
        battery(10, plugged = true)
        h.radio.start()

        assertEquals(ScanSettings.SCAN_MODE_LOW_LATENCY, scanMode())
    }

    @Test
    fun aBandChangeRestartsAdvertisingInTheNewMode() {
        h.radio.start()
        battery(40)

        assertEquals(
            listOf(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY, AdvertiseSettings.ADVERTISE_MODE_BALANCED),
            advertiseModes(),
        )
        assertEquals(1, advertising())
        assertTrue(logged("energy SAVE battery 40% plugged false saver false"))
    }

    @Test
    fun anUnchangedBandRestartsNothing() {
        battery(40)
        h.radio.start()
        advance(10_000)
        battery(39)

        assertEquals(listOf(AdvertiseSettings.ADVERTISE_MODE_BALANCED), advertiseModes())
    }

    @Test
    fun batterySaverSelectsSave() {
        h.radio.start()
        advance(10_000)
        saver(true)

        assertEquals(ScanSettings.SCAN_MODE_BALANCED, scanMode())
    }

    @Test
    fun restartsTheScanAtMostOnceEveryTenSeconds() {
        h.radio.start()
        advance(5_000)
        battery(40)
        val early = scanMode()

        advance(5_000)

        assertEquals(ScanSettings.SCAN_MODE_LOW_LATENCY, early)
        assertEquals(ScanSettings.SCAN_MODE_BALANCED, scanMode())
    }

    @Test
    fun aDeferredRestartUsesTheLatestBand() {
        h.radio.start()
        advance(5_000)
        battery(40)
        battery(90)

        advance(5_000)

        assertEquals(ScanSettings.SCAN_MODE_LOW_LATENCY, scanMode())
        assertEquals(1, shadowOf(h.adapter.bluetoothLeScanner).activeScans.size)
    }

    @Test
    fun lowCapsTheBudgetAtThreeSlots() {
        battery(10)
        h.radio.start()
        connectServer(3)
        val fourth = h.device("00:11:22:33:66:04")

        h.serverCallback().onConnectionStateChange(fourth, 0, BluetoothProfile.STATE_CONNECTED)
        h.idle()

        assertTrue(shadowOf(h.server).isConnectionCancelled(fourth))
    }

    @Test
    fun linksAboveALoweredCapStayUpAndAdvertisingSlows() {
        h.radio.start()
        val peers = connectServer(4)

        battery(10)

        assertTrue(peers.none { shadowOf(h.server).isConnectionCancelled(it) })
        assertEquals(1, advertising())
        assertEquals(AdvertiseSettings.ADVERTISE_MODE_LOW_POWER, advertiseModes().last())
    }

    @Test
    fun stopUnfollowsTheBattery() {
        h.radio.start()
        h.radio.stop()
        battery(10)

        assertEquals(listOf(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY), advertiseModes())
    }
}
