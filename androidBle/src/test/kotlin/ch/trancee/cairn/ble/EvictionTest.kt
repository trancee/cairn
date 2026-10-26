package ch.trancee.cairn.ble

import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothProfile
import android.os.Build
import android.os.Looper
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import java.time.Duration
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** A full radio frees its longest-idle rotating link for a waiting peer (spec §10.4, ADR 0025, ADR 0031). */
@RunWith(RobolectricTestRunner::class)
class EvictionTest {
    private val h = RadioHarness().also { it.radio.start() }
    private val slots = if (Build.VERSION.SDK_INT >= 35) 6 else 5
    private val quota = slots * 3 / 4
    private val rotating = quota + 1
    private val waiting = address(30)

    private fun address(i: Int) = "00:11:22:33:44:%02X".format(i)

    private fun advance(ms: Long) = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(ms))

    /** Links 1..[quota] are the strongest and stay; the rest rotate. */
    private fun link(i: Int): BluetoothGatt =
        h.discover(address(i))!!.also { h.shadow(it).setRssi(if (i <= quota) -40 else -90) }.also(h::connect)

    private fun downs() = h.listener.events.filter { it.startsWith("down") }

    /** Fills every slot with central links 1..slots, the first rotating one up 10 s before the rest. */
    private fun fill(): List<BluetoothGatt> {
        val first = (1..rotating).map(::link)
        advance(10_000)
        return first + (rotating + 1..slots).map(::link)
    }

    @Test
    fun closesTheLongestIdleLinkWhenANewPeerWaits() {
        val gatts = fill()
        advance(30_000)

        h.sight(waiting)

        assertEquals(listOf("down $rotating"), downs())
        assertTrue(h.shadow(gatts[rotating - 1]).isClosed)
    }

    @Test
    fun keepsLinksIdleForUnderThirtySeconds() {
        fill()
        advance(19_999)

        h.sight(waiting)

        assertEquals(emptyList(), downs())
    }

    @Test
    fun aFragmentKeepsALinkActive() {
        fill()
        advance(30_000)
        h.radio.send(rotating.toULong(), byteArrayOf(1))
        h.idle()

        h.sight(waiting)

        assertEquals(listOf("down ${rotating + 1}"), downs())
    }

    @Test
    fun evictsAtMostOnceEveryFifteenSeconds() {
        fill()
        advance(30_000)
        h.connect(h.discover(waiting)!!)
        advance(14_999)

        h.sight(address(32))
        val early = downs().size
        advance(1)
        h.sight(address(32))

        assertEquals(1, early)
        assertEquals(2, downs().size)
    }

    @Test
    fun doesNotEvictForAnAddressItIsBackingOff() {
        val dropped = link(29)
        h.callback(dropped).onConnectionStateChange(dropped, 8, BluetoothProfile.STATE_DISCONNECTED)
        h.idle()
        fill()
        advance(30_000)

        h.sight(address(29))

        assertEquals(listOf("down 1"), downs())
    }

    @Test
    fun doesNotEvictForADeviceConnectedToItsServer() {
        link(1)
        advance(10_000)
        (2..<slots).forEach(::link)
        h.serverCallback().onConnectionStateChange(h.device(waiting), 0, BluetoothProfile.STATE_CONNECTED)
        h.idle()
        advance(30_000)

        h.sight(waiting)

        assertEquals(emptyList(), downs())
    }

    @Test
    fun evictsNothingWhenEverySlotIsAnUnsubscribedServerConnection() {
        (1..slots).forEach {
            h.serverCallback().onConnectionStateChange(h.device(address(it)), 0, BluetoothProfile.STATE_CONNECTED)
        }
        h.idle()
        advance(30_000)

        h.sight(waiting)

        assertFalse(shadowOf(h.server).isConnectionCancelled(h.device(address(1))))
        assertEquals(0, shadowOf(h.device(waiting)).bluetoothGatts.size)
    }

    @Test
    fun evictsTheOnlyRotatingLinkAmongServerConnections() {
        (1..rotating).forEach(::link)
        (rotating + 1..slots).forEach {
            h.serverCallback().onConnectionStateChange(h.device(address(it)), 0, BluetoothProfile.STATE_CONNECTED)
        }
        h.idle()
        advance(30_000)

        h.sight(waiting)

        assertEquals(listOf("down $rotating"), downs())
    }
}
