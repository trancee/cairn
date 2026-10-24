package ch.trancee.cairn.ble

import android.os.Looper
import android.os.SystemClock
import java.time.Duration
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

@RunWith(RobolectricTestRunner::class)
class AndroidClockTest {
    @Test
    fun monoIsElapsedRealtimeAndUnixIsWallSeconds() {
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(1234))
        val before = System.currentTimeMillis() / 1000

        val clock = AndroidClock.now()

        assertEquals(SystemClock.elapsedRealtime().toULong(), clock.monoMs)
        assertTrue(clock.unixS.toLong() in before..System.currentTimeMillis() / 1000)
    }
}
