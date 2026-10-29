package ch.trancee.cairn.sdk

import ch.trancee.cairn.ffi.Action
import ch.trancee.cairn.ffi.Persisted
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse

class RowStoreTest {
    @Test
    fun otherActionsAreNotRows() {
        val rows = RowStore()

        rows.commit(listOf(Action.ChatSent(7uL, 1u)))

        val restored = rows.restore()
        assertEquals(RowStore().restore(), restored)
        assertFalse(restored.reset)
    }

    @Test
    fun wipeDeletesEveryRow() {
        val rows = RowStore()
        rows.commit(
            listOf(
                Action.PersistDevice(Persisted(byteArrayOf(1), 1u)),
                Action.PersistContact(7uL, Persisted(byteArrayOf(2), 1u)),
                Action.PutQueued(7uL, 1u, Persisted(byteArrayOf(3), 1u)),
                Action.PutCourier(0uL, Persisted(byteArrayOf(4), 1u)),
            ),
        )

        rows.wipe()

        assertEquals(RowStore().restore(), rows.restore())
    }
}
