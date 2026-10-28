package ch.trancee.cairn.sdk

import ch.trancee.cairn.ffi.Action

/**
 * [rows], reporting how many row actions each commit stored and how long it took, from
 * [nanos] readings. Commits without row actions are not reported. The device demonstration
 * uses it to measure commit latency (ADR 0035).
 */
class TimedRows(
    private val rows: Rows,
    private val nanos: () -> Long,
    private val report: (rows: Int, nanos: Long) -> Unit,
) : Rows by rows {
    override fun commit(actions: List<Action>) {
        val count = actions.count { it.isRow() }
        val start = nanos()
        rows.commit(actions)
        if (count > 0) report(count, nanos() - start)
    }
}

private fun Action.isRow() =
    this is Action.PersistDevice || this is Action.PersistContact || this is Action.PutQueued ||
        this is Action.DeleteQueued || this is Action.PutCourier || this is Action.DeleteCourier
