package ch.trancee.cairn.ble

import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.ScanSettings
import android.os.Looper
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

/** Spec §10.4 (ADR 0026): the radio follows the congestion level. */
@RunWith(RobolectricTestRunner::class)
@Config(shadows = [RecordingAdvertiser::class])
class CongestionLevelTest {
    private val h = RadioHarness().also { it.radio.start() }

    /** [n] peers whose beacon is lower than ours, so they count but are not dialled. */
    private fun crowd(n: Int) = (1..n).forEach { h.sight("00:11:22:33:55:%02X".format(it), ByteArray(8)) }

    private fun advance(ms: Long) = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(ms))

    private fun scanMode() = shadowOf(h.adapter.bluetoothLeScanner).activeScans.single().scanSettings()!!.scanMode

    private fun advertiseModes() = Shadow.extract<RecordingAdvertiser>(h.adapter.bluetoothLeAdvertiser).modes

    private fun dial(address: String): BluetoothGatt? {
        h.sight(address)
        return shadowOf(h.device(address)).bluetoothGatts.lastOrNull()
    }

    private fun fail(gatt: BluetoothGatt) {
        h.callback(gatt).onConnectionStateChange(gatt, 133, BluetoothProfile.STATE_DISCONNECTED)
        h.idle()
    }

    private fun logged(text: String) = ShadowLog.getLogsForTag("CairnRadio").any { text in it.msg }

    @Test
    fun clearScansAndAdvertisesAtLowLatency() {
        crowd(3)
        advance(10_000)

        assertEquals(ScanSettings.SCAN_MODE_LOW_LATENCY, scanMode())
        assertEquals(listOf(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY), advertiseModes())
    }

    @Test
    fun busyScansAndAdvertisesBalanced() {
        crowd(4)
        advance(10_000)

        assertEquals(ScanSettings.SCAN_MODE_BALANCED, scanMode())
        assertEquals(AdvertiseSettings.ADVERTISE_MODE_BALANCED, advertiseModes().last())
        assertTrue(logged("congestion BUSY density 4 failures 0/0"))
    }

    @Test
    fun crowdedScansAndAdvertisesAtLowPower() {
        crowd(8)
        advance(10_000)

        assertEquals(ScanSettings.SCAN_MODE_LOW_POWER, scanMode())
        assertEquals(AdvertiseSettings.ADVERTISE_MODE_LOW_POWER, advertiseModes().last())
    }

    @Test
    fun restartsTheScanAtMostOnceEveryTenSeconds() {
        crowd(4)
        advance(5_000)
        val early = scanMode()

        advance(5_000)

        assertEquals(ScanSettings.SCAN_MODE_LOW_LATENCY, early)
        assertEquals(ScanSettings.SCAN_MODE_BALANCED, scanMode())
    }

    @Test
    fun aFullRadioScansAtLowPowerUntilASlotFrees() {
        val peers = (1..6).map { h.device("00:11:22:33:66:%02X".format(it)) }
        peers.forEach { h.serverCallback().onConnectionStateChange(it, 0, BluetoothProfile.STATE_CONNECTED) }
        h.idle()
        advance(10_000)
        val full = scanMode()
        h.serverCallback().onConnectionStateChange(peers.first(), 0, BluetoothProfile.STATE_DISCONNECTED)
        h.serverCallback().onConnectionStateChange(peers.last(), 0, BluetoothProfile.STATE_DISCONNECTED)
        h.idle()
        advance(10_000)

        assertEquals(ScanSettings.SCAN_MODE_LOW_POWER, full)
        assertEquals(ScanSettings.SCAN_MODE_LOW_LATENCY, scanMode())
    }

    @Test
    fun aLevelChangeWhileFullAppliesWhenAdvertisingResumes() {
        val peers = (1..6).map { h.device("00:11:22:33:66:%02X".format(it)) }
        peers.forEach { h.serverCallback().onConnectionStateChange(it, 0, BluetoothProfile.STATE_CONNECTED) }
        h.idle()
        crowd(4)
        advance(5_000)
        val whileFull = advertiseModes().toList()
        peers.forEach { h.serverCallback().onConnectionStateChange(it, 0, BluetoothProfile.STATE_DISCONNECTED) }
        h.idle()

        assertEquals(listOf(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY), whileFull)
        assertEquals(AdvertiseSettings.ADVERTISE_MODE_BALANCED, advertiseModes().last())
    }

    @Test
    fun busyDialStartsAreOneSecondApart() {
        crowd(4)
        advance(5_000)
        h.connect(h.discover("00:11:22:33:44:01")!!)

        val early = dial("00:11:22:33:44:02")
        advance(999)
        val stillEarly = dial("00:11:22:33:44:02")
        advance(1)

        assertEquals(null, early)
        assertEquals(null, stillEarly)
        assertTrue(dial("00:11:22:33:44:02") != null)
    }

    @Test
    fun failedDialsDoubleTheGapUpToFourTimes() {
        crowd(4)
        advance(5_000)
        fail(dial("00:11:22:33:44:01")!!)
        advance(1_000)
        fail(dial("00:11:22:33:44:02")!!)
        advance(1_999)
        val beforeDouble = dial("00:11:22:33:44:03")
        advance(1)
        fail(dial("00:11:22:33:44:03")!!)
        advance(3_999)
        val beforeQuadruple = dial("00:11:22:33:44:04")
        advance(1)
        fail(dial("00:11:22:33:44:04")!!)
        advance(4_000)

        assertEquals(null, beforeDouble)
        assertEquals(null, beforeQuadruple)
        assertTrue(dial("00:11:22:33:44:05") != null)
    }

    @Test
    fun busyDialsTimeOutAfterFiveSeconds() {
        crowd(4)
        advance(5_000)
        dial("00:11:22:33:44:01")!!
        advance(4_999)
        val early = logged("dial 44:01 timed out")

        advance(1)

        assertEquals(false, early)
        assertTrue(logged("dial 44:01 timed out"))
    }
}
