package ch.trancee.cairn.sdk

import app.cash.sqldelight.db.SqlDriver
import ch.trancee.cairn.ffi.Action
import ch.trancee.cairn.ffi.ContactRow
import ch.trancee.cairn.ffi.CourierRow
import ch.trancee.cairn.ffi.Event
import ch.trancee.cairn.ffi.Persisted
import ch.trancee.cairn.ffi.QueuedRow
import ch.trancee.cairn.sdk.db.RowDatabase

private const val DEVICE = 0
private const val CONTACT = 1
private const val QUEUED = 2
private const val COURIER = 3
private val AAD_LABEL = "cairn row v1".encodeToByteArray()

/**
 * `"cairn row v1" ‖ kind ‖ u64be(contact) ‖ u32be(msgno) ‖ u32be(version)` (ADR 0035 §2); a
 * courier row puts its slot in the contact field (ADR 0036 §3).
 */
internal fun rowAad(kind: Int, contact: ULong, msgno: UInt, version: UInt): ByteArray =
    AAD_LABEL + byteArrayOf(kind.toByte()) +
        ByteArray(8) { (contact shr (56 - 8 * it)).toByte() } +
        ByteArray(4) { (msgno shr (24 - 8 * it)).toByte() } +
        ByteArray(4) { (version shr (24 - 8 * it)).toByte() }

/**
 * [Rows] in SQLite, each row sealed by [sealer] and bound to its slot (ADR 0035). [driver] must
 * hold a database created from [RowDatabase.Schema]. Not thread-safe.
 */
class SealedRowStore(driver: SqlDriver, private val sealer: RowSealer) : Rows {
    private val queries = RowDatabase(driver).rowsQueries

    override fun commit(actions: List<Action>) = queries.transaction {
        actions.forEach { action ->
            when (action) {
                is Action.PersistDevice ->
                    queries.putDevice(action.state.version.toLong(), seal(DEVICE, 0uL, 0u, action.state))
                is Action.PersistContact -> queries.putContact(
                    action.contact.toLong(),
                    action.state.version.toLong(),
                    seal(CONTACT, action.contact, 0u, action.state),
                )
                is Action.DeleteContact -> queries.deleteContact(action.contact.toLong())
                is Action.PutQueued -> queries.putQueued(
                    action.contact.toLong(),
                    action.msgno.toLong(),
                    action.state.version.toLong(),
                    seal(QUEUED, action.contact, action.msgno, action.state),
                )
                is Action.DeleteQueued -> queries.deleteQueued(action.contact.toLong(), action.msgno.toLong())
                is Action.PutCourier -> queries.putCourier(
                    action.slot.toLong(),
                    action.state.version.toLong(),
                    seal(COURIER, action.slot, 0u, action.state),
                )
                is Action.DeleteCourier -> queries.deleteCourier(action.slot.toLong())
                else -> {}
            }
        }
    }

    /** Every row; if any fails to open, wipes all of them (ADR 0035 §5). */
    override fun restore(): Restored {
        read()?.let { return Restored(it) }
        wipe()
        return Restored(Event.Restore(null, emptyList(), emptyList(), emptyList()), reset = true)
    }

    override fun wipe() = queries.transaction {
        queries.wipeDevice()
        queries.wipeContacts()
        queries.wipeQueued()
        queries.wipeCourier()
    }

    private fun read(): Event.Restore? {
        val device = queries.device().executeAsOneOrNull()?.let { row ->
            open(DEVICE, 0uL, 0u, row.version, row.ciphertext) ?: return null
        }
        val contacts = queries.contacts().executeAsList().map { row ->
            val contact = row.id.toULong()
            ContactRow(contact, open(CONTACT, contact, 0u, row.version, row.ciphertext) ?: return null)
        }
        val queued = queries.queuedRows().executeAsList().map { row ->
            val contact = row.contact.toULong()
            val msgno = row.msgno.toUInt()
            QueuedRow(contact, msgno, open(QUEUED, contact, msgno, row.version, row.ciphertext) ?: return null)
        }
        val courier = queries.courierRows().executeAsList().map { row ->
            val slot = row.slot.toULong()
            CourierRow(slot, open(COURIER, slot, 0u, row.version, row.ciphertext) ?: return null)
        }
        return Event.Restore(
            device,
            contacts.sortedBy { it.contact },
            queued.sortedWith(compareBy({ it.contact }, { it.msgno })),
            courier.sortedBy { it.slot },
        )
    }

    private fun seal(kind: Int, contact: ULong, msgno: UInt, state: Persisted): ByteArray =
        sealer.seal(rowAad(kind, contact, msgno, state.version), state.blob)

    private fun open(kind: Int, contact: ULong, msgno: UInt, version: Long, sealed: ByteArray): Persisted? {
        val state = version.toUInt()
        return sealer.open(rowAad(kind, contact, msgno, state), sealed)?.let { Persisted(it, state) }
    }
}
