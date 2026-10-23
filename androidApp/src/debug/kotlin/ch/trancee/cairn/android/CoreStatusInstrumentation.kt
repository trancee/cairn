package ch.trancee.cairn.android

import android.app.Activity
import android.app.Instrumentation
import android.os.Bundle
import ch.trancee.cairn.app.coreStatus

/** Runs the reference app's core call in the packaged APK; `am instrument` reports the result. */
class CoreStatusInstrumentation : Instrumentation() {
    override fun onCreate(arguments: Bundle?) {
        super.onCreate(arguments)
        start()
    }

    override fun onStart() {
        val status = coreStatus()
        val passed = status == EXPECTED_STATUS
        val results = Bundle()
        results.putString(
            "stream",
            if (passed) "PASS: $status\n" else "FAIL: expected '$EXPECTED_STATUS', got '$status'\n",
        )
        finish(if (passed) Activity.RESULT_OK else Activity.RESULT_CANCELED, results)
    }

    private companion object {
        const val EXPECTED_STATUS = "paired=1+1 chat=hello rejected=NotRestored closed=true"
    }
}
