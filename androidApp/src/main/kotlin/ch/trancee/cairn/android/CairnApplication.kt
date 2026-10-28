package ch.trancee.cairn.android

import android.app.Application
import android.os.Handler
import android.os.SystemClock
import android.util.Log
import app.cash.sqldelight.driver.android.AndroidSqliteDriver
import ch.trancee.cairn.sdk.CoreEngine
import ch.trancee.cairn.sdk.Engine
import ch.trancee.cairn.sdk.Rows
import ch.trancee.cairn.sdk.SealedRowStore
import ch.trancee.cairn.sdk.TimedRows
import ch.trancee.cairn.sdk.db.RowDatabase

open class CairnApplication : Application() {
    /** Host tests swap in a fake before [session] is first read; apps use the Rust core. */
    var engineFactory: () -> Engine = ::CoreEngine

    val session: Session by lazy { Session(this, Handler(mainLooper), openRows(), engineFactory) }

    /**
     * The sealed row database in app-private storage, excluded from backups (ADR 0006, ADR 0035).
     * Each commit logs its latency for the device demonstration.
     */
    internal fun openRows(): Rows = TimedRows(
        SealedRowStore(AndroidSqliteDriver(RowDatabase.Schema, this, "cairn.db"), KeystoreSealer()),
        SystemClock::elapsedRealtimeNanos,
    ) { rows, nanos -> Log.i(ROWS_TAG, "commit rows=$rows us=${nanos / 1_000}") }
}

private const val ROWS_TAG = "CairnRows"
