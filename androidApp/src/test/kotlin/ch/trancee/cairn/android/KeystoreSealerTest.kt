package ch.trancee.cairn.android

import android.security.keystore.KeyProperties
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
class KeystoreSealerTest {
    private val aad = "slot".encodeToByteArray()
    private val plaintext = "row".encodeToByteArray()

    @Before
    fun freshKeystore() = FakeAndroidKeyStore.install()

    @Test
    fun aSealedRowIsNonceCiphertextAndTagAndOpensInALaterSealer() {
        val sealed = KeystoreSealer().seal(aad, plaintext)

        assertEquals(12 + plaintext.size + 16, sealed.size)
        assertContentEquals(plaintext, KeystoreSealer().open(aad, sealed))
        assertEquals(1, FakeAndroidKeyStore.specs.size)
    }

    @Test
    fun eachSealDrawsAFreshNonce() {
        val sealer = KeystoreSealer()

        assertFalse(sealer.seal(aad, plaintext).contentEquals(sealer.seal(aad, plaintext)))
    }

    @Test
    fun aRowFailsToOpenUnderAnotherAadAfterTamperingOrWhenTruncated() {
        val sealer = KeystoreSealer()
        val sealed = sealer.seal(aad, plaintext)

        assertNull(sealer.open("other".encodeToByteArray(), sealed))
        assertNull(sealer.open(aad, sealed.copyOf().also { it[it.size - 1] = (it[it.size - 1] + 1).toByte() }))
        assertNull(sealer.open(aad, sealed.copyOf(27)))
    }

    @Test
    fun aRowSealedUnderALostKeyFailsToOpen() {
        val sealed = KeystoreSealer().seal(aad, plaintext)
        FakeAndroidKeyStore.keys.clear()

        assertNull(KeystoreSealer().open(aad, sealed))
    }

    @Test
    fun theKeyIsAnAes256GcmKeyWithoutUserAuthentication() {
        KeystoreSealer()

        val spec = FakeAndroidKeyStore.specs.single()
        assertEquals("cairn-rows", spec.keystoreAlias)
        assertEquals(256, spec.keySize)
        assertEquals(KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT, spec.purposes)
        assertContentEquals(arrayOf(KeyProperties.BLOCK_MODE_GCM), spec.blockModes)
        assertContentEquals(arrayOf(KeyProperties.ENCRYPTION_PADDING_NONE), spec.encryptionPaddings)
        assertTrue(spec.isRandomizedEncryptionRequired)
        assertFalse(spec.isUserAuthenticationRequired)
    }

    @Test
    @Config(sdk = [37])
    fun theKeyLivesInStrongBoxWhenPresent() {
        KeystoreSealer()

        assertTrue(FakeAndroidKeyStore.specs.single().isStrongBoxBacked)
    }

    @Test
    @Config(sdk = [37])
    fun withoutStrongBoxTheKeyFallsBackToTheTee() {
        FakeAndroidKeyStore.strongBox = false

        val sealer = KeystoreSealer()

        assertEquals(listOf(true, false), FakeAndroidKeyStore.specs.map { it.isStrongBoxBacked })
        assertContentEquals(plaintext, sealer.open(aad, sealer.seal(aad, plaintext)))
    }
}
