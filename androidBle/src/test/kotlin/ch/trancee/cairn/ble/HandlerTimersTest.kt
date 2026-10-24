package ch.trancee.cairn.ble

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import java.time.Duration
import kotlin.test.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

@RunWith(RobolectricTestRunner::class)
class HandlerTimersTest {
    private val fired = mutableListOf<ULong>()
    private val timers = HandlerTimers(Handler(Looper.getMainLooper())) { fired += it }
    private val looper = shadowOf(Looper.getMainLooper())

    private fun inMs(ms: Long): ULong = (SystemClock.elapsedRealtime() + ms).toULong()

    @Test
    fun aTimerFiresAtItsMonotonicDeadline() {
        timers.schedule(1u, inMs(500))

        looper.idleFor(Duration.ofMillis(499))
        val early = fired.toList()
        looper.idleFor(Duration.ofMillis(1))

        assertEquals(emptyList(), early)
        assertEquals(listOf(1uL), fired)
    }

    @Test
    fun aPastDeadlineFiresImmediately() {
        looper.idleFor(Duration.ofSeconds(1))

        timers.schedule(2u, 1u)
        looper.idle()

        assertEquals(listOf(2uL), fired)
    }

    @Test
    fun aCancelledTimerNeverFires() {
        timers.schedule(3u, inMs(100))

        timers.cancel(3u)
        timers.cancel(4u)
        looper.idleFor(Duration.ofSeconds(1))

        assertEquals(emptyList(), fired)
    }

    @Test
    fun reschedulingATimerReplacesItsDeadline() {
        timers.schedule(5u, inMs(100))

        timers.schedule(5u, inMs(300))
        looper.idleFor(Duration.ofMillis(200))
        val early = fired.toList()
        looper.idleFor(Duration.ofMillis(100))

        assertEquals(emptyList(), early)
        assertEquals(listOf(5uL), fired)
    }

    @Test
    fun aFiredTimerCanBeCancelledHarmlessly() {
        timers.schedule(6u, inMs(10))
        looper.idleFor(Duration.ofMillis(10))

        timers.cancel(6u)
        timers.schedule(6u, inMs(10))
        looper.idleFor(Duration.ofMillis(10))

        assertEquals(listOf(6uL, 6uL), fired)
    }
}
