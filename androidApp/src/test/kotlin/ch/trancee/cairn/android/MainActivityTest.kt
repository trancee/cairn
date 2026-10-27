package ch.trancee.cairn.android

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothGattServer
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasScrollToNodeAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.lifecycle.Lifecycle
import androidx.test.core.app.ActivityScenario
import ch.trancee.cairn.ble.BlePermissions
import ch.trancee.cairn.ffi.Action
import ch.trancee.cairn.ffi.ChatRejection
import ch.trancee.cairn.ffi.Event
import ch.trancee.cairn.ffi.GattRole
import ch.trancee.cairn.ffi.Verification
import ch.trancee.cairn.sdk.FaultKind
import ch.trancee.cairn.sdk.Notice
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertSame
import kotlin.test.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.util.ReflectionHelpers

@RunWith(RobolectricTestRunner::class)
class MainActivityTest {
    @get:Rule
    val compose = createEmptyComposeRule()

    private val app = AppHarness.app
    private val model get() = app.session.model

    private fun s(id: Int, vararg args: Any) = AppHarness.string(id, *args)

    private fun launch(): ActivityScenario<MainActivity> = ActivityScenario.launch(MainActivity::class.java)

    private fun running(): ActivityScenario<MainActivity> {
        AppHarness.grantPermissions()
        AppHarness.bluetooth(on = true)
        return launch()
    }

    /** Denies in the dialog; from API 37 the platform already delivered a result, so this repeat is ignored. */
    private fun ActivityScenario<MainActivity>.denyPermissions() = onActivity { activity ->
        val request = shadowOf(activity).lastRequestedPermission
        assertEquals(BlePermissions.required(), request.requestedPermissions.toList())
        @Suppress("DEPRECATION")
        activity.onRequestPermissionsResult(
            request.requestCode,
            request.requestedPermissions,
            IntArray(request.requestedPermissions.size) { PackageManager.PERMISSION_DENIED },
        )
    }

    /** The radio's GATT server; a stop and restart would replace it. */
    private fun openServer(): BluetoothGattServer? = ReflectionHelpers.getField(app.session.radio, "server")

    private fun showContacts() =
        model.onNotice(Notice.ContactsChanged(listOf(AppHarness.contact(1u), AppHarness.contact(2u, "Ada"))))

    @Test
    fun missingPermissionsShowTheNearbyDevicesGate() {
        launch().use {
            compose.onNodeWithText(s(R.string.permission_body)).assertIsDisplayed()
            assertFalse(AppHarness.scanning())
        }
    }

    @Test
    fun grantingTheNearbyPermissionsStartsTheRadio() {
        AppHarness.bluetooth(on = true)
        launch().use {
            // Granted meanwhile (e.g. in Settings): the request answers without a dialog.
            AppHarness.grantPermissions()
            compose.onNodeWithText(s(R.string.permission_allow)).performClick()

            compose.onNodeWithText(s(R.string.contacts_empty)).assertIsDisplayed()
            assertTrue(AppHarness.scanning())
        }
    }

    @Test
    fun denyingTheNearbyPermissionsKeepsTheGate() {
        AppHarness.bluetooth(on = true)
        launch().use { scenario ->
            compose.onNodeWithText(s(R.string.permission_allow)).performClick()
            scenario.denyPermissions()

            compose.onNodeWithText(s(R.string.permission_body)).assertIsDisplayed()
            assertFalse(AppHarness.scanning())
        }
    }

    @Test
    fun appSettingsOpensThisAppsDetails() {
        launch().use { scenario ->
            compose.onNodeWithText(s(R.string.permission_settings)).performClick()

            scenario.onActivity { activity ->
                val intent = shadowOf(activity).nextStartedActivity
                assertEquals(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, intent.action)
                assertEquals(Uri.fromParts("package", app.packageName, null), intent.data)
            }
        }
    }

