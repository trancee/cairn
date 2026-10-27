package ch.trancee.cairn.sdk

import ch.trancee.cairn.ffi.Action
import ch.trancee.cairn.ffi.ContactRow
import ch.trancee.cairn.ffi.Event
import ch.trancee.cairn.ffi.Persisted
import ch.trancee.cairn.ffi.QueuedRow

/**
 * The rows the core asked to keep (ADR 0034 §1), in memory only until sealed storage lands
 * (ADR 0006). Not thread-safe; it lives on the driver's thread.
 */
class RowStore {
    private var device: Persisted? = null
    private val contacts = mutableMapOf<ULong, Persisted>()
    private val queued = mutableMapOf<Pair<ULong, UInt>, Persisted>()

    /** Applies [action] if it is a row action; returns whether it was. */
    fun apply(action: Action): Boolean {
        when (action) {
            is Action.PersistDevice -> device = action.state
            is Action.PersistContact -> contacts[action.contact] = action.state
            is Action.PutQueued -> queued[action.contact to action.msgno] = action.state
            is Action.DeleteQueued -> queued.remove(action.contact to action.msgno)
            else -> return false
        }
        return true
    }

    /** The event that hands every row back to a new core, in key order. */
    fun restore(): Event.Restore = Event.Restore(
        device,
        contacts.entries.sortedBy { it.key }.map { (contact, state) -> ContactRow(contact, state) },
        queued.entries
            .sortedWith(compareBy({ it.key.first }, { it.key.second }))
            .map { (key, state) -> QueuedRow(key.first, key.second, state) },
    )
}
