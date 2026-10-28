package ch.trancee.cairn.sdk

import ch.trancee.cairn.ffi.Action
import ch.trancee.cairn.ffi.ContactRow
import ch.trancee.cairn.ffi.Event
import ch.trancee.cairn.ffi.Persisted
import ch.trancee.cairn.ffi.QueuedRow

/** [Rows] in memory, for tests. Not thread-safe; it lives on the driver's thread. */
class RowStore : Rows {
    private var device: Persisted? = null
    private val contacts = mutableMapOf<ULong, Persisted>()
    private val queued = mutableMapOf<Pair<ULong, UInt>, Persisted>()

    override fun commit(actions: List<Action>) = actions.forEach { action ->
        when (action) {
            is Action.PersistDevice -> device = action.state
            is Action.PersistContact -> contacts[action.contact] = action.state
            is Action.PutQueued -> queued[action.contact to action.msgno] = action.state
            is Action.DeleteQueued -> queued.remove(action.contact to action.msgno)
            else -> {}
        }
    }

    override fun restore() = Restored(
        Event.Restore(
            device,
            contacts.entries.sortedBy { it.key }.map { (contact, state) -> ContactRow(contact, state) },
            queued.entries
                .sortedWith(compareBy({ it.key.first }, { it.key.second }))
                .map { (key, state) -> QueuedRow(key.first, key.second, state) },
        ),
    )
}