    @Test
    fun bluetoothOffAsksTheSystemToTurnItOnThenStarts() {
        AppHarness.grantPermissions()
        AppHarness.bluetooth(on = false)
        launch().use { scenario ->
            compose.onNodeWithText(s(R.string.bluetooth_body)).assertIsDisplayed()
            compose.onNodeWithText(s(R.string.bluetooth_enable)).performClick()

            scenario.onActivity { activity ->
                val started = shadowOf(activity).nextStartedActivityForResult
                assertEquals(BluetoothAdapter.ACTION_REQUEST_ENABLE, started.intent.action)
                AppHarness.bluetooth(on = true)
                shadowOf(activity).receiveResult(started.intent, Activity.RESULT_OK, null)
            }

            compose.onNodeWithText(s(R.string.contacts_empty)).assertIsDisplayed()
            assertTrue(AppHarness.scanning())
        }
    }

    @Test
    fun contactsShowTheirLabelAndVerification() {
        running().use {
            model.onNotice(
                Notice.ContactsChanged(
                    listOf(
                        AppHarness.contact(1u),
                        AppHarness.contact(2u, "Ada", Verification.VERIFIED),
                        AppHarness.contact(3u, "Eve", Verification.COMPROMISED),
                    ),
                ),
            )

            compose.onNodeWithText(s(R.string.contact_label, 1)).assertIsDisplayed()
            compose.onNodeWithText(s(R.string.verification_unverified)).assertIsDisplayed()
            compose.onNodeWithText("Ada").assertIsDisplayed()
            compose.onNodeWithText(s(R.string.verification_verified)).assertIsDisplayed()
            compose.onNodeWithText("Eve").assertIsDisplayed()
            compose.onNodeWithText(s(R.string.verification_compromised)).assertIsDisplayed()
        }
    }

