package ch.trancee.cairn.android

import ch.trancee.cairn.ffi.Action
import ch.trancee.cairn.ffi.Event
import ch.trancee.cairn.ffi.GattRole
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class SessionTest {
    private val app = AppHarness.app

    @Test
    fun theSessionRestoresAFreshCoreOnce() {
        app.session
        app.session

        assertEquals(listOf<Event>(Event.Restore(null)), app.engine.events)
    }

    @Test
    fun resumeWithoutPermissionAsksForItAndStaysSilent() {
        AppHarness.bluetooth(on = true)

        app.session.resume()

        assertEquals(RadioState.NEEDS_PERMISSION, app.session.model.radio)
        assertFalse(AppHarness.scanning())
    }

    @Test
    fun resumeWithBluetoothOffAsksToTurnItOn() {
        AppHarness.grantPermissions()
        AppHarness.bluetooth(on = false)

        app.session.resume()

        assertEquals(RadioState.BLUETOOTH_OFF, app.session.model.radio)
    }

    @Test
    fun theRadioStateFollowsBluetoothTurningOffAndOn() {
        AppHarness.grantPermissions()
        AppHarness.bluetooth(on = true)
        app.session.resume()

        AppHarness.adapterState(android.bluetooth.BluetoothAdapter.STATE_OFF)
        assertEquals(RadioState.BLUETOOTH_OFF, app.session.model.radio)

        AppHarness.adapterState(android.bluetooth.BluetoothAdapter.STATE_ON)
        assertEquals(RadioState.RUNNING, app.session.model.radio)
    }

    @Test
    fun resumeStartsTheRadioAndPauseStopsIt() {
        AppHarness.grantPermissions()
        AppHarness.bluetooth(on = true)

        app.session.resume()
        assertEquals(RadioState.RUNNING, app.session.model.radio)
        assertTrue(AppHarness.scanning())

        app.session.pause()
        assertEquals(RadioState.STOPPED, app.session.model.radio)
        assertFalse(AppHarness.scanning())
    }

    @Test
    fun coreTimersFireIntoTheCore() {
        app.engine.respond = { if (it is Event.Restore) listOf(Action.SetTimer(7u, 0u)) else emptyList() }

        app.session
        AppHarness.idle()

        assertEquals(Event.TimerFired(7u), app.engine.events.last())
    }

    @Test
    fun sendGoesThroughTheCoreAndSettlesTheMessage() {
        app.engine.respond = { if (it is Event.SendChat) listOf(Action.ChatSent(it.contact, 1u)) else emptyList() }

        app.session.send(3u, "hi")

        assertEquals(Event.SendChat(3u, "hi"), app.engine.events.last())
        assertEquals(listOf(Message("hi", MessageStatus.Sent)), app.session.model.messages(3u))
    }

    @Test
    fun theModelsLinksFollowEveryRadioEvent() {
        val radio = app.session.radioListener
        val link = radio.linkUp(GattRole.CENTRAL, 23u, byteArrayOf(1))
        assertEquals(listOf(23.toUShort()), app.session.model.links.map { it.mtu })

        radio.mtuChanged(link, 517u)
        assertEquals(listOf(517.toUShort()), app.session.model.links.map { it.mtu })

        radio.received(link, ByteArray(5))
        assertEquals(listOf(5L), app.session.model.links.map { it.bytesIn })

        app.engine.respond = { if (it is Event.SendChat) listOf(Action.Send(link, ByteArray(9))) else emptyList() }
        app.session.send(1u, "hi")
        assertEquals(listOf(9L), app.session.model.links.map { it.bytesOut })

        radio.sent(link)
        radio.linkDown(link)
        assertEquals(emptyList(), app.session.model.links)
    }

    @Test
    fun beaconsPassStraightThroughToTheDriver() {
        val radio = app.session.radioListener
        val link = radio.linkUp(GattRole.CENTRAL, 23u, byteArrayOf(1))

        radio.beaconRead(link, byteArrayOf(4))

        val read = app.engine.events.last() as Event.BeaconRead
        assertEquals(link, read.link)
        assertContentEquals(byteArrayOf(4), read.beacon)
        assertEquals(8, radio.beacon().size)
    }

    @Test
    fun coreNoticesReachTheModel() {
        app.engine.contacts = listOf(AppHarness.contact(1u))
        app.engine.respond = { if (it is Event.LinkUp) listOf(Action.ContactAdded(1u)) else emptyList() }

        app.session.radioListener.linkUp(GattRole.CENTRAL, 517u, byteArrayOf(1))

        assertEquals(app.engine.contacts, app.session.model.contacts)
    }
}
