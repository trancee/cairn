package ch.trancee.cairn.ble

import android.Manifest
import android.app.Application
import androidx.test.core.app.ApplicationProvider
import kotlin.test.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
class BlePermissionsTest {
    private val context: Application = ApplicationProvider.getApplicationContext()

    @Test
    @Config(sdk = [37])
    fun api31AndLaterNeedTheNearbyDevicesPermissions() {
        assertEquals(
            listOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_ADVERTISE,
            ),
            BlePermissions.required(),
        )
    }

    @Test
    @Config(sdk = [26])
    fun olderReleasesNeedFineLocationToScan() {
        assertEquals(listOf(Manifest.permission.ACCESS_FINE_LOCATION), BlePermissions.required())
    }

    @Test
    fun missingListsOnlyTheUngrantedPermissions() {
        val required = BlePermissions.required()
        shadowOf(context).grantPermissions(required.first())

        assertEquals(required.drop(1), BlePermissions.missing(context))
    }
}
