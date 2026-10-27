package ch.trancee.cairn.sdk

import ch.trancee.cairn.ffi.Action
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse

class RowStoreTest {
    @Test
    fun otherActionsAreNotRows() {
        val rows = RowStore()

        val applied = rows.apply(Action.ChatSent(7uL, 1u))

        assertFalse(applied)
        assertEquals(RowStore().restore(), rows.restore())
    }
}
