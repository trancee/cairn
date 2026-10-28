package ch.trancee.cairn.android

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import android.os.Build
import ch.trancee.cairn.ffi.ChatRejection
import ch.trancee.cairn.ffi.ContactInfo
import ch.trancee.cairn.ffi.Verification
import ch.trancee.cairn.sdk.FaultKind
import ch.trancee.cairn.sdk.LinkStats

/** Material 3 with the wallpaper colours on API 31+ (ADR 0023 §5). */
@Composable
fun CairnTheme(content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current
    val colors = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S ->
            if (dark) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        dark -> darkColorScheme()
        else -> lightColorScheme()
    }
    MaterialTheme(colorScheme = colors, content = content)
}

/** What the user can do; [MainActivity] implements each. */
interface ScreenActions {
    fun allow()

    fun openSettings()

    fun enableBluetooth()

    fun send(contact: ULong, text: String)

    /** The user sees [contact]'s conversation, so its received messages are read. */
    fun read(contact: ULong)
}

/** The reference chat: a permission or Bluetooth gate, the contacts, one conversation and the debug panel. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CairnScreen(model: ChatModel, actions: ScreenActions) {
    var debug by rememberSaveable { mutableStateOf(false) }
    val open = model.open
    val running = model.radio != RadioState.NEEDS_PERMISSION && model.radio != RadioState.BLUETOOTH_OFF
    BackHandler(enabled = open != null) { model.open = null }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (open == null) stringResource(R.string.app_name) else label(open)) },
                navigationIcon = {
                    if (open != null) TextButton(onClick = { model.open = null }) { Text(stringResource(R.string.back)) }
                },
                actions = {
                    if (running) {
                        TextButton(onClick = { debug = !debug }) {
                            Text(stringResource(if (debug) R.string.debug_hide else R.string.debug_show))
                        }
                    }
                },
            )
        },
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            model.fault?.let { FaultBanner(it, model::dismissFault) }
            when (model.radio) {
                RadioState.NEEDS_PERMISSION -> Gate(R.string.permission_title, R.string.permission_body) {
                    Button(onClick = actions::allow) { Text(stringResource(R.string.permission_allow)) }
                    OutlinedButton(onClick = actions::openSettings) { Text(stringResource(R.string.permission_settings)) }
                }
                RadioState.BLUETOOTH_OFF -> Gate(R.string.bluetooth_title, R.string.bluetooth_body) {
                    Button(onClick = actions::enableBluetooth) { Text(stringResource(R.string.bluetooth_enable)) }
                }
                else -> {
                    if (debug) DebugPanel(model.links)
                    if (open == null) {
                        Contacts(model.contacts) { model.open = it }
                    } else {
                        key(open.id) {
                            val messages = model.messages(open.id)
                            LaunchedEffect(messages) { actions.read(open.id) }
                            Conversation(messages) { actions.send(open.id, it) }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun label(contact: ContactInfo): String =
    contact.name.ifEmpty { stringResource(R.string.contact_label, contact.id.toLong()) }

@Composable
private fun Gate(title: Int, body: Int, buttons: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text(stringResource(title), style = MaterialTheme.typography.headlineSmall)
        Text(stringResource(body), style = MaterialTheme.typography.bodyLarge)
        buttons()
    }
}

@Composable
private fun FaultBanner(kind: FaultKind, onDismiss: () -> Unit) {
    Surface(color = MaterialTheme.colorScheme.errorContainer, modifier = Modifier.fillMaxWidth()) {
        Row(Modifier.padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            val text = when (kind) {
                FaultKind.CRYPTO -> R.string.fault_crypto
                FaultKind.POISONED -> R.string.fault_poisoned
                FaultKind.STORAGE_RESET -> R.string.fault_storage_reset
            }
            Text(stringResource(text), Modifier.weight(1f))
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.dismiss)) }
        }
    }
}

@Composable
private fun DebugPanel(links: List<LinkStats>) {
    Surface(tonalElevation = 2.dp, modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            if (links.isEmpty()) Text(stringResource(R.string.debug_empty))
            links.forEach {
                Text(
                    stringResource(
                        R.string.debug_link,
                        it.link.toLong(),
                        it.role.name,
                        it.mtu.toInt(),
                        it.upAtMonoMs.toLong(),
                        it.fragmentsOut,
                        it.bytesOut,
                        it.fragmentsIn,
                        it.bytesIn,
                    ),
                    style = MaterialTheme.typography.bodySmall,
                    fontFamily = FontFamily.Monospace,
                )
            }
        }
    }
}

@Composable
private fun Contacts(contacts: List<ContactInfo>, onOpen: (ContactInfo) -> Unit) {
    if (contacts.isEmpty()) {
        Text(stringResource(R.string.contacts_empty), Modifier.padding(24.dp))
    }
    LazyColumn {
        items(contacts, key = { it.id.toLong() }) { contact ->
            ListItem(
                headlineContent = { Text(label(contact)) },
                supportingContent = { Text(stringResource(verification(contact.verification))) },
                modifier = Modifier.clickable { onOpen(contact) },
            )
            HorizontalDivider()
        }
    }
}

private fun verification(verification: Verification): Int = when (verification) {
    Verification.UNVERIFIED -> R.string.verification_unverified
    Verification.VERIFIED -> R.string.verification_verified
    Verification.COMPROMISED -> R.string.verification_compromised
}

@Composable
private fun Conversation(messages: List<Message>, onSend: (String) -> Unit) {
    var draft by rememberSaveable { mutableStateOf("") }
    Column(Modifier.fillMaxSize().imePadding()) {
        LazyColumn(
            Modifier.weight(1f).fillMaxWidth(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            items(messages) { Bubble(it) }
        }
        Row(Modifier.padding(8.dp), verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(
                value = draft,
                onValueChange = { draft = it },
                label = { Text(stringResource(R.string.message_hint)) },
                modifier = Modifier.weight(1f),
            )
            Button(
                onClick = {
                    onSend(draft)
                    draft = ""
                },
                enabled = draft.isNotBlank(),
                modifier = Modifier.padding(start = 8.dp),
            ) { Text(stringResource(R.string.send)) }
        }
    }
}

@Composable
private fun Bubble(message: Message) {
    val status = message.status
    val incoming = status == MessageStatus.Received
    val missed = status is MessageStatus.Missed
    val alignment = when {
        incoming -> Alignment.Start
        missed -> Alignment.CenterHorizontally
        else -> Alignment.End
    }
    Column(Modifier.fillMaxWidth(), horizontalAlignment = alignment) {
        if (!missed) {
            Surface(
                color = if (incoming) MaterialTheme.colorScheme.surfaceVariant else MaterialTheme.colorScheme.primaryContainer,
                shape = MaterialTheme.shapes.medium,
            ) {
                Text(message.text, Modifier.padding(horizontal = 12.dp, vertical = 8.dp))
            }
        }
        label(status)?.let { Text(it, style = MaterialTheme.typography.labelSmall) }
    }
}

/** The line under a message, or the whole line for a missed range. */
@Composable
private fun label(status: MessageStatus): String? = when (status) {
    MessageStatus.Received -> null
    is MessageStatus.Missed -> stringResource(R.string.missed, status.from.toLong(), status.to.toLong())
    MessageStatus.Queued -> stringResource(R.string.state_queued)
    MessageStatus.Sent -> stringResource(R.string.state_sent)
    MessageStatus.Delivered -> stringResource(R.string.state_delivered)
    MessageStatus.Read -> stringResource(R.string.state_read)
    MessageStatus.Expired -> stringResource(R.string.state_expired)
    MessageStatus.Failed -> stringResource(R.string.state_failed)
    is MessageStatus.Rejected -> stringResource(
        when (status.reason) {
            ChatRejection.NO_SESSION -> R.string.rejection_no_session
            ChatRejection.TOO_LONG -> R.string.rejection_too_long
            ChatRejection.EXHAUSTED -> R.string.rejection_exhausted
            ChatRejection.QUEUE_FULL -> R.string.rejection_queue_full
        },
    )
}
