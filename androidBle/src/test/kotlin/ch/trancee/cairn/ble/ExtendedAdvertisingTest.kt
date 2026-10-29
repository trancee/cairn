package ch.trancee.cairn.ble

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.AdvertisingSetCallback
import android.bluetooth.le.AdvertisingSetParameters
import android.bluetooth.le.ScanSettings
import android.content.Intent
import android.os.BatteryManager
import android.os.Looper
import android.os.ParcelUuid
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadow.api.Shadow
import org.robolectric.shadows.ShadowLog
import java.time.Duration
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** Spec §10.1, §10.4 (ADR 0028): extended connectable advertising where the controller supports it. */
@RunWith(RobolectricTestRunner::class)
@Config(shadows = [RecordingAdvertiser::class])
class ExtendedAdvertisingTest {
    private val h = RadioHarness()
    private val recorder get() = Shadow.extract<RecordingAdvertiser>(h.adapter.bluetoothLeAdvertiser)
    private val advertiser get() = shadowOf(h.adapter.bluetoothLeAdvertiser)

    private fun supported() = shadowOf(h.adapter).setIsLeExtendedAdvertisingSupported(true)

    private fun advance(ms: Long) = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(ms))

    private fun scanSettings() = shadowOf(h.adapter.bluetoothLeScanner).activeScans.single().scanSettings()!!

    private fun intervals() = recorder.sets.map { it.first.interval }

    @Test
    fun advertisesAnExtendedConnectableSetWhereSupported() {
        supported()

        h.radio.start()

        val parameters = recorder.sets.single().first
        assertFalse(parameters.isLegacy)
        assertTrue(parameters.isConnectable)
        assertFalse(parameters.isScannable)
        assertEquals(AdvertisingSetParameters.INTERVAL_LOW, parameters.interval)
        assertContentEquals(
            h.listener.beaconValue,
            advertiser.lastAdvertisingData.serviceData.getValue(ParcelUuid(GattProfile.SERVICE)),
        )
        assertEquals(0, advertiser.advertisementRequestCount)
    }

    // Robolectric fakes isLe2MPhySupported only from API 34.
    private fun supports2m() {
        supported()
        shadowOf(h.adapter).setIsLe2MPhySupported(true)
    }

    private fun secondaryPhys() = recorder.sets.map { it.first.secondaryPhy }

    private fun logged(message: String) = ShadowLog.getLogsForTag("CairnRadio").any { it.msg == message }

    // An advert without service data is one only iOS sends (spec §10.4, ADR 0038).
    private fun sightIos() = h.sight("00:11:22:33:77:01")

    @Test
    @Config(sdk = [37])
    fun sendsTheAuxiliaryPacketOn1mUntilAnIosPeerIsSeen() {
        supports2m()

        h.radio.start()
        h.sight("00:11:22:33:77:02", beacon = ByteArray(16))

        val parameters = recorder.sets.single().first
        assertEquals(BluetoothDevice.PHY_LE_1M, parameters.primaryPhy)
        assertEquals(BluetoothDevice.PHY_LE_1M, parameters.secondaryPhy)
    }

    @Test
    @Config(sdk = [37])
    fun movesTheAuxiliaryPacketTo2mWhenAnIosPeerIsSeenSoIosReportsIt() {
        supports2m()
        h.radio.start()

        sightIos()
        sightIos()

        assertEquals(listOf(BluetoothDevice.PHY_LE_1M, BluetoothDevice.PHY_LE_2M), secondaryPhys())
        assertEquals(BluetoothDevice.PHY_LE_1M, recorder.sets.last().first.primaryPhy)
        assertEquals(listOf(recorder.sets.last().second), recorder.activeSets)
        assertTrue(logged("advertising extended 2M"))
    }

    @Test
    @Config(sdk = [37])
    fun returnsTo1mAtTheFirstRotationAWindowAfterTheLastIosSighting() {
        supports2m()
        h.radio.start()
        sightIos()

        advance(200_000)
        advance(300_000)

        assertEquals(listOf(BluetoothDevice.PHY_LE_1M, BluetoothDevice.PHY_LE_2M, BluetoothDevice.PHY_LE_2M, BluetoothDevice.PHY_LE_1M), secondaryPhys())
        assertTrue(logged("advertising extended 1M"))
    }

    @Test
    @Config(sdk = [37])
    fun anotherIosSightingKeeps2mThroughTheRotation() {
        supports2m()
        h.radio.start()
        sightIos()
        advance(250_000)

        sightIos()
        advance(250_000)

        assertEquals(listOf(BluetoothDevice.PHY_LE_1M, BluetoothDevice.PHY_LE_2M, BluetoothDevice.PHY_LE_2M, BluetoothDevice.PHY_LE_2M), secondaryPhys())
    }

    @Test
    @Config(sdk = [37])
    fun anIosPeerSeenWhileTheSlotsAreFullGets2mOnceASlotFrees() {
        supports2m()
        h.radio.start()
        val devices = (1..6).map { h.device("00:11:22:33:66:%02X".format(it)) }
        devices.forEach { h.serverCallback().onConnectionStateChange(it, 0, BluetoothProfile.STATE_CONNECTED) }
        h.idle()

        sightIos()
        h.serverCallback().onConnectionStateChange(devices[0], 0, BluetoothProfile.STATE_DISCONNECTED)
        h.idle()

        assertEquals(listOf(BluetoothDevice.PHY_LE_1M, BluetoothDevice.PHY_LE_2M), secondaryPhys())
    }

    @Test
    fun keepsTheAuxiliaryPacketOn1mWithout2m() {
        supported()
        shadowOf(h.adapter).setIsLe2MPhySupported(false)
        h.radio.start()

        sightIos()

        assertEquals(listOf(BluetoothDevice.PHY_LE_1M), secondaryPhys())
    }

    @Test
    @Config(sdk = [37])
    fun anIosPeerLeavesALegacyAdvertAlone() {
        shadowOf(h.adapter).setIsLe2MPhySupported(true)
        h.radio.start()

        sightIos()

        assertEquals(1, advertiser.advertisementRequestCount)
        assertEquals(emptyList(), recorder.sets)
    }

    @Test
    fun stopStopsTheSet() {
        supported()
        h.radio.start()

        h.radio.stop()

        assertEquals(emptyList(), recorder.activeSets)
    }

    @Test
    fun restartsTheSetAtTheWindowBoundary() {
        supported()
        h.radio.start()

        advance(230_000)

        assertEquals(2, recorder.sets.size)
        assertEquals(listOf(recorder.sets.last().second), recorder.activeSets)
    }

    @Test
    fun restartsTheSetAtTheBandsInterval() {
        supported()
        h.radio.start()

        battery(40)

        assertEquals(listOf(AdvertisingSetParameters.INTERVAL_LOW, AdvertisingSetParameters.INTERVAL_MEDIUM), intervals())
        assertEquals(1, recorder.activeSets.size)
    }

    @Test
    fun stopsTheSetWhileTheSlotsAreFull() {
        supported()
        h.radio.start()

        (1..6).forEach {
            h.serverCallback().onConnectionStateChange(h.device("00:11:22:33:66:%02X".format(it)), 0, BluetoothProfile.STATE_CONNECTED)
        }
        h.idle()

        assertEquals(emptyList(), recorder.activeSets)
    }

    @Test
    fun advertisesLegacyUntilReopenedWhenTheSetFailsToStart() {
        supported()
        h.radio.start()

        recorder.sets.single().second.onAdvertisingSetStarted(null, 0, AdvertisingSetCallback.ADVERTISE_FAILED_INTERNAL_ERROR)
        h.idle()
        advance(230_000)

        assertEquals(1, recorder.sets.size)
        assertEquals(2, recorder.modes.size)
        assertEquals(1, advertiser.advertisementRequestCount)
        assertTrue(ShadowLog.getLogsForTag("CairnRadio").any { "advertising legacy" in it.msg })
    }

    @Test
    fun keepsTheSetThatStarted() {
        supported()
        h.radio.start()

        recorder.sets.single().second.onAdvertisingSetStarted(null, 0, AdvertisingSetCallback.ADVERTISE_SUCCESS)
        h.idle()

        assertEquals(1, recorder.activeSets.size)
        assertEquals(0, advertiser.advertisementRequestCount)
    }

    @Test
    fun scansForExtendedAdvertsWhereSupported() {
        supported()

        h.radio.start()

        assertFalse(scanSettings().legacy)
        assertEquals(ScanSettings.PHY_LE_ALL_SUPPORTED, scanSettings().phy)
    }

    @Test
    fun scansLegacyAndAdvertisesLegacyWithoutSupport() {
        h.radio.start()

        assertTrue(scanSettings().legacy)
        assertEquals(1, advertiser.advertisementRequestCount)
        assertEquals(emptyList(), recorder.sets)
    }

    @Test
    fun logsTheAdvertKindWhenOpened() {
        supported()

        h.radio.start()

        assertTrue(ShadowLog.getLogsForTag("CairnRadio").any { "advertising extended" in it.msg })
    }

    private fun battery(level: Int) {
        @Suppress("DEPRECATION")
        h.context.sendStickyBroadcast(
            Intent(Intent.ACTION_BATTERY_CHANGED)
                .putExtra(BatteryManager.EXTRA_LEVEL, level)
                .putExtra(BatteryManager.EXTRA_SCALE, 100),
        )
        h.idle()
    }

    private fun fail(set: Int) {
        recorder.sets[set].second.onAdvertisingSetStarted(null, 0, AdvertisingSetCallback.ADVERTISE_FAILED_INTERNAL_ERROR)
        h.idle()
    }

    @Test
    fun lowAdvertisesAtTheHighInterval() {
        supported()
        battery(10)

        h.radio.start()

        assertEquals(listOf(AdvertisingSetParameters.INTERVAL_HIGH), intervals())
    }

    @Test
    fun aFailureAfterStopStartsNothing() {
        supported()
        h.radio.start()
        h.radio.stop()

        fail(0)

        assertEquals(0, recorder.modes.size)
    }

    @Test
    fun twoFailedSetsFallBackOnce() {
        supported()
        h.radio.start()
        battery(40)

        fail(0)
        fail(1)

        assertEquals(1, recorder.modes.size)
    }

    @Test
    fun aFailureWhileTheSlotsAreFullAdvertisesLegacyOnceASlotFrees() {
        supported()
        h.radio.start()
        val devices = (1..6).map { h.device("00:11:22:33:66:%02X".format(it)) }
        devices.forEach { h.serverCallback().onConnectionStateChange(it, 0, BluetoothProfile.STATE_CONNECTED) }
        h.idle()

        fail(0)
        assertEquals(0, recorder.modes.size)
        h.serverCallback().onConnectionStateChange(devices[0], 0, BluetoothProfile.STATE_DISCONNECTED)
        h.idle()

        assertEquals(1, recorder.modes.size)
        assertEquals(1, recorder.sets.size)
    }

    private fun adapter(state: Int) {
        h.context.sendBroadcast(Intent(BluetoothAdapter.ACTION_STATE_CHANGED).putExtra(BluetoothAdapter.EXTRA_STATE, state))
        h.idle()
    }

    @Test
    fun bluetoothTurningBackOnStartsANewSet() {
        supported()
        h.radio.start()

        adapter(BluetoothAdapter.STATE_TURNING_OFF)
        adapter(BluetoothAdapter.STATE_ON)

        assertEquals(2, recorder.sets.size)
    }

    @Test
    fun aFailureOfTheSetBeforeBluetoothTurnedOffIsIgnored() {
        supported()
        h.radio.start()
        adapter(BluetoothAdapter.STATE_TURNING_OFF)
        adapter(BluetoothAdapter.STATE_ON)

        fail(0)

        assertEquals(0, recorder.modes.size)
    }
}
