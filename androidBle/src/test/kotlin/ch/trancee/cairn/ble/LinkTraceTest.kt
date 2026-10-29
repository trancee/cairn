package ch.trancee.cairn.ble

import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothProfile
import android.os.Build
import android.os.Looper
import java.time.Duration
import kotlin.test.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.shadows.ShadowLog

/** The per-link trace that times pairing and Resume on devices (spec §4.4). */
@RunWith(RobolectricTestRunner::class)
class LinkTraceTest {
    private val h = RadioHarness().also { it.radio.start() }

    private fun advance(ms: Long) = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(ms))

    private fun trace() = ShadowLog.getLogsForTag("CairnRadio").map { it.msg }.filter { it.startsWith("link ") }

    @Test
    fun centralLinkTracesEveryFragmentWithItsHeaderSizeAndTimeSinceLinkUp() {
        val gatt = h.discover("00:11:22:33:44:01")!!
        h.connect(gatt)
        val tx = gatt.getService(GattProfile.SERVICE).getCharacteristic(GattProfile.TX)
        advance(40)
        h.radio.send(1u, byteArrayOf(0x00, 1, 2))
        h.idle()
        advance(260)
        if (Build.VERSION.SDK_INT >= 33) {
            h.callback(gatt).onCharacteristicChanged(gatt, tx, byteArrayOf(0x81.toByte(), 9))
        } else {
            @Suppress("DEPRECATION")
            tx.value = byteArrayOf(0x81.toByte(), 9)
            @Suppress("DEPRECATION")
            h.callback(gatt).onCharacteristicChanged(gatt, tx)
        }
        h.idle()
        advance(4_700)

        h.callback(gatt).onConnectionStateChange(gatt, 0x08, BluetoothProfile.STATE_DISCONNECTED)
        h.idle()

        assertEquals(
            listOf(
                "link 1 up CENTRAL mtu 517",
                "link 1 out 0x00 3 B at 40 ms",
                "link 1 in 0x81 2 B at 300 ms",
                "link 1 lost status 0x08",
                "link 1 down at 5000 ms",
            ),
            trace(),
        )
    }

    @Test
    fun peripheralLinkTracesItsFragments() {
        val device = h.device("00:11:22:33:44:02")
        h.registerServer()
        h.subscribe(device)
        h.serverCallback().onCharacteristicWriteRequest(
            device, 2, h.characteristic(GattProfile.RX), false, false, 0, byteArrayOf(0x10, 1),
        )
        h.idle()
        h.radio.send(1u, byteArrayOf(0x20))
        h.idle()

        h.radio.disconnect(1u)
        h.idle()

        assertEquals(
            listOf(
                "link 1 up PERIPHERAL mtu 23",
                "link 1 in 0x10 2 B at 0 ms",
                "link 1 out 0x20 1 B at 0 ms",
                "link 1 close requested",
                "link 1 down at 0 ms",
            ),
            trace(),
        )
    }

    @Test
    fun peripheralLinkTracesTheStatusOfAConnectionThePeerEnded() {
        val device = h.device("00:11:22:33:44:02")
        h.registerServer()
        h.subscribe(device)

        h.serverCallback().onConnectionStateChange(device, 0x13, BluetoothProfile.STATE_DISCONNECTED)
        h.idle()

        assertEquals(listOf("link 1 up PERIPHERAL mtu 23", "link 1 lost status 0x13", "link 1 down at 0 ms"), trace())
    }
}
