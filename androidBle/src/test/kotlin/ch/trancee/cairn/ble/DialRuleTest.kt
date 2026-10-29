package ch.trancee.cairn.ble

import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothProfile
import android.os.Looper
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import java.time.Duration
import kotlin.test.assertEquals

/**
 * Of two radios that advertise a beacon, only the lower one dials (ADR 0025), unless one advertises
 * extended and sees the other advertise legacy (ADR 0028). An iOS peer, or one connected to the
 * server, gets 10 s to dial first (ADR 0039).
 */
@RunWith(RobolectricTestRunner::class)
class DialRuleTest {
    private val h = RadioHarness()
    private val address = "00:11:22:33:44:01"

    private fun dials() = shadowOf(h.device(address)).bluetoothGatts.size

    private fun advance(ms: Long) = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(ms))

    private fun extended() = shadowOf(h.adapter).setIsLeExtendedAdvertisingSupported(true)

    private fun start(own: ByteArray) {
        h.listener.beaconValue = own
        h.radio.start()
    }

    @Test
    fun dialsAPeerWithAHigherBeacon() {
        start(byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8))

        h.sight(address, byteArrayOf(1, 2, 3, 4, 5, 6, 7, 9))

        assertEquals(1, dials())
    }

    @Test
    fun leavesAPeerWithALowerBeaconToDialUs() {
        start(byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8))
        h.sight(address, byteArrayOf(1, 2, 3, 4, 5, 6, 7, 7))
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(5))

        h.sight(address, byteArrayOf(1, 2, 3, 4, 5, 6, 7, 7))

        assertEquals(0, dials())
        assertEquals(emptyList(), h.random.ranges.filter { it == 0L..3_000L })
    }

    @Test
    fun comparesBeaconsUnsigned() {
        start(byteArrayOf(0x80.toByte(), 0, 0, 0, 0, 0, 0, 0))

        h.sight(address, byteArrayOf(0x7f, 0, 0, 0, 0, 0, 0, 0))

        assertEquals(0, dials())
    }

    @Test
    fun dialsAPeerWithTheSameBeacon() {
        start(byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8))

        h.sight(address, byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8))

        assertEquals(1, dials())
    }

    @Test
    fun dialsAPeerThatAdvertisesNoBeaconOnlyTenSecondsAfterFirstSeeingIt() {
        start(byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8))
        h.sight(address)
        advance(9_999)
        h.sight(address)
        val early = dials()
        advance(1)

        h.sight(address)

        assertEquals(0, early)
        assertEquals(1, dials())
    }

    @Test
    fun leavesAPeerThatConnectedToTheServerTenSecondsToLinkBeforeDiallingIt() {
        start(byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8))
        h.serverCallback().onConnectionStateChange(h.device(address), BluetoothGatt.GATT_SUCCESS, BluetoothProfile.STATE_CONNECTED)
        h.sight(address, byteArrayOf(1, 2, 3, 4, 5, 6, 7, 9))
        advance(9_999)
        h.sight(address, byteArrayOf(1, 2, 3, 4, 5, 6, 7, 9))
        val early = dials()
        advance(1)

        h.sight(address, byteArrayOf(1, 2, 3, 4, 5, 6, 7, 9))

        assertEquals(0, early)
        assertEquals(1, dials())
    }

    private fun serverDisconnected() {
        h.serverCallback().onConnectionStateChange(h.device(address), BluetoothGatt.GATT_SUCCESS, BluetoothProfile.STATE_DISCONNECTED)
        h.idle()
    }

    /** Sights the peer just before and at [ms] after now; returns the dials at each. */
    private fun dialsBeforeAndAt(ms: Long, beacon: ByteArray?): List<Int> {
        advance(ms - 1)
        h.sight(address, beacon)
        val early = dials()
        advance(1)
        h.sight(address, beacon)
        return listOf(early, dials())
    }

    @Test
    fun leavesAPeerWhoseServerConnectionEndedWithoutALinkFifteenSecondsToRedial() {
        start(byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8))
        h.random.pick = { _, until -> until - 1 }
        h.serverCallback().onConnectionStateChange(h.device(address), BluetoothGatt.GATT_SUCCESS, BluetoothProfile.STATE_CONNECTED)
        h.idle()

        serverDisconnected()
        h.sight(address, byteArrayOf(1, 2, 3, 4, 5, 6, 7, 9))

        assertEquals(listOf(0, 1), dialsBeforeAndAt(18_000, byteArrayOf(1, 2, 3, 4, 5, 6, 7, 9)))
        assertEquals(0L..3_000L, h.random.ranges.last())
    }

    @Test
    fun leavesAnIosPeerWhosePeripheralLinkWentDownFifteenSecondsToRedial() {
        start(byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8))
        h.sight(address)
        h.subscribe(h.device(address))
        advance(20_000)

        serverDisconnected()

        assertEquals(listOf(0, 1), dialsBeforeAndAt(15_000, beacon = null))
    }

    @Test
    fun anExtendedAdvertiserDialsALegacyAdvertiserWithALowerBeacon() {
        extended()
        start(byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8))

        h.sight(address, byteArrayOf(1, 2, 3, 4, 5, 6, 7, 7))

        assertEquals(1, dials())
    }

    @Test
    fun anExtendedAdvertiserLeavesAnExtendedAdvertiserWithALowerBeacon() {
        extended()
        start(byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8))

        h.sight(address, byteArrayOf(1, 2, 3, 4, 5, 6, 7, 7), legacy = false)

        assertEquals(0, dials())
    }

    @Test
    fun aLegacyAdvertiserLeavesAnExtendedAdvertiserWithALowerBeacon() {
        start(byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8))

        h.sight(address, byteArrayOf(1, 2, 3, 4, 5, 6, 7, 7), legacy = false)

        assertEquals(0, dials())
    }
}
