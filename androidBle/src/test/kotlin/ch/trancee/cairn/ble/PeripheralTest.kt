package ch.trancee.cairn.ble

import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothProfile
import android.os.Build
import ch.trancee.cairn.sdk.DisconnectReason
import ch.trancee.cairn.sdk.FragmentCheck
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadow.api.Shadow
import org.robolectric.shadows.ShadowLog

@RunWith(RobolectricTestRunner::class)
class PeripheralTest {
    private val h = RadioHarness().also { it.radio.start() }
    private val address = "00:11:22:33:44:0A"
    private val device = h.device(address)

    private fun responses() = shadowOf(h.server).responses

    private fun write(
        uuid: java.util.UUID,
        value: ByteArray,
        from: android.bluetooth.BluetoothDevice = device,
        prepared: Boolean = false,
        responseNeeded: Boolean = true,
    ) {
        h.serverCallback().onCharacteristicWriteRequest(
            from, 2, h.characteristic(uuid), prepared, responseNeeded, 0, value,
        )
        h.idle()
    }

    private fun read(uuid: java.util.UUID, offset: Int = 0) {
        h.serverCallback().onCharacteristicReadRequest(device, 3, offset, h.characteristic(uuid))
        h.idle()
    }

    private fun cccd(): BluetoothGattDescriptor = h.characteristic(GattProfile.TX).getDescriptor(GattProfile.CCCD)

    @Test
    fun peripheralReportsLinkUpWhenACentralEnablesNotifications() {
        h.subscribe(device)

        assertEquals(listOf("up 1 PERIPHERAL 23 $address"), h.listener.events)
        assertEquals(1, responses().size)
    }

    @Test
    fun peripheralReportsTheMtuNegotiatedBeforeSubscribing() {
        h.serverCallback().onMtuChanged(device, 247)
        h.idle()

        h.subscribe(device)

        assertEquals(listOf("up 1 PERIPHERAL 247 $address"), h.listener.events)
    }

    @Test
    fun peripheralReportsMtuChangesOnALink() {
        h.subscribe(device)

        h.serverCallback().onMtuChanged(device, 185)
        h.idle()

        assertEquals("mtu 1 185", h.listener.events.last())
    }

    @Test
    fun peripheralOpensOneLinkPerCentral() {
        h.subscribe(device)

        h.subscribe(device)

        assertEquals(listOf("up 1 PERIPHERAL 23 $address"), h.listener.events)
    }

    @Test
    fun peripheralIgnoresANotificationDisable() {
        h.serverCallback().onDescriptorWriteRequest(
            device, 1, cccd(), false, true, 0, BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE,
        )
        h.idle()

        assertEquals(emptyList(), h.listener.events)
        assertEquals(1, responses().size)
    }

    @Test
    fun peripheralRejectsOtherDescriptorWrites() {
        val other = BluetoothGattDescriptor(java.util.UUID.randomUUID(), 0)
        h.serverCallback().onDescriptorWriteRequest(
            device, 1, other, false, true, 0, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE,
        )
        h.serverCallback().onDescriptorWriteRequest(
            device, 1, cccd(), true, true, 0, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE,
        )
        h.serverCallback().onDescriptorWriteRequest(
            device, 1, cccd(), false, false, 0, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE,
        )
        h.idle()

        assertEquals(listOf("up 1 PERIPHERAL 23 $address"), h.listener.events)
        assertEquals(listOf(null, null), responses().toList())
    }

