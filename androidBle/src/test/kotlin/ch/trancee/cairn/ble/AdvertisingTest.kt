package ch.trancee.cairn.ble

import android.bluetooth.le.AdvertiseCallback
import android.os.Looper
import android.os.ParcelUuid
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadow.api.Shadow
import org.robolectric.shadows.ShadowLog
import java.time.Duration
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** The beacon advert and its rotation (spec §10.1, ADR 0025). */
@RunWith(RobolectricTestRunner::class)
class AdvertisingTest {
    private val h = RadioHarness()
    private val advertiser get() = shadowOf(h.adapter.bluetoothLeAdvertiser)
    private val next = byteArrayOf(8, 7, 6, 5, 4, 3, 2, 1)

    private fun advance(ms: Long) = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(ms))

    private fun advertised(): ByteArray = advertiser.lastAdvertisingData.serviceData.getValue(ParcelUuid(GattProfile.SERVICE))

    @Test
    fun restartsTheAdvertWithTheNextBeaconAtTheWindowBoundaryPlusJitter() {
        h.random.pick = { from, _ -> from + 7_000 }
        h.radio.start()
        val first = h.listener.beaconValue
        h.listener.beaconValue = next

        advance(200_000 + 6_999)
        assertContentEquals(first, advertised())
        advance(1)

        assertContentEquals(next, advertised())
        assertEquals(1, advertiser.advertisementRequestCount)
        assertTrue(0L until 30_001 in h.random.ranges)
    }

    @Test
    fun keepsRotatingEveryWindow() {
        h.radio.start()
        advance(200_000)
        h.listener.beaconValue = next

        advance(300_000)

        assertContentEquals(next, advertised())
    }

    @Test
    @Config(shadows = [RecordingAdvertiser::class])
    fun logsAnAdvertThatFailsToStartAndRetriesAtTheWindowBoundary() {
        val recorder = Shadow.extract<RecordingAdvertiser>(h.adapter.bluetoothLeAdvertiser)
        h.radio.start()

        recorder.callbacks.single().onStartFailure(AdvertiseCallback.ADVERTISE_FAILED_TOO_MANY_ADVERTISERS)
        advance(230_000)

        assertTrue(ShadowLog.getLogsForTag("CairnRadio").any { it.msg == "advertising failed (2)" })
        assertEquals(2, recorder.callbacks.size)
    }

    @Test
    fun stopCancelsTheRotation() {
        h.radio.start()
        h.radio.stop()

        advance(200_000)

        assertEquals(0, advertiser.advertisementRequestCount)
    }
}
