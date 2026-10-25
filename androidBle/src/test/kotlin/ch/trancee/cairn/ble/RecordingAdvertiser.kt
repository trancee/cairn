package ch.trancee.cairn.ble

import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.AdvertisingSetCallback
import android.bluetooth.le.AdvertisingSetParameters
import android.bluetooth.le.BluetoothLeAdvertiser
import android.bluetooth.le.PeriodicAdvertisingParameters
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.annotation.RealObject
import org.robolectric.shadows.ShadowBluetoothLeAdvertiser
import org.robolectric.util.reflector.Direct
import org.robolectric.util.reflector.ForType
import org.robolectric.util.reflector.Reflector.reflector

/**
 * Records the advertising mode of every legacy start, which the stock shadow drops, then starts as
 * usual; and records advertising sets, which the stock shadow neither counts nor stops.
 */
@Implements(BluetoothLeAdvertiser::class)
class RecordingAdvertiser : ShadowBluetoothLeAdvertiser() {
    val modes = mutableListOf<Int>()

    /** Every advertising set started, in order. */
    val sets = mutableListOf<Pair<AdvertisingSetParameters, AdvertisingSetCallback>>()

    /** The advertising sets started and not stopped since. */
    val activeSets = mutableListOf<AdvertisingSetCallback>()

    @RealObject
    private lateinit var real: BluetoothLeAdvertiser

    @Implementation
    public override fun startAdvertising(settings: AdvertiseSettings, data: AdvertiseData, callback: AdvertiseCallback) {
        modes += settings.mode
        reflector(Real::class.java, real).startAdvertising(settings, data, callback)
    }

    @Implementation
    public override fun startAdvertisingSet(
        parameters: AdvertisingSetParameters,
        advertiseData: AdvertiseData?,
        scanResponse: AdvertiseData?,
        periodicParameters: PeriodicAdvertisingParameters?,
        periodicData: AdvertiseData?,
        callback: AdvertisingSetCallback,
    ) {
        // As Android does: a callback is released only by stopping its set, or by a failed start.
        require(callback !in activeSets) { "callback instance already associated with advertising" }
        sets += parameters to callback
        activeSets += callback
        super.startAdvertisingSet(parameters, advertiseData, scanResponse, periodicParameters, periodicData, callback)
    }

    @Implementation
    fun stopAdvertisingSet(callback: AdvertisingSetCallback) {
        activeSets -= callback
    }

    @ForType(BluetoothLeAdvertiser::class)
    private interface Real {
        @Direct
        fun startAdvertising(settings: AdvertiseSettings, data: AdvertiseData, callback: AdvertiseCallback)
    }
}
