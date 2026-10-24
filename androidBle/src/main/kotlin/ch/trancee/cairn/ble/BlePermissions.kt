package ch.trancee.cairn.ble

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build

/** The runtime permissions the radio needs (ADR 0023 §3); the manifest declares the install-time ones. */
object BlePermissions {
    fun required(): List<String> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        listOf(
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.BLUETOOTH_ADVERTISE,
        )
    } else {
        listOf(Manifest.permission.ACCESS_FINE_LOCATION)
    }

    fun missing(context: Context): List<String> =
        required().filter { context.checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
}
