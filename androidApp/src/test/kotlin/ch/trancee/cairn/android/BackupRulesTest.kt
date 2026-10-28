package ch.trancee.cairn.android

import android.content.pm.ApplicationInfo
import org.xmlpull.v1.XmlPullParser
import kotlin.test.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/** ADR 0006: the sealed database never leaves the device, by backup or by device transfer. */
@RunWith(RobolectricTestRunner::class)
class BackupRulesTest {
    private val app = AppHarness.app

    @Test
    fun backupIsDisabled() {
        assertEquals(0, app.applicationInfo.flags and ApplicationInfo.FLAG_ALLOW_BACKUP)
    }

    @Test
    fun cloudBackupAndDeviceTransferExcludeTheDatabase() {
        assertEquals(
            listOf("cloud-backup exclude database .", "device-transfer exclude database ."),
            rules(R.xml.data_extraction_rules),
        )
    }

    @Test
    fun fullBackupBeforeAndroid12ExcludesTheDatabase() {
        assertEquals(listOf(" exclude database ."), rules(R.xml.backup_rules))
    }

    /** Each include or exclude as "section tag domain path". */
    private fun rules(xml: Int): List<String> {
        val parser = app.resources.getXml(xml)
        val rules = mutableListOf<String>()
        var section = ""
        while (parser.next() != XmlPullParser.END_DOCUMENT) {
            if (parser.eventType != XmlPullParser.START_TAG) continue
            when (parser.name) {
                "cloud-backup", "device-transfer" -> section = parser.name
                "exclude", "include" -> rules +=
                    "$section ${parser.name} ${parser.getAttributeValue(null, "domain")} ${parser.getAttributeValue(null, "path")}"
            }
        }
        return rules
    }
}
