package ch.trancee.cairn.ble

import android.bluetooth.BluetoothGattCharacteristic.PERMISSION_READ
import android.bluetooth.BluetoothGattCharacteristic.PERMISSION_WRITE
import android.bluetooth.BluetoothGattCharacteristic.PROPERTY_NOTIFY
import android.bluetooth.BluetoothGattCharacteristic.PROPERTY_READ
import android.bluetooth.BluetoothGattCharacteristic.PROPERTY_WRITE
import android.bluetooth.BluetoothGattService
import java.util.UUID
import kotlin.test.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class GattProfileTest {
    @Test
    fun uuidsMatchSpecSection12() {
        assertEquals(UUID.fromString("d8177748-2cfa-4aa1-b3d0-c46de25a0e45"), GattProfile.SERVICE)
        assertEquals(UUID.fromString("725e4d3d-d899-4e4e-990a-af2bac20deb4"), GattProfile.BEACON)
        assertEquals(UUID.fromString("eabb6cc0-aa49-4dd4-ae89-af2383e291dd"), GattProfile.RX)
        assertEquals(UUID.fromString("d91c38e6-5dbc-4eee-828b-707e41d63451"), GattProfile.TX)
        assertEquals(UUID.fromString("1446537a-3d32-4b5c-89d9-8c05f045487a"), GattProfile.PSM)
        assertEquals(UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"), GattProfile.CCCD)
    }

    @Test
    fun serviceDeclaresEachCharacteristicWithItsAccess() {
        val service = GattProfile.service()

        assertEquals(BluetoothGattService.SERVICE_TYPE_PRIMARY, service.type)
        val access = service.characteristics.associate { it.uuid to (it.properties to it.permissions) }
        assertEquals(
            mapOf(
                GattProfile.BEACON to (PROPERTY_READ to PERMISSION_READ),
                GattProfile.RX to (PROPERTY_WRITE to PERMISSION_WRITE),
                GattProfile.TX to (PROPERTY_NOTIFY to 0),
                GattProfile.PSM to (PROPERTY_READ to PERMISSION_READ),
            ),
            access,
        )
        val cccd = service.getCharacteristic(GattProfile.TX).descriptors.single()
        assertEquals(GattProfile.CCCD, cccd.uuid)
        assertEquals(PERMISSION_READ or PERMISSION_WRITE, cccd.permissions)
    }
}