    @Test
    fun aContactOpensItsConversationAndBackReturns() {
        running().use { scenario ->
            showContacts()
            model.onNotice(Notice.ChatReceived(2u, 1u, "from Ada"))
            model.onNotice(Notice.ChatReceived(1u, 1u, "from 1"))

            compose.onNodeWithText("Ada").performClick()
            compose.onNodeWithText("from Ada").assertIsDisplayed()
            compose.onNodeWithText("from 1").assertDoesNotExist()

            compose.onNodeWithText(s(R.string.back)).performClick()
            compose.onNodeWithText(s(R.string.contact_label, 1)).performClick()
            compose.onNodeWithText("from 1").assertIsDisplayed()

            scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }
            compose.onNodeWithText("Ada").assertIsDisplayed()
        }
    }

    @Test
    fun sendingShowsTheMessageAsSentAndClearsTheField() {
        app.engine.respond = { if (it is Event.SendChat) listOf(Action.ChatSent(it.contact, 1u)) else emptyList() }
        running().use {
            showContacts()
            compose.onNodeWithText("Ada").performClick()
            compose.onNodeWithText(s(R.string.send)).assertIsNotEnabled()

            compose.onNodeWithText(s(R.string.message_hint)).performTextInput("hello")
            compose.onNodeWithText(s(R.string.send)).assertIsEnabled().performClick()

            compose.onNodeWithText("hello").assertIsDisplayed()
            compose.onNodeWithText(s(R.string.state_sent)).assertIsDisplayed()
            compose.onNodeWithText(s(R.string.send)).assertIsNotEnabled()
            assertEquals(Event.SendChat(2u, "hello"), app.engine.events.last())
        }
    }

    @Test
    fun unsentMessagesSayWhy() {
        running().use {
            showContacts()
            model.send(2u, "a") { model.onNotice(Notice.ChatRejected(2u, ChatRejection.NO_SESSION)) }
            model.send(2u, "b") { model.onNotice(Notice.ChatRejected(2u, ChatRejection.TOO_LONG)) }
            model.send(2u, "c") { model.onNotice(Notice.ChatRejected(2u, ChatRejection.EXHAUSTED)) }
            model.send(2u, "e") { model.onNotice(Notice.ChatRejected(2u, ChatRejection.QUEUE_FULL)) }
            model.send(2u, "d") {}

            compose.onNodeWithText("Ada").performClick()

            val reasons = listOf(
                R.string.rejection_no_session,
                R.string.rejection_too_long,
                R.string.rejection_exhausted,
                R.string.rejection_queue_full,
                R.string.state_failed,
            )
            for (reason in reasons) {
                compose.onNode(hasScrollToNodeAction()).performScrollToNode(hasText(s(reason)))
                compose.onNodeWithText(s(reason)).assertIsDisplayed()
            }
        }
    }

    @Test
    fun deliveryStatesAndMissedMessagesAreShown() {
        running().use {
            showContacts()
            for (msgno in 1u..4u) model.send(2u, "m$msgno") { model.onNotice(Notice.ChatSent(2u, msgno)) }
            model.send(2u, "m5") { model.onNotice(Notice.ChatQueued(2u, 5u)) }
            model.onNotice(Notice.ChatRead(2u, 1u))
            model.onNotice(Notice.ChatDelivered(2u, 2u))
            model.onNotice(Notice.ChatExpired(2u, 3u))
            model.onNotice(Notice.ChatsExpired(2u, 1u, 2u))

            compose.onNodeWithText("Ada").performClick()

            val shown = listOf(
                s(R.string.state_read),
                s(R.string.state_delivered),
                s(R.string.state_expired),
                s(R.string.state_sent),
                s(R.string.state_queued),
                app.getString(R.string.missed, 1, 2),
            )
            for (text in shown) {
                compose.onNode(hasScrollToNodeAction()).performScrollToNode(hasText(text))
                compose.onNodeWithText(text).assertIsDisplayed()
            }
        }
    }

    @Test
    fun anOpenConversationMarksArrivingMessagesRead() {
        running().use {
            showContacts()
            compose.onNodeWithText("Ada").performClick()

            model.onNotice(Notice.ChatReceived(2u, 1u, "hey"))
            compose.waitForIdle()

            compose.onNodeWithText("hey").assertIsDisplayed()
            assertEquals(Event.MarkRead(2u, 1u), app.engine.events.last())
        }
    }

    @Test
    fun theDebugPanelListsLinkStats() {
        running().use {
            compose.onNodeWithText(s(R.string.debug_show)).performClick()
            compose.onNodeWithText(s(R.string.debug_empty)).assertIsDisplayed()

            app.session.radioListener.linkUp(GattRole.CENTRAL, 517u, byteArrayOf(1))
            val up = model.links.single().upAtMonoMs.toLong()

            compose.onNodeWithText(s(R.string.debug_link, 1L, "CENTRAL", 517, up, 0, 0L, 0, 0L)).assertIsDisplayed()
            compose.onNodeWithText(s(R.string.debug_hide)).performClick()
            compose.onNodeWithText(s(R.string.debug_empty)).assertDoesNotExist()
        }
    }

    @Test
    fun faultsShowUntilDismissed() {
        running().use {
            model.onNotice(Notice.Fault(FaultKind.CRYPTO))
            compose.onNodeWithText(s(R.string.fault_crypto)).assertIsDisplayed()
            compose.onNodeWithText(s(R.string.dismiss)).performClick()
            compose.onNodeWithText(s(R.string.fault_crypto)).assertDoesNotExist()

            model.onNotice(Notice.Fault(FaultKind.POISONED))
            compose.onNodeWithText(s(R.string.fault_poisoned)).assertIsDisplayed()

            model.onNotice(Notice.Fault(FaultKind.STORAGE_RESET))
            compose.onNodeWithText(s(R.string.fault_storage_reset)).assertIsDisplayed()
        }
    }

    @Test
    fun leavingTheForegroundStopsTheRadioAndReturningRestartsIt() {
        running().use { scenario ->
            scenario.moveToState(Lifecycle.State.CREATED)
            assertFalse(AppHarness.scanning())

            scenario.moveToState(Lifecycle.State.RESUMED)
            assertTrue(AppHarness.scanning())
        }
    }

    @Test
    fun aConfigurationChangeKeepsTheRadioRunning() {
        running().use { scenario ->
            val server = assertNotNull(openServer())

            scenario.recreate()

            assertSame(server, openServer())
        }
    }

    @Test
    @Config(qualifiers = "night")
    fun theDarkThemeRenders() {
        launch().use {
            compose.onNodeWithText(s(R.string.permission_title)).assertIsDisplayed()
        }
    }
}
