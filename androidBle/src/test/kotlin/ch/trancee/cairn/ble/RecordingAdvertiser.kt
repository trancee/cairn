package ch.trancee.cairn.ble

import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.annotation.RealObject
import org.robolectric.shadows.ShadowBluetoothLeAdvertiser
import org.robolectric.util.reflector.Direct
import org.robolectric.util.reflector.ForType
import org.robolectric.util.reflector.Reflector.reflector

/** Records the advertising mode of every start, which the stock shadow drops, then starts as usual. */
@Implements(BluetoothLeAdvertiser::class)
class RecordingAdvertiser : ShadowBluetoothLeAdvertiser() {
    val modes = mutableListOf<Int>()

    @RealObject
    private lateinit var real: BluetoothLeAdvertiser

    @Implementation
    public override fun startAdvertising(settings: AdvertiseSettings, data: AdvertiseData, callback: AdvertiseCallback) {
        modes += settings.mode
        reflector(Real::class.java, real).startAdvertising(settings, data, callback)
    }

    @ForType(BluetoothLeAdvertiser::class)
    private interface Real {
        @Direct
        fun startAdvertising(settings: AdvertiseSettings, data: AdvertiseData, callback: AdvertiseCallback)
    }
}
