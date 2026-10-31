package ch.trancee.cairn.ble

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGattServer
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.shadows.ShadowBluetoothGattServer

/** Robolectric's server shadow records each response's value; this one also records its status. */
@Implements(BluetoothGattServer::class)
class StatusGattServer : ShadowBluetoothGattServer() {
    val statuses = mutableListOf<Int>()

    @Implementation
    override fun sendResponse(device: BluetoothDevice, requestId: Int, status: Int, offset: Int, value: ByteArray?): Boolean {
        statuses += status
        return super.sendResponse(device, requestId, status, offset, value)
    }
}
