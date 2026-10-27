package ch.trancee.cairn.android

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import androidx.annotation.RequiresApi
import ch.trancee.cairn.sdk.RowSealer
import java.security.KeyStore
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

private const val KEYSTORE = "AndroidKeyStore"
private const val TRANSFORMATION = "AES/GCM/NoPadding"
private const val NONCE = 12
private const val TAG_BITS = 128

/**
 * Seals rows with the installation's non-exportable Keystore AES-256-GCM key, in StrongBox when
 * present (ADR 0006, ADR 0035 §1). The Keystore draws each 96-bit nonce; the key never enters
 * app memory. A missing key is replaced, so rows sealed under the old one fail to open.
 */
class KeystoreSealer(private val alias: String = "cairn-rows") : RowSealer {
    private val key: SecretKey =
        KeyStore.getInstance(KEYSTORE).apply { load(null) }.getKey(alias, null) as SecretKey? ?: generate()

    override fun seal(aad: ByteArray, plaintext: ByteArray): ByteArray {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key)
        cipher.updateAAD(aad)
        return cipher.iv + cipher.doFinal(plaintext)
    }

    override fun open(aad: ByteArray, sealed: ByteArray): ByteArray? {
        if (sealed.size < NONCE + TAG_BITS / 8) return null
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(TAG_BITS, sealed, 0, NONCE))
        cipher.updateAAD(aad)
        return try {
            cipher.doFinal(sealed, NONCE, sealed.size - NONCE)
        } catch (_: AEADBadTagException) {
            null
        }
    }

    private fun generate(): SecretKey =
        (if (Build.VERSION.SDK_INT >= 28) StrongBox.generate(spec()) else null) ?: generate(spec().build())

    private fun spec(): KeyGenParameterSpec.Builder =
        KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setKeySize(256)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)

    /** API 28 calls, apart so API 26's class verifier never meets them. */
    @RequiresApi(28)
    private object StrongBox {
        fun generate(spec: KeyGenParameterSpec.Builder): SecretKey? = try {
            generate(spec.setIsStrongBoxBacked(true).build())
        } catch (_: StrongBoxUnavailableException) {
            null
        }
    }
}

private fun generate(spec: KeyGenParameterSpec): SecretKey =
    KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE).run {
        init(spec)
        generateKey()
    }
