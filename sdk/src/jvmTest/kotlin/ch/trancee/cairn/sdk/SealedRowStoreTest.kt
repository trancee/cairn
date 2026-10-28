package ch.trancee.cairn.sdk

import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.jdbc.sqlite.JdbcSqliteDriver
import ch.trancee.cairn.ffi.Action
import ch.trancee.cairn.ffi.ContactRow
import ch.trancee.cairn.ffi.CourierRow
import ch.trancee.cairn.ffi.Event
import ch.trancee.cairn.ffi.Persisted
import ch.trancee.cairn.ffi.QueuedRow
import ch.trancee.cairn.sdk.db.RowDatabase
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** Prefixes the AAD so a row opens only under the AAD it was sealed with. */
private class FakeSealer : RowSealer {
    val aads = mutableListOf<List<Byte>>()
    var failAfter = Int.MAX_VALUE

    override fun seal(aad: ByteArray, plaintext: ByteArray): ByteArray {
        if (aads.size == failAfter) error("sealer unavailable")
        aads += aad.toList()
        return byteArrayOf(aad.size.toByte()) + aad + plaintext
    }

    override fun open(aad: ByteArray, sealed: ByteArray): ByteArray? {
        val prefix = sealed.copyOfRange(1, 1 + sealed[0].toInt())
        return if (prefix.contentEquals(aad)) sealed.copyOfRange(1 + aad.size, sealed.size) else null
    }
}

private fun row(byte: Int, version: UInt = 1u) = Persisted(byteArrayOf(byte.toByte()), version)

private fun key(state: Persisted?): List<Any>? = state?.let { listOf(it.blob.toList(), it.version) }

private fun key(event: Event.Restore): List<Any?> = listOf(
    key(event.device),
    event.contacts.map { listOf(it.contact, key(it.state)) },
    event.queued.map { listOf(it.contact, it.msgno, key(it.state)) },
    event.courier.map { listOf(it.slot, key(it.state)) },
)

private fun database(): SqlDriver = JdbcSqliteDriver(JdbcSqliteDriver.IN_MEMORY).also(RowDatabase.Schema::create)

private fun aad(kind: Int, contact: ULong, msgno: UInt, version: UInt): List<Byte> =
    ("cairn row v1".encodeToByteArray() + byteArrayOf(kind.toByte()) +
        ByteArray(8) { (contact shr (56 - 8 * it)).toByte() } +
        ByteArray(4) { (msgno shr (24 - 8 * it)).toByte() } +
        ByteArray(4) { (version shr (24 - 8 * it)).toByte() }).toList()

class SealedRowStoreTest {
    @Test
    fun committedRowsComeBackInKeyOrderFromANewStore() {
        val driver = database()
        val sealer = FakeSealer()
        SealedRowStore(driver, sealer).commit(
            listOf(
                Action.PersistDevice(row(1)),
                Action.PersistDevice(row(2, 3u)),
                Action.PersistContact(ULong.MAX_VALUE, row(3)),
                Action.PersistContact(7uL, row(4)),
                Action.ChatSent(7uL, 1u),
                Action.PutQueued(7uL, UInt.MAX_VALUE, row(5)),
                Action.PutQueued(7uL, 1u, row(6)),
                Action.PutQueued(7uL, 2u, row(7)),
                Action.DeleteQueued(7uL, 2u),
                Action.PutCourier(ULong.MAX_VALUE, row(8)),
                Action.PutCourier(3uL, row(9)),
                Action.PutCourier(4uL, row(10)),
                Action.PutCourier(3uL, row(11)),
                Action.DeleteCourier(4uL),
            ),
        )

        val restored = SealedRowStore(driver, sealer).restore()

        val expected = Event.Restore(
            row(2, 3u),
            listOf(ContactRow(7uL, row(4)), ContactRow(ULong.MAX_VALUE, row(3))),
            listOf(QueuedRow(7uL, 1u, row(6)), QueuedRow(7uL, UInt.MAX_VALUE, row(5))),
            listOf(CourierRow(3uL, row(11)), CourierRow(ULong.MAX_VALUE, row(8))),
        )
        assertEquals(key(expected), key(restored.event))
        assertFalse(restored.reset)
    }

    @Test
    fun eachRowIsSealedWithItsSlotAndVersionAsAad() {
        val sealer = FakeSealer()

        SealedRowStore(database(), sealer).commit(
            listOf(
                Action.PersistDevice(row(1, 2u)),
                Action.PersistContact(0x0102030405060708uL, row(2, 3u)),
                Action.PutQueued(9uL, 0x0a0b0c0du, row(3, 4u)),
                Action.PutCourier(0x1112131415161718uL, row(4, 5u)),
            ),
        )

        val expected = listOf(
            aad(0, 0uL, 0u, 2u),
            aad(1, 0x0102030405060708uL, 0u, 3u),
            aad(2, 9uL, 0x0a0b0c0du, 4u),
            aad(3, 0x1112131415161718uL, 0u, 5u),
        )
        assertEquals(expected, sealer.aads)
    }

    @Test
    fun aRowMovedToAnotherSlotWipesStorage() {
        val driver = database()
        val store = SealedRowStore(driver, FakeSealer())
        store.commit(listOf(Action.PersistContact(7uL, row(1)), Action.PersistContact(8uL, row(2))))
        driver.execute(null, "UPDATE contact SET ciphertext = (SELECT ciphertext FROM contact WHERE id = 7) WHERE id = 8", 0)

        val restored = store.restore()

        val empty = Event.Restore(null, emptyList(), emptyList(), emptyList())
        assertTrue(restored.reset)
        assertEquals(key(empty), key(restored.event))
        assertEquals(key(empty), key(store.restore().event))
        assertFalse(store.restore().reset)
    }

    @Test
    fun anUnreadableDeviceQueuedOrCourierRowWipesStorage() {
        val outcomes = listOf("device", "queued", "courier").map { table ->
            val driver = database()
            val store = SealedRowStore(driver, FakeSealer())
            store.commit(
                listOf(Action.PersistDevice(row(1)), Action.PutQueued(7uL, 1u, row(2)), Action.PutCourier(0uL, row(3))),
            )
            driver.execute(null, "UPDATE $table SET version = version + 1", 0)
            store.restore().reset to driver.executeQuery(
                null,
                "SELECT COUNT(*) FROM courier",
                { cursor -> cursor.next(); app.cash.sqldelight.db.QueryResult.Value(cursor.getLong(0)) },
                0,
            ).value
        }

        assertEquals(listOf(true to 0L, true to 0L, true to 0L), outcomes)
    }

    @Test
    fun aFailedSealCommitsNothingFromItsBatch() {
        val driver = database()
        val sealer = FakeSealer()
        val store = SealedRowStore(driver, sealer)
        store.commit(listOf(Action.PersistDevice(row(1))))
        sealer.failAfter = 2

        assertFailsWith<IllegalStateException> {
            store.commit(listOf(Action.PersistDevice(row(2)), Action.PersistContact(7uL, row(3))))
        }

        val expected = Event.Restore(row(1), emptyList(), emptyList(), emptyList())
        assertEquals(key(expected), key(store.restore().event))
    }
}
