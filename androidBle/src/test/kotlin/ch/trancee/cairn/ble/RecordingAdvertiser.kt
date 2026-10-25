package ch.trancee.cairn.ble

import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.shadows.ShadowBluetoothLeAdvertiser

/** Records the advertising mode of every start, which the stock shadow drops. */
@Implements(BluetoothLeAdvertiser::class)
class RecordingAdvertiser : ShadowBluetoothLeAdvertiser() {
    val modes = mutableListOf<Int>()

    @Implementation
    public override fun startAdvertising(settings: AdvertiseSettings, data: AdvertiseData, callback: AdvertiseCallback) {
        modes += settings.mode
        super.startAdvertising(settings, data, callback)
    }
}
