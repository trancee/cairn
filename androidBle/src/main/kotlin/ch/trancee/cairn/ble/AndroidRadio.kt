package ch.trancee.cairn.ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothStatusCodes
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.BluetoothLeAdvertiser
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.SystemClock
import ch.trancee.cairn.ffi.GattRole
import ch.trancee.cairn.sdk.Radio
import ch.trancee.cairn.sdk.RadioListener

/**
 * The Android [Radio] for slice S2 (ADR 0023 §3). It advertises and scans for the cairn service
 * while started and runs both GATT roles.
 *
 * Every method must be called on [handler]'s thread, and every platform callback is posted there,
 * so [listener] sees one ordered stream. Callers must hold the permissions in [BlePermissions].
 */
@SuppressLint("MissingPermission")
class AndroidRadio(private val context: Context, private val handler: Handler) : Radio {
    /** Usually the [ch.trancee.cairn.sdk.LinkDriver]; set before [start]. */
    lateinit var listener: RadioListener

    private interface Link {
        fun send(fragment: ByteArray)

        fun close()
    }

    private var scanner: BluetoothLeScanner? = null
    private var advertiser: BluetoothLeAdvertiser? = null

    /** The open GATT server; internal for the Robolectric tests. */
    internal var server: BluetoothGattServer? = null

    private val centrals = HashMap<String, Central>()
    private val peripherals = HashMap<String, Peripheral>()
    private val links = HashMap<ULong, Link>()
    private val serverMtus = HashMap<String, Int>()
    private val attempts = HashMap<String, Long>()

    /**
     * Opens the GATT server, advertises and scans. Returns false, and starts nothing, when
     * Bluetooth is missing or off; returns true when already started.
     */
    fun start(): Boolean {
        if (server != null) return true
        val manager = context.getSystemService(BluetoothManager::class.java) ?: return false
        val adapter = manager.adapter ?: return false
        if (!adapter.isEnabled) return false
        val scanner = adapter.bluetoothLeScanner ?: return false
        val advertiser = adapter.bluetoothLeAdvertiser ?: return false
        val server = manager.openGattServer(context, serverCallback) ?: return false
        val service = GattProfile.service()
        server.addService(service)
        serverTx = service.getCharacteristic(GattProfile.TX)
        this.server = server
        advertiser.startAdvertising(GattProfile.advertiseSettings(), GattProfile.advertiseData(), advertiseCallback)
        this.advertiser = advertiser
        scanner.startScan(GattProfile.scanFilters(), GattProfile.scanSettings(), scanCallback)
        this.scanner = scanner
        return true
    }

    /** Stops discovery, closes every connection and reports [RadioListener.linkDown] for each link. */
    fun stop() {
        scanner?.stopScan(scanCallback)
        advertiser?.stopAdvertising(advertiseCallback)
        centrals.values.toList().forEach(Central::close)
        peripherals.values.toList().forEach(Peripheral::close)
        server?.close()
        scanner = null
        advertiser = null
        server = null
        serverMtus.clear()
    }

    // Posted, because the driver calls these while it dispatches, possibly before linkUp returned the id.
    override fun send(link: ULong, fragment: ByteArray) {
        handler.post { links[link]?.send(fragment) }
    }

    override fun disconnect(link: ULong) {
        handler.post { links[link]?.close() }
    }

