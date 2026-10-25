package ch.trancee.cairn.ble

import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothProfile
import android.os.Build
import android.os.ParcelUuid
import java.util.UUID
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.util.ReflectionHelpers

@RunWith(RobolectricTestRunner::class)
class CentralTest {
    private val h = RadioHarness().also { it.radio.start() }
    private val address = "00:11:22:33:44:01"

    private fun up(service: BluetoothGattService = RadioHarness.peerService()): BluetoothGatt {
        val gatt = h.discover(address, service)!!
        h.connect(gatt)
        return gatt
    }

    private fun tx(gatt: BluetoothGatt) = gatt.getService(GattProfile.SERVICE).getCharacteristic(GattProfile.TX)

    private fun rx(gatt: BluetoothGatt) = gatt.getService(GattProfile.SERVICE).getCharacteristic(GattProfile.RX)

    private fun beacon(gatt: BluetoothGatt) =
        gatt.getService(GattProfile.SERVICE).getCharacteristic(GattProfile.BEACON)

    private fun notify(gatt: BluetoothGatt, value: ByteArray, tx: BluetoothGattCharacteristic = tx(gatt)) {
        if (Build.VERSION.SDK_INT >= 33) {
            h.callback(gatt).onCharacteristicChanged(gatt, tx, value)
        } else {
            @Suppress("DEPRECATION")
            tx.value = value
            @Suppress("DEPRECATION")
            h.callback(gatt).onCharacteristicChanged(gatt, tx)
        }
        h.idle()
    }

    private fun readResult(gatt: BluetoothGatt, value: ByteArray, status: Int) {
        val beacon = beacon(gatt)
        if (Build.VERSION.SDK_INT >= 33) {
            h.callback(gatt).onCharacteristicRead(gatt, beacon, value, status)
        } else {
            @Suppress("DEPRECATION")
            beacon.value = value
            @Suppress("DEPRECATION")
            h.callback(gatt).onCharacteristicRead(gatt, beacon, status)
        }
        h.idle()
    }

    private fun assertClosed(gatt: BluetoothGatt) = assertTrue(h.shadow(gatt).isClosed)

    @Test
    fun scansOnlyForTheCairnServiceUuidOrServiceData() {
        val scan = shadowOf(h.adapter.bluetoothLeScanner).activeScans.single()

        val filters = scan.scanFilters()
        assertEquals(listOf(ParcelUuid(GattProfile.SERVICE), null), filters.map { it.serviceUuid })
        assertEquals(listOf(null, ParcelUuid(GattProfile.SERVICE)), filters.map { it.serviceDataUuid })
        assertContentEquals(ByteArray(0), filters[1].serviceData)
    }

