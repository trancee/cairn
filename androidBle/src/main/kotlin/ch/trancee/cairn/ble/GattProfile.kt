package ch.trancee.cairn.ble

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.AdvertisingSetParameters
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanSettings
import android.os.ParcelUuid
import java.util.UUID

/** The cairn GATT service (spec §12, ADR 0003) and the S2 discovery settings (ADR 0023 §3). */
object GattProfile {
    val SERVICE: UUID = UUID.fromString("d8177748-2cfa-4aa1-b3d0-c46de25a0e45")
    val BEACON: UUID = UUID.fromString("725e4d3d-d899-4e4e-990a-af2bac20deb4")
    val RX: UUID = UUID.fromString("eabb6cc0-aa49-4dd4-ae89-af2383e291dd")
    val TX: UUID = UUID.fromString("d91c38e6-5dbc-4eee-828b-707e41d63451")
    val PSM: UUID = UUID.fromString("1446537a-3d32-4b5c-89d9-8c05f045487a")

    /** The standard Client Characteristic Configuration descriptor. */
    val CCCD: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

    /** ATT MTU before any exchange. */
    const val DEFAULT_MTU = 23

    /** The largest ATT MTU; the central requests it once per link. */
    const val MAX_MTU = 517

    /** A fresh service for the local GATT server. */
    fun service(): BluetoothGattService = BluetoothGattService(SERVICE, BluetoothGattService.SERVICE_TYPE_PRIMARY).apply {
        addCharacteristic(characteristic(BEACON, BluetoothGattCharacteristic.PROPERTY_READ, BluetoothGattCharacteristic.PERMISSION_READ))
        addCharacteristic(characteristic(RX, BluetoothGattCharacteristic.PROPERTY_WRITE, BluetoothGattCharacteristic.PERMISSION_WRITE))
        addCharacteristic(
            characteristic(TX, BluetoothGattCharacteristic.PROPERTY_NOTIFY, 0).apply {
                addDescriptor(
                    BluetoothGattDescriptor(
                        CCCD,
                        BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE,
                    ),
                )
            },
        )
        addCharacteristic(characteristic(PSM, BluetoothGattCharacteristic.PROPERTY_READ, BluetoothGattCharacteristic.PERMISSION_READ))
    }

    /** Legacy, connectable, untimed advertising; [mode] follows the energy band (spec §10.4). */
    fun advertiseSettings(mode: Int): AdvertiseSettings = AdvertiseSettings.Builder()
        .setAdvertiseMode(mode)
        .setConnectable(true)
        .setTimeout(0)
        .build()

    /**
     * An extended, connectable, non-scannable set (spec §10.1, ADR 0028), at the interval of the
     * legacy [mode]. The primary PHY is 1M; the auxiliary packet goes on 2M where [le2M] allows,
     * since iOS reports only those (ADR 0038).
     */
    fun advertisingSetParameters(mode: Int, le2M: Boolean): AdvertisingSetParameters = AdvertisingSetParameters.Builder()
        .setLegacyMode(false)
        .setConnectable(true)
        .setScannable(false)
        .setPrimaryPhy(BluetoothDevice.PHY_LE_1M)
        .setSecondaryPhy(if (le2M) BluetoothDevice.PHY_LE_2M else BluetoothDevice.PHY_LE_1M)
        .setInterval(
            when (mode) {
                AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY -> AdvertisingSetParameters.INTERVAL_LOW
                AdvertiseSettings.ADVERTISE_MODE_BALANCED -> AdvertisingSetParameters.INTERVAL_MEDIUM
                else -> AdvertisingSetParameters.INTERVAL_HIGH
            },
        )
        .build()

    /**
     * Service data, service UUID ‖ [beacon] (spec §10.1, ADR 0025): 3 B flags plus 2 + 16 + 8 B fit
     * the 31 B legacy payload.
     */
    fun advertiseData(beacon: ByteArray): AdvertiseData = AdvertiseData.Builder()
        .addServiceData(ParcelUuid(SERVICE), beacon)
        .setIncludeDeviceName(false)
        .build()

    /** Either advert form: the bare service UUID of older builds, or service data with a beacon. */
    fun scanFilters(): List<ScanFilter> = listOf(
        ScanFilter.Builder().setServiceUuid(ParcelUuid(SERVICE)).build(),
        ScanFilter.Builder().setServiceData(ParcelUuid(SERVICE), ByteArray(0)).build(),
    )

    /**
     * [mode] follows the energy band (spec §10.4); an [extended] scan receives extended adverts as
     * well as legacy ones, on every supported PHY (ADR 0028).
     */
    fun scanSettings(mode: Int, extended: Boolean): ScanSettings = ScanSettings.Builder()
        .setScanMode(mode)
        .apply { if (extended) setLegacy(false).setPhy(ScanSettings.PHY_LE_ALL_SUPPORTED) }
        .build()

    private fun characteristic(uuid: UUID, properties: Int, permissions: Int) =
        BluetoothGattCharacteristic(uuid, properties, permissions)
}
