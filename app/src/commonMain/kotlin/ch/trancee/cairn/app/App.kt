package ch.trancee.cairn.app

import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember

/** Reference app root; shows the result of calling the Rust core through the SDK. */
@Composable
fun App() {
    val status = remember { coreStatus() }
    BasicText(status)
}
