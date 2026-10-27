package ch.trancee.cairn.android

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import ch.trancee.cairn.ble.BlePermissions

/** Runs the radio while visible (ADR 0023 §3) and hosts [CairnScreen]. */
class MainActivity : ComponentActivity(), ScreenActions {
    private val session get() = (application as CairnApplication).session

    private val permissions =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { session.resume() }

    private val bluetooth =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { session.resume() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { CairnTheme { CairnScreen(session.model, this) } }
    }

    override fun onStart() {
        super.onStart()
        session.resume()
    }

    override fun onStop() {
        super.onStop()
        // A rotation recreates the activity; keep the links up through it.
        if (!isChangingConfigurations) session.pause()
    }

    override fun allow() = permissions.launch(BlePermissions.required().toTypedArray())

    override fun openSettings() =
        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null)))

    // The Bluetooth gate shows only once the Nearby devices permissions are granted (Session.resume).
    @SuppressLint("MissingPermission")
    override fun enableBluetooth() = bluetooth.launch(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE))

    override fun send(contact: ULong, text: String) = session.send(contact, text)

    override fun read(contact: ULong) = session.read(contact)
}
