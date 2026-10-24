package ch.trancee.cairn.ble

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothManager
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.shadows.ShadowBluetoothAdapter
import org.robolectric.shadows.ShadowBluetoothDevice
import org.robolectric.shadows.ShadowBluetoothManager

/** Stacks whose Bluetooth service is gone: Android then returns null GATT objects. */
object NullGattShadows {
    /** LE access dropped between the scanner and advertiser lookups, which use the same check. */
    @Implements(BluetoothAdapter::class)
    class Adapter : ShadowBluetoothAdapter() {
        @Implementation
        @Suppress("unused")
        fun getBluetoothLeAdvertiser(): BluetoothLeAdvertiser? = null
    }

    @Implements(BluetoothDevice::class)
    class Device : ShadowBluetoothDevice() {
        @Implementation
        override fun connectGatt(
            context: Context,
            autoConnect: Boolean,
            callback: BluetoothGattCallback,
            transport: Int,
        ): BluetoothGatt? = null
    }

    @Implements(BluetoothManager::class)
    class Manager : ShadowBluetoothManager() {
        @Implementation
        @Suppress("unused")
        fun openGattServer(context: Context, callback: BluetoothGattServerCallback): BluetoothGattServer? = null
    }
}
