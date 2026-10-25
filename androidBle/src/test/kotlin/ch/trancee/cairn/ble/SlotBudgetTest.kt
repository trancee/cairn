package ch.trancee.cairn.ble

import android.bluetooth.BluetoothProfile
import android.os.Build
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull

/** The radio's GATT slot budget (spec §10.4, ADR 0025). */
@RunWith(RobolectricTestRunner::class)
class SlotBudgetTest {
    private val h = RadioHarness().also { it.radio.start() }
    private val slots = if (Build.VERSION.SDK_INT >= 35) 6 else 5
    private val pending = if (Build.VERSION.SDK_INT <= 28) 1 else 2

    private fun address(i: Int) = "00:11:22:33:44:%02X".format(i)

    private fun dials(i: Int) = shadowOf(h.device(address(i))).bluetoothGatts.size

    private fun serverConnect(i: Int) {
        h.serverCallback().onConnectionStateChange(h.device(address(i)), 0, BluetoothProfile.STATE_CONNECTED)
        h.idle()
    }

    @Test
    fun dialsAtMostOneOrTwoPeersAtOnce() {
        (1..3).forEach { h.sight(address(it)) }

        assertEquals(List(pending) { 1 } + List(3 - pending) { 0 }, (1..3).map(::dials))
    }

    @Test
    fun aFailedDialFreesItsPlace() {
        (1..pending).forEach { h.discover(address(it)) }
        val gatt = shadowOf(h.device(address(1))).bluetoothGatts.single()
        h.callback(gatt).onConnectionStateChange(gatt, 133, BluetoothProfile.STATE_DISCONNECTED)
        h.idle()

        h.sight(address(9))

        assertEquals(1, dials(9))
    }

    @Test
    fun dialsNoMoreOnceEverySlotIsInUse() {
        (1..slots - 1).forEach { h.connect(h.discover(address(it))!!) }
        serverConnect(20)

        assertNull(h.discover(address(9)))
    }

    @Test
    fun aDeviceConnectedBothWaysTakesOneSlot() {
        (1..slots - 1).forEach {
            serverConnect(it)
            h.connect(h.discover(address(it))!!)
        }

        assertNotNull(h.discover(address(9)))
    }

    @Test
    fun aServerConnectionTakesItsSlotOnlyOnceConnected() {
        (1..slots - 1).forEach { h.connect(h.discover(address(it))!!) }
        h.serverCallback().onConnectionStateChange(h.device(address(20)), 0, BluetoothProfile.STATE_CONNECTING)
        h.idle()

        assertNotNull(h.discover(address(9)))
    }
}
