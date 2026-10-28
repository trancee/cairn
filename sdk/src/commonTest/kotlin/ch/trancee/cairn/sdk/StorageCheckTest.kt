package ch.trancee.cairn.sdk

import ch.trancee.cairn.ffi.Action
import ch.trancee.cairn.ffi.Clock
import ch.trancee.cairn.ffi.Event
import kotlin.test.Test
import kotlin.test.assertEquals

private val CLOCK = Clock(monoMs = 1_000uL, unixS = 1_761_177_600uL)

/** Restores from [inner] but reports a wipe, as [SealedRowStore] does after an unreadable row. */
private class ResetRows(private val inner: Rows) : Rows by inner {
    override fun restore(): Restored = Restored(inner.restore().event, reset = true)
}

/** Restores nothing and drops every commit. */
private class LostRows : Rows {
    override fun commit(actions: List<Action>) = Unit

    override fun restore(): Restored = Restored(Event.Restore(null, emptyList(), emptyList(), emptyList()))
}

class StorageCheckTest {
    @Test
    fun emptyStorageStoresTheNewCoresDeviceRow() {
        val rows = RowStore()

        val status = checkStorage(rows, CLOCK)

        assertEquals("storage=new device=stored", status)
    }

    @Test
    fun aSecondCheckRestoresTheStoredDevice() {
        val rows = RowStore()
        checkStorage(rows, CLOCK)

        val status = checkStorage(rows, CLOCK)

        assertEquals("storage=restored device=stored", status)
    }

    @Test
    fun aWipedStoreIsReported() {
        val status = checkStorage(ResetRows(RowStore()), CLOCK)

        assertEquals("storage=reset device=stored", status)
    }

    @Test
    fun aDeviceRowThatDoesNotPersistIsReported() {
        val status = checkStorage(LostRows(), CLOCK)

        assertEquals("storage=new device=missing", status)
    }
}
