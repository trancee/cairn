package ch.trancee.cairn.ble

import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.AdvertiseSettings
import android.content.Context
import android.os.ParcelUuid
import android.provider.Settings
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertSame
import kotlin.test.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowBluetoothAdapter

@RunWith(RobolectricTestRunner::class)
class RadioLifecycleTest {
    private val h = RadioHarness()

    @Test
    fun startAdvertisesAndScansForTheCairnService() {
        assertTrue(h.radio.start())

        val advertiser = shadowOf(h.adapter.bluetoothLeAdvertiser)
        assertEquals(1, advertiser.advertisementRequestCount)
        assertEquals(emptyList(), advertiser.lastAdvertisingData.serviceUuids)
        assertEquals(setOf(ParcelUuid(GattProfile.SERVICE)), advertiser.lastAdvertisingData.serviceData.keys)
        assertContentEquals(h.listener.beaconValue, advertiser.lastAdvertisingData.serviceData.getValue(ParcelUuid(GattProfile.SERVICE)))
        assertFalse(advertiser.lastAdvertisingData.includeDeviceName)
        assertEquals(1, shadowOf(h.adapter.bluetoothLeScanner).activeScans.size)
    }

    @Test
    fun startIsIdempotent() {
        h.radio.start()
        val server = h.server

        assertTrue(h.radio.start())

        assertSame(server, h.server)
        assertEquals(1, shadowOf(h.adapter.bluetoothLeScanner).activeScans.size)
    }

    @Test
    fun startDoesNotGateOnMultipleAdvertisementSupport() {
        shadowOf(h.adapter).setIsMultipleAdvertisementSupported(false)

        assertTrue(h.radio.start())

        assertEquals(1, shadowOf(h.adapter.bluetoothLeScanner).activeScans.size)
    }

    @Test
    fun startFailsWithoutABluetoothAdapter() {
        ShadowBluetoothAdapter.setIsBluetoothSupported(false)

        assertFalse(h.radio.start())
    }

    @Test
    fun startFailsWithoutTheBluetoothService() {
        shadowOf(h.context).setSystemService(Context.BLUETOOTH_SERVICE, null)

        assertFalse(AndroidRadio(h.context, android.os.Handler(android.os.Looper.getMainLooper())).start())
    }

    @Test
    fun startFailsWhileBluetoothIsOff() {
        shadowOf(h.adapter).setEnabled(false)

        assertFalse(h.radio.start())
        assertNull(h.radio.server)
    }

    @Test
    fun startFailsWhenTheScannerIsUnavailable() {
        Settings.Global.putInt(h.context.contentResolver, Settings.Global.AIRPLANE_MODE_ON, 1)

        assertFalse(h.radio.start())
    }

    @Test
    @Config(shadows = [NullGattShadows.Adapter::class])
    fun startFailsAndOpensNothingWhenTheAdvertiserIsUnavailable() {
        assertFalse(h.radio.start())

        assertNull(h.radio.server)
        assertEquals(0, shadowOf(h.adapter.bluetoothLeScanner).activeScans.size)
    }

    @Test
    fun scanResultsDeliveredAfterStopOpenNoConnection() {
        h.radio.start()
        val callback = h.scanCallback()
        val device = h.device("00:11:22:33:44:01")

        h.radio.stop()
        callback.onScanResult(0, android.bluetooth.le.ScanResult(device, null, -40, 0))
        h.idle()

        assertEquals(0, shadowOf(device).bluetoothGatts.size)
    }

    @Test
    @Config(shadows = [NullGattShadows.Manager::class])
    fun startFailsWhenTheGattServerCannotOpen() {
        assertFalse(h.radio.start())
    }

    @Test
    fun stopEndsEveryLinkAndRadioSession() {
        h.radio.start()
        val scanner = shadowOf(h.adapter.bluetoothLeScanner)
        val server = h.server
        val linked = h.discover("00:11:22:33:44:01")!!
        h.connect(linked)
        val pending = h.discover("00:11:22:33:44:02")!!
        h.subscribe(h.device("00:11:22:33:44:03"))
        val callback = shadowOf(server).gattServerCallback

        h.radio.stop()
        callback.onMtuChanged(h.device("00:11:22:33:44:03"), 100)
        h.callback(linked).onConnectionStateChange(linked, BluetoothGatt.GATT_SUCCESS, BluetoothProfile.STATE_DISCONNECTED)
        h.idle()

        assertEquals(listOf("down 1", "down 2"), h.listener.events.filter { it.startsWith("down") })
        assertTrue(h.shadow(linked).isClosed)
        assertTrue(h.shadow(pending).isClosed)
        assertTrue(shadowOf(server).isClosed)
        assertEquals(0, scanner.activeScans.size)
        assertNull(h.radio.server)
    }

    @Test
    fun stopBeforeStartDoesNothing() {
        h.radio.stop()

        assertEquals(emptyList(), h.listener.events)
    }

    @Test
    fun advertisingIsConnectableAndUntimed() {
        val settings: AdvertiseSettings = GattProfile.advertiseSettings()
        assertTrue(settings.isConnectable)
        assertEquals(0, settings.timeout)
    }
}
