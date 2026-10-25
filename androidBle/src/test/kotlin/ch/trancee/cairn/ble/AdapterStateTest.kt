package ch.trancee.cairn.ble

import android.bluetooth.BluetoothAdapter
import android.content.Intent
import android.provider.Settings
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNotSame
import kotlin.test.assertNull
import kotlin.test.assertSame
import kotlin.test.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

/** The radio follows Bluetooth turning off and on while started, including a stack restart. */
@RunWith(RobolectricTestRunner::class)
class AdapterStateTest {
    private val h = RadioHarness()
    private val availability = mutableListOf<Boolean>()

    init {
        h.radio.availability = { availability += it }
    }

    private fun adapter(state: Int) {
        h.context.sendBroadcast(Intent(BluetoothAdapter.ACTION_STATE_CHANGED).putExtra(BluetoothAdapter.EXTRA_STATE, state))
        h.idle()
    }

    @Test
    fun bluetoothTurningOffEndsEveryLinkAndReportsTheRadioUnavailable() {
        h.radio.start()
        val server = h.server
        val linked = h.discover("00:11:22:33:44:01")!!
        h.connect(linked)
        val pending = h.discover("00:11:22:33:44:02")!!
        h.subscribe(h.device("00:11:22:33:44:03"))

        adapter(BluetoothAdapter.STATE_TURNING_OFF)

        assertEquals(listOf("down 1", "down 2"), h.listener.events.filter { it.startsWith("down") })
        assertTrue(h.shadow(linked).isClosed)
        assertTrue(h.shadow(pending).isClosed)
        assertTrue(shadowOf(server).isClosed)
        assertNull(h.radio.server)
        assertEquals(listOf(false), availability)
    }

    @Test
    fun bluetoothTurningOffReportsUnavailableOnce() {
        h.radio.start()

        adapter(BluetoothAdapter.STATE_TURNING_OFF)
        adapter(BluetoothAdapter.STATE_OFF)

        assertEquals(listOf(false), availability)
    }

    @Test
    fun bluetoothTurningBackOnReopensTheRadio() {
        h.radio.start()
        val first = h.server
        adapter(BluetoothAdapter.STATE_OFF)
        val scanner = h.adapter.bluetoothLeScanner!!
        scanner.stopScan(h.scanCallback()) // as the stack does on its way off

        adapter(BluetoothAdapter.STATE_TURNING_ON)
        adapter(BluetoothAdapter.STATE_ON)

        assertNotSame(first, h.server)
        assertEquals(1, shadowOf(scanner).activeScans.size)
        assertEquals(listOf(false, true), availability)
    }

    @Test
    fun bluetoothOnWhileRunningChangesNothing() {
        h.radio.start()
        val server = h.server

        adapter(BluetoothAdapter.STATE_ON)

        assertSame(server, h.server)
        assertEquals(emptyList(), availability)
    }

    @Test
    fun startWhileBluetoothIsOffOpensTheRadioOnceItTurnsOn() {
        shadowOf(h.adapter).setEnabled(false)
        h.radio.start()
        shadowOf(h.adapter).setEnabled(true)

        adapter(BluetoothAdapter.STATE_ON)

        assertNotNull(h.radio.server)
        assertEquals(listOf(true), availability)
    }

    @Test
    fun bluetoothOnThatCannotOpenTheRadioReportsNothing() {
        h.radio.start()
        adapter(BluetoothAdapter.STATE_OFF)
        Settings.Global.putInt(h.context.contentResolver, Settings.Global.AIRPLANE_MODE_ON, 1)

        adapter(BluetoothAdapter.STATE_ON)

        assertNull(h.radio.server)
        assertEquals(listOf(false), availability)
    }

    @Test
    fun stopStopsFollowingTheAdapter() {
        h.radio.start()
        h.radio.stop()

        adapter(BluetoothAdapter.STATE_ON)

        assertNull(h.radio.server)
        assertEquals(emptyList(), availability)
    }
}
