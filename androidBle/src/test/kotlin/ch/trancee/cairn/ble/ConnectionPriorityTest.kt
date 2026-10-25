package ch.trancee.cairn.ble

import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothProfile
import android.os.Looper
import java.time.Duration
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.shadows.ShadowLog

/** Fast connection events and the 2M PHY during the pre-auth window (spec §4.4, issue 52). */
@RunWith(RobolectricTestRunner::class)
class ConnectionPriorityTest {
    private val h = RadioHarness().also { it.radio.start() }

    private fun advance(ms: Long) = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(ms))

    @Test
    fun centralRequestsHighPriorityAnd2mPhyOnConnect() {
        val gatt = h.discover("00:11:22:33:44:01")!!

        h.connect(gatt)

        assertEquals(BluetoothGatt.CONNECTION_PRIORITY_HIGH, h.shadow(gatt).connectionPriority)
        assertTrue("dial 44:01 phy tx 2 rx 2 status 0x00" in ShadowLog.getLogsForTag("CairnRadio").map { it.msg })
    }

    @Test
    fun centralReturnsToBalancedTenSecondsAfterConnect() {
        val gatt = h.discover("00:11:22:33:44:01")!!
        h.connect(gatt)
        advance(9_999)
        assertEquals(BluetoothGatt.CONNECTION_PRIORITY_HIGH, h.shadow(gatt).connectionPriority)

        advance(1)

        assertEquals(BluetoothGatt.CONNECTION_PRIORITY_BALANCED, h.shadow(gatt).connectionPriority)
    }

    @Test
    fun closedLinkKeepsItsLastPriority() {
        val gatt = h.discover("00:11:22:33:44:01")!!
        h.connect(gatt)
        h.callback(gatt).onConnectionStateChange(gatt, BluetoothGatt.GATT_SUCCESS, BluetoothProfile.STATE_DISCONNECTED)
        h.idle()

        advance(10_000)

        assertEquals(BluetoothGatt.CONNECTION_PRIORITY_HIGH, h.shadow(gatt).connectionPriority)
    }
}