    private fun connect(device: BluetoothDevice) {
        val address = device.address
        if (address in centrals || address in peripherals) return
        val now = SystemClock.elapsedRealtime()
        val last = attempts[address]
        if (last != null && now - last < ATTEMPT_INTERVAL_MS) return
        attempts[address] = now
        val central = Central(address)
        val gatt: BluetoothGatt = device.connectGatt(context, false, central, BluetoothDevice.TRANSPORT_LE) ?: return
        central.gatt = gatt
        centrals[address] = central
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            handler.post { if (server != null) connect(result.device) }
        }
    }

    private val advertiseCallback = object : AdvertiseCallback() {}

    /** A link where we are the GATT client: connect, MTU, discovery, `tx` subscription, then `beacon`. */
    private inner class Central(val address: String) : BluetoothGattCallback(), Link {
        lateinit var gatt: BluetoothGatt
        private var stage = Stage.CONNECTING
        private var mtu = GattProfile.DEFAULT_MTU
        private var link = 0uL
        private lateinit var rx: BluetoothGattCharacteristic
        private lateinit var beacon: BluetoothGattCharacteristic
        private var reading = false
        private var held: ByteArray? = null

        private fun post(block: () -> Unit) {
            handler.post { if (centrals[address] === this) block() }
        }

        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) = post {
            if (status == BluetoothGatt.GATT_SUCCESS && newState == BluetoothProfile.STATE_CONNECTED) {
                if (!gatt.requestMtu(GattProfile.MAX_MTU)) close()
            } else {
                close()
            }
        }

        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) = post {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                this.mtu = mtu
                if (stage == Stage.UP) listener.mtuChanged(link, mtu.toUShort())
            }
            if (stage == Stage.CONNECTING) {
                stage = Stage.DISCOVERING
                if (!gatt.discoverServices()) close()
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) = post {
            val service = gatt.getService(GattProfile.SERVICE)
            val tx = service?.getCharacteristic(GattProfile.TX)
            val cccd = tx?.getDescriptor(GattProfile.CCCD)
            val rx = service?.getCharacteristic(GattProfile.RX)
            val beacon = service?.getCharacteristic(GattProfile.BEACON)
            if (status != BluetoothGatt.GATT_SUCCESS || cccd == null || rx == null || beacon == null) {
                close()
            } else {
                this.rx = rx
                this.beacon = beacon
                stage = Stage.SUBSCRIBING
                val enable = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                if (!gatt.setCharacteristicNotification(tx, true) || !gatt.writeCompat(cccd, enable)) close()
            }
        }

        override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) = post {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                close()
            } else {
                stage = Stage.UP
                link = listener.linkUp(GattRole.CENTRAL, mtu.toUShort(), address.encodeToByteArray())
                links[link] = this
                reading = true
                if (!gatt.readCharacteristic(beacon)) close()
            }
        }

        @Deprecated("Superseded on API 33, which delivers both forms")
        override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            @Suppress("DEPRECATION")
            val value = characteristic.value
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) post { beaconRead(value, status) }
        }

        override fun onCharacteristicRead(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
            status: Int,
        ) = post { beaconRead(value, status) }

        private fun beaconRead(value: ByteArray, status: Int) {
            reading = false
            if (status != BluetoothGatt.GATT_SUCCESS) return close()
            listener.beaconRead(link, value)
            held?.let {
                held = null
                send(it)
            }
        }

        @Deprecated("Superseded on API 33, which delivers both forms")
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            @Suppress("DEPRECATION")
            val value = characteristic.value
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) post { notified(value) }
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
        ) = post { notified(value) }

        private fun notified(value: ByteArray) {
            if (stage == Stage.UP) listener.received(link, value)
        }

        override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) =
            post { if (status == BluetoothGatt.GATT_SUCCESS) listener.sent(link) else close() }

        // Android runs one GATT operation at a time, so a write waits for the beacon read.
        override fun send(fragment: ByteArray) {
            if (reading) {
                held = fragment
            } else if (!gatt.writeCompat(rx, fragment)) {
                close()
            }
        }

        override fun close() {
            centrals.remove(address)
            gatt.disconnect()
            gatt.close()
            if (stage == Stage.UP) {
                links.remove(link)
                listener.linkDown(link)
            }
        }
    }

    private enum class Stage { CONNECTING, DISCOVERING, SUBSCRIBING, UP }

    /** A link where we are the GATT server; it opens when the central enables `tx` notifications. */
    private inner class Peripheral(
        val device: BluetoothDevice,
        val server: BluetoothGattServer,
        val tx: BluetoothGattCharacteristic,
        val link: ULong,
    ) : Link {
        override fun send(fragment: ByteArray) {
            if (!server.notifyCompat(device, tx, fragment)) close()
        }

        override fun close() {
            server.cancelConnection(device)
            peripherals.remove(device.address)
            links.remove(link)
            listener.linkDown(link)
        }
    }

    private var serverTx: BluetoothGattCharacteristic? = null

    private val serverCallback = object : BluetoothGattServerCallback() {
        private fun post(block: (BluetoothGattServer) -> Unit) {
            handler.post { server?.let(block) }
        }

        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) = post {
            if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                serverMtus.remove(device.address)
                peripherals.remove(device.address)?.let {
                    links.remove(it.link)
                    listener.linkDown(it.link)
                }
            }
        }

        override fun onMtuChanged(device: BluetoothDevice, mtu: Int) = post {
            serverMtus[device.address] = mtu
            peripherals[device.address]?.let { listener.mtuChanged(it.link, mtu.toUShort()) }
        }

        override fun onCharacteristicReadRequest(
            device: BluetoothDevice,
            requestId: Int,
            offset: Int,
            characteristic: BluetoothGattCharacteristic,
        ) = post { server ->
            val value = if (characteristic.uuid == GattProfile.BEACON) listener.beacon() else null
            when {
                value == null -> server.sendResponse(device, requestId, BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED, 0, null)
                offset > value.size -> server.sendResponse(device, requestId, BluetoothGatt.GATT_INVALID_OFFSET, offset, null)
                else -> server.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value.copyOfRange(offset, value.size))
            }
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray,
        ) = post { server ->
            val peripheral = peripherals[device.address]
            val accepted = peripheral != null && characteristic.uuid == GattProfile.RX && !preparedWrite
            if (responseNeeded) server.respond(device, requestId, accepted)
            if (accepted) listener.received(peripheral.link, value)
        }

        override fun onDescriptorWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            descriptor: BluetoothGattDescriptor,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray,
        ) = post { server ->
            val accepted = descriptor.uuid == GattProfile.CCCD && !preparedWrite
            if (responseNeeded) server.respond(device, requestId, accepted)
            val address = device.address
            val enable = value.contentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
            if (accepted && enable && address !in peripherals) {
                val mtu = serverMtus[address] ?: GattProfile.DEFAULT_MTU
                val link = listener.linkUp(GattRole.PERIPHERAL, mtu.toUShort(), address.encodeToByteArray())
                val peripheral = Peripheral(device, server, serverTx!!, link)
                peripherals[address] = peripheral
                links[link] = peripheral
            }
        }

        override fun onDescriptorReadRequest(
            device: BluetoothDevice,
            requestId: Int,
            offset: Int,
            descriptor: BluetoothGattDescriptor,
        ) = post { server ->
            val value = if (device.address in peripherals) {
                BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            } else {
                BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE
            }
            server.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, value)
        }

        override fun onNotificationSent(device: BluetoothDevice, status: Int) = post {
            peripherals[device.address]?.let {
                if (status == BluetoothGatt.GATT_SUCCESS) listener.sent(it.link) else it.close()
            }
        }
    }

    private companion object {
        /** Spec §10.4: at most one connection attempt per address per 2 min. */
        const val ATTEMPT_INTERVAL_MS = 120_000L

        fun BluetoothGattServer.respond(device: BluetoothDevice, requestId: Int, accepted: Boolean) {
            val status = if (accepted) BluetoothGatt.GATT_SUCCESS else BluetoothGatt.GATT_WRITE_NOT_PERMITTED
            sendResponse(device, requestId, status, 0, null)
        }

        fun BluetoothGatt.writeCompat(descriptor: BluetoothGattDescriptor, value: ByteArray): Boolean =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                writeDescriptor(descriptor, value) == BluetoothStatusCodes.SUCCESS
            } else {
                @Suppress("DEPRECATION")
                descriptor.value = value
                @Suppress("DEPRECATION")
                writeDescriptor(descriptor)
            }

        fun BluetoothGatt.writeCompat(characteristic: BluetoothGattCharacteristic, value: ByteArray): Boolean =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                writeCharacteristic(characteristic, value, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT) ==
                    BluetoothStatusCodes.SUCCESS
            } else {
                characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                @Suppress("DEPRECATION")
                characteristic.value = value
                @Suppress("DEPRECATION")
                writeCharacteristic(characteristic)
            }

        fun BluetoothGattServer.notifyCompat(
            device: BluetoothDevice,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
        ): Boolean = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            notifyCharacteristicChanged(device, characteristic, false, value) == BluetoothStatusCodes.SUCCESS
        } else {
            @Suppress("DEPRECATION")
            characteristic.value = value
            @Suppress("DEPRECATION")
            notifyCharacteristicChanged(device, characteristic, false)
        }
    }
}