    @Test
    fun centralReportsLinkUpAfterSubscribingThenTheBeaconValue() {
        val gatt = up()

        assertEquals(listOf("up 1 CENTRAL 517 $address", "beacon 1 0909090909090909"), h.listener.events)
        assertContentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE, h.shadow(gatt).latestWrittenBytes)
    }

    @Test
    fun centralWritesAFragmentToRxAndReportsSent() {
        val gatt = up()

        h.radio.send(1u, byteArrayOf(0x0a, 0x0b))
        h.idle()

        assertEquals("sent 1", h.listener.events.last())
        assertContentEquals(byteArrayOf(0x0a, 0x0b), h.shadow(gatt).latestWrittenBytes)
    }

    @Test
    fun centralHoldsAWriteUntilTheBeaconReadCompletes() {
        h.listener.onLinkUp = { link -> h.radio.send(link, byteArrayOf(0x0c)) }

        val gatt = up()

        assertEquals(
            listOf("up 1 CENTRAL 517 $address", "beacon 1 0909090909090909", "sent 1"),
            h.listener.events,
        )
        assertContentEquals(byteArrayOf(0x0c), h.shadow(gatt).latestWrittenBytes)
    }

    @Test
    fun centralReportsTxNotifications() {
        val gatt = up()

        notify(gatt, byteArrayOf(0x01, 0x02))

        assertEquals("received 1 0102", h.listener.events.last())
    }

    @Test
    fun centralIgnoresNotificationsBeforeLinkUp() {
        val service = RadioHarness.peerService()
        val gatt = h.discover(address, service)!!

        notify(gatt, byteArrayOf(0x01), service.getCharacteristic(GattProfile.TX))

        assertEquals(emptyList(), h.listener.events)
    }

    @Test
    @Config(sdk = [37])
    fun centralIgnoresTheDeprecatedCallbacksThatApi33AlsoDelivers() {
        val gatt = up(RadioHarness.peerService(beacon = null))
        @Suppress("DEPRECATION")
        h.callback(gatt).onCharacteristicRead(gatt, beacon(gatt), BluetoothGatt.GATT_SUCCESS)
        @Suppress("DEPRECATION")
        h.callback(gatt).onCharacteristicChanged(gatt, tx(gatt))
        h.idle()

        assertEquals(listOf("up 1 CENTRAL 517 $address"), h.listener.events)
    }

    @Test
    fun centralReportsMtuChangesAfterLinkUp() {
        val gatt = up()

        h.callback(gatt).onMtuChanged(gatt, 247, BluetoothGatt.GATT_SUCCESS)
        h.callback(gatt).onMtuChanged(gatt, 100, BluetoothGatt.GATT_FAILURE)
        h.idle()

        assertEquals("mtu 1 247", h.listener.events.last())
    }

    @Test
    fun centralKeepsTheDefaultMtuWhenTheRequestFails() {
        val gatt = h.discover(address)!!

        h.callback(gatt).onMtuChanged(gatt, 0, BluetoothGatt.GATT_FAILURE)
        h.idle()

        assertEquals("up 1 CENTRAL 23 $address", h.listener.events.first())
    }

    @Test
    fun centralTakesTheLatestMtuReportedDuringSetup() {
        val gatt = h.discover(address)!!

        h.callback(gatt).onMtuChanged(gatt, 185, BluetoothGatt.GATT_SUCCESS)
        h.callback(gatt).onMtuChanged(gatt, 200, BluetoothGatt.GATT_SUCCESS)
        h.idle()

        assertEquals("up 1 CENTRAL 200 $address", h.listener.events.first())
    }

    @Test
    fun centralClosesAFailedConnectionAttempt() {
        val gatt = h.discover(address)!!

        h.callback(gatt).onConnectionStateChange(gatt, 133, BluetoothProfile.STATE_DISCONNECTED)
        h.idle()

        assertClosed(gatt)
        assertEquals(emptyList(), h.listener.events)
    }

    @Test
    fun centralClosesAConnectionReportedWithAnErrorStatus() {
        val gatt = h.discover(address)!!

        h.callback(gatt).onConnectionStateChange(gatt, 133, BluetoothProfile.STATE_CONNECTED)
        h.idle()

        assertClosed(gatt)
    }

    @Test
    fun centralClosesTheLinkWhenTheMtuRequestCannotStart() {
        val gatt = h.discover(address)!!
        val callback = h.callback(gatt)
        h.shadow(gatt).setGattCallback(null)

        callback.onConnectionStateChange(gatt, BluetoothGatt.GATT_SUCCESS, BluetoothProfile.STATE_CONNECTED)
        h.idle()

        assertClosed(gatt)
    }

    @Test
    fun centralClosesTheLinkWhenDiscoveryCannotStart() {
        val gatt = h.discover(address, service = null)!!

        h.connect(gatt)

        assertClosed(gatt)
        assertEquals(emptyList(), h.listener.events)
    }

    @Test
    fun centralClosesTheLinkWhenDiscoveryFails() {
        val gatt = h.discover(address)!!

        h.callback(gatt).onServicesDiscovered(gatt, BluetoothGatt.GATT_FAILURE)
        h.idle()

        assertClosed(gatt)
    }

    @Test
    fun centralClosesTheLinkWhenThePeerLacksTheService() {
        val other = BluetoothGattService(UUID.randomUUID(), BluetoothGattService.SERVICE_TYPE_PRIMARY)

        val gatt = up(other)

        assertClosed(gatt)
        assertEquals(emptyList(), h.listener.events)
    }

    @Test
    fun centralClosesTheLinkWhenTheServiceLacksACharacteristic() {
        val partial = listOf(
            emptySet(),
            setOf(GattProfile.TX),
            setOf(GattProfile.TX, GattProfile.RX),
        )
        partial.forEachIndexed { index, characteristics ->
            val gatt = h.discover("00:11:22:33:45:0$index", RadioHarness.peerService(characteristics = characteristics))!!

            h.connect(gatt)

            assertClosed(gatt)
        }
        assertEquals(emptyList(), h.listener.events)
    }

    @Test
    fun centralClosesTheLinkWhenNotificationsCannotBeEnabled() {
        val service = RadioHarness.peerService()
        val gatt = h.discover(address, service)!!
        h.shadow(gatt).disallowCharacteristicNotification(service.getCharacteristic(GattProfile.TX))

        h.connect(gatt)

        assertClosed(gatt)
    }

    @Test
    fun centralClosesTheLinkWhenTheCccdWriteCannotStart() {
        val service = RadioHarness.peerService()
        val gatt = h.discover(address, service)!!
        val cccd = service.getCharacteristic(GattProfile.TX).getDescriptor(GattProfile.CCCD)
        ReflectionHelpers.setField(cccd, "mCharacteristic", null)

        h.connect(gatt)

        assertClosed(gatt)
    }

    @Test
    fun centralClosesTheLinkWhenTheCccdWriteFails() {
        val service = RadioHarness.peerService()
        val gatt = h.discover(address, service)!!
        val cccd = service.getCharacteristic(GattProfile.TX).getDescriptor(GattProfile.CCCD)

        h.callback(gatt).onDescriptorWrite(gatt, cccd, BluetoothGatt.GATT_FAILURE)
        h.idle()

        assertClosed(gatt)
    }

    @Test
    fun centralReportsLinkDownWhenTheBeaconReadCannotStart() {
        val gatt = up(RadioHarness.peerService(beaconProperties = 0))

        assertEquals(listOf("up 1 CENTRAL 517 $address", "down 1"), h.listener.events)
        assertClosed(gatt)
    }

    @Test
    fun centralReportsLinkDownWhenTheBeaconReadFails() {
        val gatt = up(RadioHarness.peerService(beacon = null))

        readResult(gatt, ByteArray(0), BluetoothGatt.GATT_FAILURE)

        assertEquals(listOf("up 1 CENTRAL 517 $address", "down 1"), h.listener.events)
    }

    @Test
    fun centralReportsLinkDownWhenAWriteCannotStart() {
        val gatt = up(RadioHarness.peerService(rxProperties = 0))

        h.radio.send(1u, byteArrayOf(1))
        h.idle()

        assertEquals("down 1", h.listener.events.last())
        assertClosed(gatt)
    }

    @Test
    fun centralReportsLinkDownWhenAWriteFails() {
        val gatt = up()

        h.callback(gatt).onCharacteristicWrite(gatt, rx(gatt), BluetoothGatt.GATT_FAILURE)
        h.idle()

        assertEquals("down 1", h.listener.events.last())
    }

    @Test
    fun centralDisconnectReportsLinkDownOnce() {
        val gatt = up()

        h.radio.disconnect(1u)
        h.idle()

        assertEquals(listOf("up 1 CENTRAL 517 $address", "beacon 1 0909090909090909", "down 1"), h.listener.events)
        assertClosed(gatt)
    }

    @Test
    fun centralReportsARemoteDisconnect() {
        val gatt = up()

        h.callback(gatt).onConnectionStateChange(gatt, BluetoothGatt.GATT_SUCCESS, BluetoothProfile.STATE_DISCONNECTED)
        h.idle()

        assertEquals("down 1", h.listener.events.last())
        assertClosed(gatt)
    }

    @Test
    fun sendAndDisconnectIgnoreUnknownLinks() {
        h.radio.send(7u, byteArrayOf(1))
        h.radio.disconnect(7u)
        h.idle()

        assertEquals(emptyList(), h.listener.events)
    }

    @Test
    fun centralConnectsToAnAddressOnceWhileItIsConnected() {
        h.discover(address)

        h.discover(address)

        assertEquals(1, shadowOf(h.device(address)).bluetoothGatts.size)
    }

    @Test
    fun centralDoesNotConnectToAPeerAlreadyLinkedAsCentral() {
        h.subscribe(h.device(address))

        h.discover(address)

        assertEquals(0, shadowOf(h.device(address)).bluetoothGatts.size)
    }

    @Test
    @Config(shadows = [NullGattShadows.Device::class])
    fun centralSkipsAPeerWhenTheStackCannotOpenAGattClient() {
        val gatt = h.discover(address)

        assertNull(gatt)
        assertEquals(emptyList(), h.listener.events)
    }
}