    @Test
    fun peripheralAnswersCccdReadsWithTheSubscriptionState() {
        h.serverCallback().onDescriptorReadRequest(device, 4, 0, cccd())
        h.idle()
        h.subscribe(device)
        h.serverCallback().onDescriptorReadRequest(device, 5, 0, cccd())
        h.idle()

        assertContentEquals(BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE, responses()[0])
        assertContentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE, responses()[2])
    }

    @Test
    fun peripheralAnswersBeaconReadsFromTheCore() {
        read(GattProfile.BEACON)
        read(GattProfile.BEACON, offset = 6)
        read(GattProfile.BEACON, offset = 9)

        val values = responses()
        assertContentEquals(h.listener.beaconValue, values[0])
        assertContentEquals(byteArrayOf(7, 8), values[1])
        assertNull(values[2])
    }

    @Test
    fun peripheralRejectsPsmReads() {
        read(GattProfile.PSM)

        assertEquals(listOf(null), responses().toList())
    }

    @Test
    fun peripheralReportsRxWritesFromALinkedCentral() {
        h.subscribe(device)

        write(GattProfile.RX, checked(0x0d, 0x0e))
        write(GattProfile.RX, byteArrayOf(0x0f), responseNeeded = false)

        assertEquals(listOf("received 1 ${checked(0x0d, 0x0e).hex()}", "received 1 0f"), h.listener.events.drop(1))
        assertEquals(2, responses().size)
    }

    @Test
    @Config(shadows = [StatusGattServer::class])
    fun peripheralRejectsAWriteWhoseCheckFailsSoTheCentralResendsIt() {
        h.subscribe(device)
        val corrupted = checked(0x0d, 0x0e).also { it[1] = 0x0c }

        write(GattProfile.RX, corrupted)

        assertEquals(listOf("up 1 PERIPHERAL 23 $address"), h.listener.events)
        assertEquals(FragmentCheck.CHECK_FAILED, Shadow.extract<StatusGattServer>(h.server).statuses.last())
        assertTrue("link 1 write rejected (check)" in ShadowLog.getLogsForTag("CairnRadio").map { it.msg })
    }

    @Test
    fun peripheralRejectsWritesItCannotAccept() {
        h.subscribe(device)

        write(GattProfile.RX, byteArrayOf(1), from = h.device("00:11:22:33:44:0B"))
        write(GattProfile.BEACON, byteArrayOf(2))
        write(GattProfile.RX, byteArrayOf(3), prepared = true)
        write(GattProfile.RX, byteArrayOf(4), from = h.device("00:11:22:33:44:0C"), responseNeeded = false)

        assertEquals(listOf("up 1 PERIPHERAL 23 $address"), h.listener.events)
        assertEquals(listOf(null, null, null), responses().drop(1))
    }

    @Test
    fun peripheralNotifiesTxAndReportsSentWhenTheStackConfirms() {
        h.registerServer()
        h.subscribe(device)

        h.radio.send(1u, byteArrayOf(0x21))
        h.idle()
        h.serverCallback().onNotificationSent(device, BluetoothGatt.GATT_SUCCESS)
        h.idle()

        assertEquals("sent 1", h.listener.events.last())
        @Suppress("DEPRECATION")
        if (Build.VERSION.SDK_INT < 33) assertContentEquals(byteArrayOf(0x21), h.characteristic(GattProfile.TX).value)
        assertFalse(shadowOf(h.server).isConnectionCancelled(device))
    }

    @Test
    fun peripheralClosesTheLinkWhenANotificationCannotStart() {
        h.subscribe(device)

        h.radio.send(1u, byteArrayOf(0x22))
        h.idle()

        assertEquals("down 1", h.listener.events.last())
        assertTrue(shadowOf(h.server).isConnectionCancelled(device))
    }

    @Test
    fun peripheralClosesTheLinkWhenANotificationFails() {
        h.subscribe(device)

        h.serverCallback().onNotificationSent(device, BluetoothGatt.GATT_FAILURE)
        h.serverCallback().onNotificationSent(h.device("00:11:22:33:44:0B"), BluetoothGatt.GATT_SUCCESS)
        h.idle()

        assertEquals(listOf("up 1 PERIPHERAL 23 $address", "down 1"), h.listener.events)
    }

    @Test
    fun peripheralDisconnectCancelsTheConnectionAndReportsLinkDownOnce() {
        h.subscribe(device)

        h.radio.disconnect(1u, DisconnectReason.BUSY)
        h.idle()
        h.serverCallback().onConnectionStateChange(device, BluetoothGatt.GATT_SUCCESS, BluetoothProfile.STATE_DISCONNECTED)
        h.idle()

        assertEquals(listOf("up 1 PERIPHERAL 23 $address", "down 1"), h.listener.events)
        assertTrue(shadowOf(h.server).isConnectionCancelled(device))
    }

    @Test
    fun peripheralReportsARemoteDisconnectAndForgetsTheMtu() {
        h.serverCallback().onMtuChanged(device, 247)
        h.serverCallback().onConnectionStateChange(device, BluetoothGatt.GATT_SUCCESS, BluetoothProfile.STATE_CONNECTED)
        h.idle()
        h.subscribe(device)

        h.serverCallback().onConnectionStateChange(device, BluetoothGatt.GATT_SUCCESS, BluetoothProfile.STATE_DISCONNECTED)
        h.idle()
        h.subscribe(device)

        assertEquals(
            listOf("up 1 PERIPHERAL 247 $address", "down 1", "up 2 PERIPHERAL 23 $address"),
            h.listener.events,
        )
    }

    @Test
    fun peripheralPublishesTheCairnService() {
        val service = h.server.getService(GattProfile.SERVICE)

        assertEquals(
            listOf(GattProfile.BEACON, GattProfile.RX, GattProfile.TX, GattProfile.PSM),
            service.characteristics.map { it.uuid },
        )
        assertEquals(BluetoothGattCharacteristic.PROPERTY_WRITE, h.characteristic(GattProfile.RX).properties)
    }
}
