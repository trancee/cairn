package ch.trancee.cairn.sdk

import ch.trancee.cairn.ffi.Action
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
}
