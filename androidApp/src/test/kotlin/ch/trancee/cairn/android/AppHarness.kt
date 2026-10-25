package ch.trancee.cairn.android

import android.Manifest
import android.app.Application
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import ch.trancee.cairn.ffi.Action
import ch.trancee.cairn.ffi.Clock
import ch.trancee.cairn.ffi.ContactInfo
import ch.trancee.cairn.ffi.Event
import ch.trancee.cairn.ffi.Verification
import ch.trancee.cairn.sdk.Engine
import org.robolectric.Shadows.shadowOf
import org.robolectric.shadows.ShadowLooper

/** An [Engine] that records events and answers them from [respond]; the Rust core never loads. */
class FakeEngine(var respond: (Event) -> List<Action> = { emptyList() }) : Engine {
    val events = mutableListOf<Event>()
    var contacts = listOf<ContactInfo>()

    override fun handle(clock: Clock, event: Event): List<Action> {
        events += event
        return respond(event)
    }

    override fun contacts(): List<ContactInfo> = contacts

    override fun beacon(unixS: ULong): ByteArray = ByteArray(8)

    override fun close() = Unit
}

/** The Robolectric application: [CairnApplication] on a [FakeEngine]. */
class TestCairnApplication : CairnApplication() {
    val engine = FakeEngine()

    init {
        engineFactory = { engine }
    }
}

object AppHarness {
    val app: TestCairnApplication get() = ApplicationProvider.getApplicationContext()

    val adapter: BluetoothAdapter
        get() = app.getSystemService(BluetoothManager::class.java).adapter

    val nearbyPermissions = arrayOf(
        Manifest.permission.BLUETOOTH_SCAN,
        Manifest.permission.BLUETOOTH_CONNECT,
        Manifest.permission.BLUETOOTH_ADVERTISE,
        Manifest.permission.ACCESS_FINE_LOCATION,
    )

    fun grantPermissions() = shadowOf(app as Application).grantPermissions(*nearbyPermissions)

    fun bluetooth(on: Boolean) {
        shadowOf(adapter).setEnabled(on)
    }

    fun scanning(): Boolean = shadowOf(adapter.bluetoothLeScanner).scanCallbacks.isNotEmpty()

    /** Broadcasts an adapter state change, as the system does when Bluetooth turns off or on. */
    fun adapterState(state: Int) {
        app.sendBroadcast(
            android.content.Intent(BluetoothAdapter.ACTION_STATE_CHANGED).putExtra(BluetoothAdapter.EXTRA_STATE, state),
        )
        idle()
    }

    fun idle() = ShadowLooper.idleMainLooper()

    fun contact(id: ULong, name: String = "", verification: Verification = Verification.UNVERIFIED) =
        ContactInfo(id, name, verification)

    fun string(id: Int, vararg args: Any): String = (app as Context).getString(id, *args)
}
