package ch.trancee.cairn.ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
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
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.ParcelUuid
import android.os.SystemClock
import android.util.Log
import ch.trancee.cairn.ble.Congestion.Level
import ch.trancee.cairn.ffi.GattRole
import ch.trancee.cairn.sdk.Radio
import ch.trancee.cairn.sdk.RadioListener
import kotlin.random.Random

/**
 * The Android [Radio] for slice S2 (ADR 0023 §3). It advertises and scans for the cairn service
 * while started and runs both GATT roles.
 *
 * Every method must be called on [handler]'s thread, and every platform callback is posted there,
 * so [listener] sees one ordered stream. Callers must hold the permissions in [BlePermissions].
 */
@SuppressLint("MissingPermission")
class AndroidRadio(
    private val context: Context,
    private val handler: Handler,
    private val random: Random = Random.Default,
    /** Unix time in ms; the beacon window follows it (spec §10.1). */
    private val wallClock: () -> Long = System::currentTimeMillis,
) : Radio {
    /** Usually the [ch.trancee.cairn.sdk.LinkDriver]; set before [start]. */
    lateinit var listener: RadioListener

    /** Called on [handler]'s thread when Bluetooth turns off (false) or back on (true) while started. */
    var availability: (Boolean) -> Unit = {}

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
    private val dials = HashMap<String, Dial>()
    private val upAt = HashMap<ULong, Long>()

    /** When each link last carried a fragment, or came up. */
    private val activeAt = HashMap<ULong, Long>()
    private var evictedAt = -EVICTION_INTERVAL_MS

    /** Devices connected to the GATT server, subscribed or not; each holds a slot (ADR 0025). */
    private val serverConnected = HashSet<String>()

    /** ADR 0025: the AOSP link-record minimum, 7 before API 35 and 8 from it, less 2. */
    private val maxSlots = if (Build.VERSION.SDK_INT >= 35) 6 else 5

    /** ADR 0025: stacks up to API 28 run one LE connect at a time. */
    private val maxDialsInFlight = if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) 1 else 2

    // Android allocates one link record per remote address, whichever role opened it.
    private fun slotsInUse(): Int = (centrals.keys + peripherals.keys + serverConnected).size

    private fun dialsInFlight(): Int = centrals.values.count { !it.isUp }

    private val congestion = Congestion()

    /** Tags the pending congestion evaluation and deferred scan restart, so [release] can cancel them. */
    private val evaluation = Any()
    private val rescanning = Any()

    private var scanMode = 0
    private var scanStartedAt = 0L

    /** No dial starts before then (spec §10.4); failed dials in a row widen the gap. */
    private var nextDialAt = 0L
    private var dialFailures = 0

    /**
     * Opens the GATT server, advertises and scans, and from then on follows Bluetooth turning off
     * and on (see [availability]) until [stop]. Returns false, and starts nothing yet, when
     * Bluetooth is missing or off; returns true when already started.
     */
    fun start(): Boolean {
        if (!following) {
            // Delivered on the handler; a system broadcast, so it needs no export flag.
            context.registerReceiver(adapterReceiver, IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED), null, handler)
            following = true
        }
        return open()
    }

    private fun open(): Boolean {
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
        this.advertiser = advertiser
        budget()
        scan(scanner, congestion.level.scanMode)
        this.scanner = scanner
        evaluate(advertiser)
        return true
    }

    private fun scan(scanner: BluetoothLeScanner, mode: Int) {
        scanner.startScan(GattProfile.scanFilters(), GattProfile.scanSettings(mode), scanCallback)
        scanMode = mode
        scanStartedAt = SystemClock.elapsedRealtime()
    }

    // Schedules itself every EVALUATION_INTERVAL_MS while open.
    private fun evaluate(advertiser: BluetoothLeAdvertiser) {
        handler.postAtTime(
            {
                val before = congestion.level
                val level = congestion.evaluate(SystemClock.elapsedRealtime())
                if (level != before) {
                    Log.i(TAG, "congestion $level density ${congestion.density} failures ${congestion.failed}/${congestion.ended}")
                    rescan()
                    if (advertising) {
                        advertiser.stopAdvertising(advertiseCallback)
                        advertise(advertiser)
                    }
                }
                evaluate(advertiser)
            },
            evaluation,
            SystemClock.uptimeMillis() + EVALUATION_INTERVAL_MS,
        )
    }

    /**
     * Restarts the scan when its mode should change: the level's, or `LOW_POWER` while every slot
     * is in use. Android allows 5 scan starts per 30 s, so a restart waits [SCAN_RESTART_INTERVAL_MS].
     */
    private fun rescan() {
        val scanner = scanner ?: return
        handler.removeCallbacksAndMessages(rescanning)
        val mode = if (slotsInUse() >= maxSlots) ScanSettings.SCAN_MODE_LOW_POWER else congestion.level.scanMode
        if (mode == scanMode) return
        val wait = scanStartedAt + SCAN_RESTART_INTERVAL_MS - SystemClock.elapsedRealtime()
        if (wait > 0) {
            handler.postAtTime(::rescan, rescanning, SystemClock.uptimeMillis() + wait)
        } else {
            scanner.stopScan(scanCallback)
            scan(scanner, mode)
        }
    }

    /** The beacon in the latest advert; the dial rule compares it (ADR 0025). */
    private var advertised = ByteArray(0)

    private var advertising = false

    /** Advertises only while a slot is free (ADR 0025); runs after every change to the slots in use. */
    private fun budget() {
        val advertiser = advertiser ?: return
        rescan()
        val free = slotsInUse() < maxSlots
        if (free == advertising) return
        if (free) {
            advertise(advertiser)
        } else {
            advertiser.stopAdvertising(advertiseCallback)
            handler.removeCallbacksAndMessages(rotation)
            advertising = false
            Log.i(TAG, "slots full; advertising stopped")
        }
    }

    /** Tags the pending advert restart, so [release] can cancel it. */
    private val rotation = Any()

    // Restarts at the next window boundary plus jitter, so the advert carries the current beacon (spec §10.1).
    private fun advertise(advertiser: BluetoothLeAdvertiser) {
        val beacon = listener.beacon()
        advertiser.startAdvertising(GattProfile.advertiseSettings(congestion.level.advertiseMode), GattProfile.advertiseData(beacon), advertiseCallback)
        advertised = beacon
        advertising = true
        handler.removeCallbacksAndMessages(rotation)
        val wall = wallClock()
        val delay = BEACON_WINDOW_MS - wall % BEACON_WINDOW_MS + random.nextLong(0, ROTATION_JITTER_MS + 1)
        handler.postAtTime(
            {
                advertiser.stopAdvertising(advertiseCallback)
                advertise(advertiser)
            },
            rotation,
            SystemClock.uptimeMillis() + delay,
        )
    }

    /** Stops discovery, closes every connection and reports [RadioListener.linkDown] for each link. */
    fun stop() {
        if (following) {
            context.unregisterReceiver(adapterReceiver)
            following = false
        }
        scanner?.stopScan(scanCallback)
        advertiser?.stopAdvertising(advertiseCallback)
        release()
    }

    // Once the adapter leaves STATE_ON the stack drops scans and advertising itself, and stopping
    // them throws IllegalStateException, so release skips them.
    // The advertiser goes first, so links closing here don't restart advertising.
    private fun release() {
        advertiser = null
        advertising = false
        handler.removeCallbacksAndMessages(rotation)
        handler.removeCallbacksAndMessages(evaluation)
        handler.removeCallbacksAndMessages(rescanning)
        centrals.values.toList().forEach(Central::close)
        peripherals.values.toList().forEach(Peripheral::close)
        server?.close()
        scanner = null
        server = null
        serverMtus.clear()
        serverConnected.clear()
    }

    private var following = false

    // A stack restart after a controller fault also turns Bluetooth off and on (issue 53).
    private val adapterReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)) {
                BluetoothAdapter.STATE_TURNING_OFF, BluetoothAdapter.STATE_OFF -> if (server != null) {
                    release()
                    availability(false)
                }
                BluetoothAdapter.STATE_ON -> if (server == null && open()) availability(true)
            }
        }
    }

    // Posted, because the driver calls these while it dispatches, possibly before linkUp returned the id.
    override fun send(link: ULong, fragment: ByteArray) {
        handler.post {
            links[link]?.let {
                trace(link, "out", fragment)
                it.send(fragment)
            }
        }
    }

    override fun disconnect(link: ULong) {
        handler.post { links[link]?.close() }
    }

    /** Dials [device] unless both advertise a beacon and ours is the higher one (ADR 0025). */
    private fun connect(device: BluetoothDevice, beacon: ByteArray?) {
        val address = device.address
        if (address in centrals || address in peripherals) return
        val now = SystemClock.elapsedRealtime()
        val waiting = address !in serverConnected && now >= (dials[address]?.notBefore ?: now)
        if (waiting && slotsInUse() >= maxSlots) evict(now, address)
        if (beacon != null && compareUnsigned(advertised, beacon) > 0) return
        if (dialsInFlight() >= maxDialsInFlight || slotsInUse() >= maxSlots) return
        val dial = dials.getOrPut(address) { Dial(now + random.nextLong(0, FIRST_DIAL_SPREAD_MS + 1)) }
        if (now < dial.notBefore || now < nextDialAt) return
        dial.notBefore = now + ATTEMPT_INTERVAL_MS
        val level = congestion.level
        nextDialAt = now + level.dialGapMs * (1 shl minOf(dialFailures, MAX_GAP_DOUBLINGS))
        val central = Central(address, dial, now)
        val gatt: BluetoothGatt = device.connectGatt(context, false, central, BluetoothDevice.TRANSPORT_LE) ?: return
        central.gatt = gatt
        centrals[address] = central
        budget()
        // A stack may wait 30 s for a peer that is gone, holding the slot (ADR 0025).
        handler.postDelayed({
            if (centrals[address] === central && !central.isUp) {
                Log.i(TAG, "dial ${address.takeLast(5)} timed out")
                central.close()
            }
        }, level.dialTimeoutMs)
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val beacon = result.scanRecord?.getServiceData(ParcelUuid(GattProfile.SERVICE))
            handler.post {
                if (server != null) {
                    congestion.sighted(result.device.address, SystemClock.elapsedRealtime())
                    connect(result.device, beacon)
                }
            }
        }
    }

    private val advertiseCallback = object : AdvertiseCallback() {}

    // The trace times pairing and Resume on devices (spec §4.4): link up, each fragment's header
    // byte (frame type and step, §4.2) and size, and link down, in ms since link up.
    private fun up(role: GattRole, mtu: Int, address: String): ULong {
        val link = listener.linkUp(role, mtu.toUShort(), address.encodeToByteArray())
        upAt[link] = SystemClock.elapsedRealtime()
        activeAt[link] = upAt.getValue(link)
        Log.d(TAG, "link $link up $role mtu $mtu")
        return link
    }

    private fun since(link: ULong) = SystemClock.elapsedRealtime() - upAt.getValue(link)

    private fun trace(link: ULong, direction: String, fragment: ByteArray) {
        activeAt[link] = SystemClock.elapsedRealtime()
        val header = fragment.copyOf(minOf(1, fragment.size)).joinToString("") { "%02x".format(it) }
        Log.d(TAG, "link $link $direction 0x$header ${fragment.size} B at ${since(link)} ms")
    }

    private fun received(link: ULong, fragment: ByteArray) {
        trace(link, "in", fragment)
        listener.received(link, fragment)
    }

    private fun down(link: ULong) {
        Log.d(TAG, "link $link down at ${since(link)} ms")
        upAt.remove(link)
        activeAt.remove(link)
        links.remove(link)
        listener.linkDown(link)
    }

    /** Closes the longest link idle for [LINK_IDLE_MS], at most once per [EVICTION_INTERVAL_MS] (ADR 0025). */
    private fun evict(now: Long, waiting: String) {
        if (now - evictedAt < EVICTION_INTERVAL_MS) return
        val (link, at) = activeAt.minByOrNull { it.value } ?: return
        if (now - at < LINK_IDLE_MS) return
        evictedAt = now
        Log.i(TAG, "slots full; evicting link $link idle ${now - at} ms for ${waiting.takeLast(5)}")
        links.getValue(link).close()
    }

    /**
     * When the central may next dial one address (spec §10.4). A dial that fails before link-up is
     * retried twice after random delays, so two devices that dialled each other at once fall out of
     * step; a third failure, or a dial that linked, waits [ATTEMPT_INTERVAL_MS].
     */
    private inner class Dial(var notBefore: Long) {
        private var failures = 0

        fun linked() {
            failures = 0
        }

        /** Records a failed dial at [now] and returns the delay until the next one. */
        fun failed(now: Long): Long {
            failures++
            val delay = when (failures) {
                1 -> random.nextLong(1_000, 5_001)
                2 -> random.nextLong(5_000, 15_001)
                else -> ATTEMPT_INTERVAL_MS.also { failures = 0 }
            }
            notBefore = now + delay
            return delay
        }
    }

    /** A link where we are the GATT client: connect, MTU, discovery, `tx` subscription, then `beacon`. */
    private inner class Central(val address: String, val dial: Dial, val dialledAt: Long) :
        BluetoothGattCallback(),
        Link {
        lateinit var gatt: BluetoothGatt
        private var stage = Stage.CONNECTING
        val isUp get() = stage == Stage.UP
        private var mtu = GattProfile.DEFAULT_MTU
        private var link = 0uL
        private lateinit var rx: BluetoothGattCharacteristic
        private lateinit var beacon: BluetoothGattCharacteristic
        private var reading = false
        private var held: ByteArray? = null
        private var status = BluetoothGatt.GATT_SUCCESS

        private fun post(block: () -> Unit) {
            handler.post { if (centrals[address] === this) block() }
        }

        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) = post {
            this.status = status
            if (status == BluetoothGatt.GATT_SUCCESS && newState == BluetoothProfile.STATE_CONNECTED) {
                // Both are preferences the controller may decline, so a refusal doesn't close the link.
                gatt.requestConnectionPriority(BluetoothGatt.CONNECTION_PRIORITY_HIGH)
                gatt.setPreferredPhy(
                    BluetoothDevice.PHY_LE_2M_MASK,
                    BluetoothDevice.PHY_LE_2M_MASK,
                    BluetoothDevice.PHY_OPTION_NO_PREFERRED,
                )
                handler.postDelayed({
                    if (centrals[address] === this) {
                        gatt.requestConnectionPriority(BluetoothGatt.CONNECTION_PRIORITY_BALANCED)
                    }
                }, PRE_AUTH_WINDOW_MS)
                if (!gatt.requestMtu(GattProfile.MAX_MTU)) close()
            } else {
                close()
            }
        }

        override fun onPhyUpdate(gatt: BluetoothGatt, txPhy: Int, rxPhy: Int, status: Int) = post {
            Log.d(TAG, "dial ${address.takeLast(5)} phy tx $txPhy rx $rxPhy status 0x%02x".format(status))
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
                dial.linked()
                dialFailures = 0
                congestion.dialEnded(SystemClock.elapsedRealtime(), failed = false)
                link = up(GattRole.CENTRAL, mtu, address)
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
            if (stage == Stage.UP) received(link, value)
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
            budget()
            gatt.disconnect()
            gatt.close()
            if (stage == Stage.UP) {
                down(link)
            } else {
                val now = SystemClock.elapsedRealtime()
                val delay = dial.failed(now)
                dialFailures++
                congestion.dialEnded(now, failed = true)
                Log.i(
                    TAG,
                    "dial ${address.takeLast(5)} failed $stage status 0x%02x after %d ms; retry in %d ms"
                        .format(status, now - dialledAt, delay),
                )
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
            budget()
            down(link)
        }
    }

    private var serverTx: BluetoothGattCharacteristic? = null

    private val serverCallback = object : BluetoothGattServerCallback() {
        private fun post(block: (BluetoothGattServer) -> Unit) {
            handler.post { server?.let(block) }
        }

        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) = post { server ->
            val address = device.address
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                // A device that raced the advert stop; one sharing an address with our dial costs no slot.
                if (address !in centrals && slotsInUse() >= maxSlots) {
                    server.cancelConnection(device)
                } else {
                    serverConnected += address
                    budget()
                }
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                serverConnected -= address
                serverMtus.remove(address)
                peripherals.remove(address)?.let { down(it.link) }
                budget()
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
            if (accepted) received(peripheral.link, value)
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
                val link = up(GattRole.PERIPHERAL, mtu, address)
                val peripheral = Peripheral(device, server, serverTx!!, link)
                peripherals[address] = peripheral
                links[link] = peripheral
                budget()
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
        const val TAG = "CairnRadio"

        /** Spec §10.4: the interval between dials to one address, outside the two fast retries. */
        const val ATTEMPT_INTERVAL_MS = 120_000L

        /** Spec §4.4 twice: pairing, then Resume under a fresh deadline (ADR 0022); high priority covers both. */
        const val PRE_AUTH_WINDOW_MS = 10_000L

        /** Spec §10.4: the first dial to an address waits a random 0 to 3 s after it is first seen. */
        const val FIRST_DIAL_SPREAD_MS = 3_000L

        /** ADR 0025: a link that carried no fragment for this long may be evicted. */
        const val LINK_IDLE_MS = 30_000L

        /** ADR 0025: at most one eviction per interval. */
        const val EVICTION_INTERVAL_MS = 60_000L

        /** ADR 0026: how often the congestion level is evaluated. */
        const val EVALUATION_INTERVAL_MS = 5_000L

        /** ADR 0026: Android allows 5 scan starts per 30 s. */
        const val SCAN_RESTART_INTERVAL_MS = 10_000L

        /** ADR 0026: the dial gap doubles per failed dial in a row, up to 4 times. */
        const val MAX_GAP_DOUBLINGS = 2

        /** ADR 0026: per level, a dial not up by then fails and frees its slot (ADR 0025). */
        val Level.dialTimeoutMs get() = if (this == Level.CLEAR) 10_000L else 5_000L

        /** ADR 0026: the base gap between dial starts. */
        val Level.dialGapMs get() = when (this) {
            Level.CLEAR -> 0L
            Level.BUSY -> 1_000L
            Level.CROWDED -> 2_000L
        }

        val Level.scanMode get() = when (this) {
            Level.CLEAR -> ScanSettings.SCAN_MODE_LOW_LATENCY
            Level.BUSY -> ScanSettings.SCAN_MODE_BALANCED
            Level.CROWDED -> ScanSettings.SCAN_MODE_LOW_POWER
        }

        val Level.advertiseMode get() = when (this) {
            Level.CLEAR -> AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY
            Level.BUSY -> AdvertiseSettings.ADVERTISE_MODE_BALANCED
            Level.CROWDED -> AdvertiseSettings.ADVERTISE_MODE_LOW_POWER
        }

        /** Spec §10.1: one beacon per 300 s window of Unix time. */
        const val BEACON_WINDOW_MS = 300_000L

        /** Spec §10.1: the advert restarts up to 30 s after each window boundary. */
        const val ROTATION_JITTER_MS = 30_000L

        /** Big-endian unsigned order, as spec §10.1 beacons compare. */
        fun compareUnsigned(a: ByteArray, b: ByteArray): Int {
            for (i in 0 until minOf(a.size, b.size)) {
                val c = (a[i].toInt() and 0xff) - (b[i].toInt() and 0xff)
                if (c != 0) return c
            }
            return a.size - b.size
        }

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
