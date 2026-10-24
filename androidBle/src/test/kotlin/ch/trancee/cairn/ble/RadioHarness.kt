package ch.trancee.cairn.ble

import android.Manifest
import android.app.Application
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanResult
import android.os.Handler
import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import ch.trancee.cairn.ffi.GattRole
import ch.trancee.cairn.sdk.RadioListener
import org.robolectric.Shadows.shadowOf
import org.robolectric.shadows.ShadowBluetoothGatt
import org.robolectric.util.ReflectionHelpers

/** Records what the radio reports, in order, as readable lines. */
class RecordingListener : RadioListener {
    val events = mutableListOf<String>()
    var beaconValue = byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8)
    private var nextLink = 1uL

    /** Runs inside the next [linkUp], before it returns, like a driver dispatching `LinkUp`. */
    var onLinkUp: (ULong) -> Unit = {}

    override fun linkUp(role: GattRole, mtu: UShort, address: ByteArray): ULong {
        val link = nextLink++
        events += "up $link $role $mtu ${address.decodeToString()}"
        onLinkUp(link)
        return link
    }

    override fun mtuChanged(link: ULong, mtu: UShort) {
        events += "mtu $link $mtu"
    }

    override fun beaconRead(link: ULong, beacon: ByteArray) {
        events += "beacon $link ${beacon.hex()}"
    }

    override fun received(link: ULong, fragment: ByteArray) {
        events += "received $link ${fragment.hex()}"
    }

    override fun sent(link: ULong) {
        events += "sent $link"
    }

    override fun linkDown(link: ULong) {
        events += "down $link"
    }

    override fun beacon(): ByteArray = beaconValue
}

/** Records each `nextLong(from, until)` range and answers with [pick], by default the lowest value. */
class FakeRandom : kotlin.random.Random() {
    val ranges = mutableListOf<LongRange>()
    var pick: (Long, Long) -> Long = { from, _ -> from }

    override fun nextBits(bitCount: Int): Int = error("the radio draws only ranges")

    override fun nextLong(from: Long, until: Long): Long {
        ranges += from until until
        return pick(from, until)
    }
}

fun ByteArray.hex(): String = joinToString("") { "%02x".format(it) }

/** One radio under test on the main looper, with the Bluetooth permissions granted. */
class RadioHarness {
    val context: Application = ApplicationProvider.getApplicationContext()
    val listener = RecordingListener()
    val random = FakeRandom()
    val radio = AndroidRadio(context, Handler(Looper.getMainLooper()), random).also { it.listener = listener }
    val manager: BluetoothManager = context.getSystemService(BluetoothManager::class.java)
    val adapter: BluetoothAdapter = manager.adapter

    init {
        shadowOf(context).grantPermissions(*BlePermissions.required().toTypedArray())
        shadowOf(context).grantPermissions(Manifest.permission.BLUETOOTH_CONNECT)
        shadowOf(adapter).setEnabled(true)
    }

    fun idle() = shadowOf(Looper.getMainLooper()).idle()

    fun device(address: String): BluetoothDevice = adapter.getRemoteDevice(address)

    fun scanCallback() = shadowOf(adapter.bluetoothLeScanner).scanCallbacks.single()

    /** Reports [address] as a scan match and returns the GATT client the radio opened. */
    fun discover(address: String, service: BluetoothGattService? = peerService()): BluetoothGatt? {
        val device = device(address)
        scanCallback().onScanResult(0, ScanResult(device, null, -40, 0))
        idle()
        val gatt = shadowOf(device).bluetoothGatts.lastOrNull() ?: return null
        service?.let {
            shadowOf(gatt).addDiscoverableService(it)
            it.getCharacteristic(GattProfile.TX)?.let(shadowOf(gatt)::allowCharacteristicNotification)
        }
        return gatt
    }

    /** Connects a discovered GATT client through MTU, discovery, subscription and the beacon read. */
    fun connect(gatt: BluetoothGatt) {
        gatt.connect()
        idle()
    }

    fun shadow(gatt: BluetoothGatt): ShadowBluetoothGatt = shadowOf(gatt)

    fun callback(gatt: BluetoothGatt): BluetoothGattCallback = shadowOf(gatt).gattCallback

    val server: BluetoothGattServer get() = radio.server!!

    fun serverCallback(): BluetoothGattServerCallback = shadowOf(server).gattServerCallback

    /** Lets the real `notifyCharacteristicChanged` reach the null-proxy service, as if registered. */
    fun registerServer() = if (android.os.Build.VERSION.SDK_INT >= 33) {
        ReflectionHelpers.setField(server, "mServerRegistered", true)
    } else {
        ReflectionHelpers.setField(server, "mServerIf", 1)
    }

    /** Has [device] enable `tx` notifications, which opens a peripheral link. */
    fun subscribe(device: BluetoothDevice, requestId: Int = 1) {
        val cccd = server.getService(GattProfile.SERVICE).getCharacteristic(GattProfile.TX)
            .getDescriptor(GattProfile.CCCD)
        serverCallback().onDescriptorWriteRequest(
            device, requestId, cccd, false, true, 0, android.bluetooth.BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE,
        )
        idle()
    }

    fun characteristic(uuid: java.util.UUID): BluetoothGattCharacteristic =
        server.getService(GattProfile.SERVICE).getCharacteristic(uuid)

    companion object {
        /** A peer's GATT service as discovery returns it, with a readable `beacon` value. */
        fun peerService(
            beacon: ByteArray? = byteArrayOf(9, 9, 9, 9, 9, 9, 9, 9),
            characteristics: Set<java.util.UUID> = setOf(GattProfile.BEACON, GattProfile.RX, GattProfile.TX),
            rxProperties: Int = BluetoothGattCharacteristic.PROPERTY_WRITE,
            beaconProperties: Int = BluetoothGattCharacteristic.PROPERTY_READ,
        ): BluetoothGattService {
            val service = BluetoothGattService(GattProfile.SERVICE, BluetoothGattService.SERVICE_TYPE_PRIMARY)
            if (GattProfile.BEACON in characteristics) {
                service.addCharacteristic(
                    BluetoothGattCharacteristic(GattProfile.BEACON, beaconProperties, 0).apply {
                        @Suppress("DEPRECATION")
                        value = beacon
                    },
                )
            }
            if (GattProfile.RX in characteristics) {
                service.addCharacteristic(BluetoothGattCharacteristic(GattProfile.RX, rxProperties, 0))
            }
            if (GattProfile.TX in characteristics) {
                service.addCharacteristic(
                    BluetoothGattCharacteristic(GattProfile.TX, BluetoothGattCharacteristic.PROPERTY_NOTIFY, 0).apply {
                        addDescriptor(android.bluetooth.BluetoothGattDescriptor(GattProfile.CCCD, 0))
                    },
                )
            }
            return service
        }
    }
}
