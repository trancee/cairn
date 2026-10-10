package ch.trancee.cairn.consumer

import android.app.Activity
import android.app.Instrumentation
import android.os.Bundle

public class SmokeInstrumentation : Instrumentation() {
    override fun onCreate(arguments: Bundle?) {
        super.onCreate(arguments)
        start()
    }

    override fun onStart() {
        main()
        val results = Bundle()
        results.putString(
            "stream",
            "PASS: Android value, boundary, typed error and object lifetime\n",
        )
        finish(Activity.RESULT_OK, results)
    }
}
