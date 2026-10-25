package ch.trancee.cairn.ble

import android.os.Looper
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import java.time.Duration
import kotlin.test.assertEquals

/** Of two radios that advertise a beacon, only the lower one dials (ADR 0025). */
@RunWith(RobolectricTestRunner::class)
class DialRuleTest {
    private val h = RadioHarness()
    private val address = "00:11:22:33:44:01"

    private fun dials() = shadowOf(h.device(address)).bluetoothGatts.size

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
    fun dialsAPeerThatAdvertisesNoBeacon() {
        start(byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8))

        h.sight(address)

        assertEquals(1, dials())
    }
}
