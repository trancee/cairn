package ch.trancee.cairn.sdk

import ch.trancee.cairn.ffi.Action
import ch.trancee.cairn.ffi.Persisted
import kotlin.test.Test
import kotlin.test.assertEquals

class TimedRowsTest {
    private val row = Persisted(byteArrayOf(1), 1u)

    @Test
    fun aCommitWithRowsReportsTheRowCountAndItsDuration() {
        val ticks = ArrayDeque(listOf(1_000L, 4_500L))
        val reports = mutableListOf<Pair<Int, Long>>()
        val store = RowStore()
        val rows = TimedRows(store, { ticks.removeFirst() }) { count, nanos -> reports += count to nanos }

        rows.commit(listOf(Action.PersistDevice(row), Action.ChatSent(7uL, 1u), Action.PutQueued(7uL, 1u, row)))

        assertEquals(listOf(2 to 3_500L), reports)
        assertEquals(store.restore(), rows.restore())
    }

    @Test
    fun aCommitWithoutRowsIsNotReported() {
        val reports = mutableListOf<Pair<Int, Long>>()
        val rows = TimedRows(RowStore(), { 0L }) { count, nanos -> reports += count to nanos }

        rows.commit(listOf(Action.ChatSent(7uL, 1u)))

        assertEquals(emptyList(), reports)
    }

    @Test
    fun deletesContactsAndCourierRowsCountAsRows() {
        val reports = mutableListOf<Int>()
        val rows = TimedRows(RowStore(), { 0L }) { count, _ -> reports += count }

        rows.commit(
            listOf(
                Action.PersistContact(7uL, row),
                Action.DeleteQueued(7uL, 1u),
                Action.PutCourier(1uL, row),
                Action.DeleteCourier(2uL),
            ),
        )

        assertEquals(listOf(4), reports)
    }
}
