package ch.trancee.cairn.android

import android.content.Context
import android.os.Handler
import ch.trancee.cairn.ble.AndroidClock
import ch.trancee.cairn.ble.AndroidRadio
import ch.trancee.cairn.ble.BlePermissions
import ch.trancee.cairn.ble.HandlerTimers
import ch.trancee.cairn.ffi.GattRole
import ch.trancee.cairn.sdk.Engine
import ch.trancee.cairn.sdk.LinkDriver
import ch.trancee.cairn.sdk.RadioListener

/**
 * One core, its [LinkDriver] and the [AndroidRadio], all on [handler]'s thread (ADR 0023 §2).
 * It outlives activities; the radio runs only while the app is in the foreground.
 */
class Session(private val context: Context, handler: Handler, newEngine: () -> Engine) {
    val model = ChatModel()

    internal val radio = AndroidRadio(context, handler)

    private val driver: LinkDriver = LinkDriver(
        newEngine,
        radio,
        HandlerTimers(handler) { driver.timerFired(it) },
        AndroidClock,
        model::onNotice,
    )

    /** The driver, refreshing the debug panel's link stats after each event that changes them. */
    internal val radioListener: RadioListener = object : RadioListener by driver {
        override fun linkUp(role: GattRole, mtu: UShort, address: ByteArray): ULong =
            driver.linkUp(role, mtu, address).also { refresh() }

        override fun mtuChanged(link: ULong, mtu: UShort) {
            driver.mtuChanged(link, mtu)
            refresh()
        }

        override fun received(link: ULong, fragment: ByteArray) {
            driver.received(link, fragment)
            refresh()
        }

        override fun sent(link: ULong) {
            driver.sent(link)
            refresh()
        }

        override fun linkDown(link: ULong) {
            driver.linkDown(link)
            refresh()
        }
    }

    init {
        radio.listener = radioListener
        radio.availability = { model.radio = if (it) RadioState.RUNNING else RadioState.BLUETOOTH_OFF }
        driver.start()
    }

    /**
     * Starts the radio, or records what the user must grant or enable first. Once started, the
     * radio state follows Bluetooth turning off and on until [pause].
     */
    fun resume() {
        model.radio = when {
            BlePermissions.missing(context).isNotEmpty() -> RadioState.NEEDS_PERMISSION
            radio.start() -> RadioState.RUNNING
            else -> RadioState.BLUETOOTH_OFF
        }
    }

    /** Stops the radio, which closes every link. */
    fun pause() {
        radio.stop()
        model.radio = RadioState.STOPPED
    }

    fun send(contact: ULong, text: String) {
        model.send(contact, text) { driver.sendChat(contact, text) }
        refresh()
    }

    private fun refresh() {
        model.links = driver.links()
    }
}
