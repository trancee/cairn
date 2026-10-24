package ch.trancee.cairn.ble

import android.os.Handler
import android.os.SystemClock
import ch.trancee.cairn.sdk.Timers

/** [Timers] on the driver's [Handler], against the [AndroidClock] monotonic clock. */
class HandlerTimers(private val handler: Handler, private val fired: (ULong) -> Unit) : Timers {
    private val pending = HashMap<ULong, Runnable>()

    override fun schedule(timer: ULong, atMonoMs: ULong) {
        cancel(timer)
        val task = Runnable {
            pending.remove(timer)
            fired(timer)
        }
        pending[timer] = task
        handler.postDelayed(task, (atMonoMs.toLong() - SystemClock.elapsedRealtime()).coerceAtLeast(0))
    }

    override fun cancel(timer: ULong) {
        pending.remove(timer)?.let(handler::removeCallbacks)
    }
}
