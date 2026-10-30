package ch.trancee.cairn.ble

import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanResult
import android.os.Looper
import java.time.Duration
import kotlin.test.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.shadows.ShadowLog

/** Spec §10.4: when the central dials an address, and how it retries a dial that fails before link-up. */
@RunWith(RobolectricTestRunner::class)
class DialPolicyTest {
    private companion object {
        const val GATT_CONN_TIMEOUT = 0x08
    }

    // Drops the advert rotation's draw, so the ranges below are the dial schedule only.
    private val h = RadioHarness().also {
        it.radio.start()
        it.random.ranges.clear()
    }
    private val address = "00:11:22:33:44:01"

    private fun sight() {
        h.scanCallback().onScanResult(0, ScanResult(h.device(address), RadioHarness.advert(RadioHarness.PEER_BEACON), -40, 0))
        h.idle()
    }

    private fun dials(): List<BluetoothGatt> = shadowOf(h.device(address)).bluetoothGatts

    private fun advance(ms: Long) = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(ms))

    private fun fail(gatt: BluetoothGatt = dials().last()) {
        h.callback(gatt).onConnectionStateChange(gatt, 133, BluetoothProfile.STATE_DISCONNECTED)
        h.idle()
    }

    private fun link(): BluetoothGatt {
        val gatt = dials().last()
        val service = RadioHarness.peerService()
        h.shadow(gatt).addDiscoverableService(service)
        h.shadow(gatt).allowCharacteristicNotification(service.getCharacteristic(GattProfile.TX))
        h.connect(gatt)
        return gatt
    }

    @Test
    fun firstDialWaitsARandomDelayOfUpToThreeSeconds() {
        h.random.pick = { _, until -> until - 1 }
        sight()
        advance(2_999)
        sight()
        val early = dials().size

        advance(1)
        sight()

        assertEquals(0, early)
        assertEquals(1, dials().size)
        assertEquals(listOf(0L..3_000L), h.random.ranges)
    }

    @Test
    fun failedDialRetriesAfterOneToFiveThenFiveToFifteenSeconds() {
        h.random.pick = { _, until -> until - 1 }
        sight()
        advance(3_000)
        sight()
        fail()
        advance(4_999)
        sight()
        val beforeFirstRetry = dials().size
        advance(1)
        sight()
        fail()
        advance(14_999)
        sight()
        val beforeSecondRetry = dials().size

        advance(1)
        sight()

        assertEquals(listOf(1, 2, 3), listOf(beforeFirstRetry, beforeSecondRetry, dials().size))
        assertEquals(listOf(0L..3_000L, 1_000L..5_000L, 5_000L..15_000L), h.random.ranges)
    }

    @Test
    fun thirdFailedDialWaitsTwoMinutes() {
        sight()
        fail()
        advance(1_000)
        sight()
        fail()
        advance(5_000)
        sight()
        fail()
        advance(119_999)
        sight()
        val early = dials().size

        advance(1)
        sight()
        fail()

        assertEquals(3, early)
        assertEquals(4, dials().size)
        assertEquals(1_000L..5_000L, h.random.ranges.last())
    }

    @Test
    fun linkedAddressIsDialledAgainOnlyTwoMinutesAfterTheDialThatLinked() {
        sight()
        fail()
        advance(1_000)
        sight()
        val linked = link()
        h.callback(linked).onConnectionStateChange(linked, BluetoothGatt.GATT_SUCCESS, BluetoothProfile.STATE_DISCONNECTED)
        h.idle()
        advance(119_999)
        sight()
        val early = dials().size

        advance(1)
        sight()
        fail()

        assertEquals(2, early)
        assertEquals(3, dials().size)
        assertEquals(1_000L..5_000L, h.random.ranges.last())
    }

    private fun timeOut(gatt: BluetoothGatt) {
        h.callback(gatt).onConnectionStateChange(gatt, GATT_CONN_TIMEOUT, BluetoothProfile.STATE_DISCONNECTED)
        h.idle()
    }

    /** Dials once the address may be dialled, links, keeps the link up for [upMs], then times it out. */
    private fun linkThenTimeOut(upMs: Long) {
        sight()
        timeOut(link().also { advance(upMs) })
    }

    @Test
    fun linkLostToASupervisionTimeoutIsRedialledAfterOneToFiveSeconds() {
        h.random.pick = { _, until -> until - 1 }
        sight()
        advance(3_000)
        linkThenTimeOut(upMs = 0)
        advance(4_999)
        sight()
        val early = dials().size

        advance(1)
        sight()

        assertEquals(listOf(1, 2), listOf(early, dials().size))
        assertEquals(1_000L..5_000L, h.random.ranges.last())
    }

    @Test
    fun repeatedTimeoutsWithinTwoMinutesOfLinkUpWaitFiveToFifteenSecondsThenTwoMinutes() {
        linkThenTimeOut(upMs = 0)
        advance(1_000)
        linkThenTimeOut(upMs = 119_999)
        advance(5_000)
        linkThenTimeOut(upMs = 0)
        advance(119_999)
        sight()
        val early = dials().size

        advance(1)
        sight()

        assertEquals(listOf(3, 4), listOf(early, dials().size))
        // The advert rotation draws 0..30 s once the beacon window turns.
        assertEquals(listOf(1_000L..5_000L, 5_000L..15_000L), h.random.ranges.subList(1, 3))
    }

    @Test
    fun timeoutOfALinkUpForTwoMinutesStartsTheLadderAgain() {
        linkThenTimeOut(upMs = 0)
        advance(1_000)
        linkThenTimeOut(upMs = 120_000)
        advance(1_000)

        sight()

        assertEquals(3, dials().size)
        assertEquals(listOf(1_000L..5_000L, 1_000L..5_000L), h.random.ranges.drop(1))
    }

    @Test
    fun timedOutLinkIsLoggedWithTheNextDelay() {
        linkThenTimeOut(upMs = 0)

        assertEquals(
            "dial 44:01 timed out after link-up; retry in 1000 ms",
            ShadowLog.getLogsForTag("CairnRadio").single { "after link-up" in it.msg }.msg,
        )
    }

    @Test
    fun failedDialIsLoggedWithStageStatusAndNextDelay() {
        sight()
        advance(250)

        fail()

        assertEquals(
            "dial 44:01 failed CONNECTING status 0x85 after 250 ms; retry in 1000 ms",
            ShadowLog.getLogsForTag("CairnRadio").single { " failed " in it.msg }.msg,
        )
    }
}
