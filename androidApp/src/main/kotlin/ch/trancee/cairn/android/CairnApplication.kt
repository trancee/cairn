package ch.trancee.cairn.android

import android.app.Application
import android.os.Handler
import ch.trancee.cairn.sdk.CoreEngine
import ch.trancee.cairn.sdk.Engine

open class CairnApplication : Application() {
    /** Host tests swap in a fake before [session] is first read; apps use the Rust core. */
    var engineFactory: () -> Engine = ::CoreEngine

    val session: Session by lazy { Session(this, Handler(mainLooper), engineFactory) }
}
