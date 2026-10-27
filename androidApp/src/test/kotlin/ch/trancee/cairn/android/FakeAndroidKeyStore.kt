package ch.trancee.cairn.android

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.StrongBoxUnavailableException
import java.io.InputStream
import java.io.OutputStream
import java.security.Key
import java.security.KeyStoreSpi
import java.security.Provider
import java.security.SecureRandom
import java.security.Security
import java.security.cert.Certificate
import java.security.spec.AlgorithmParameterSpec
import java.util.Collections
import java.util.Date
import java.util.Enumeration
import javax.crypto.KeyGeneratorSpi
import javax.crypto.SecretKey
import javax.crypto.spec.SecretKeySpec

/**
 * A software stand-in for the `AndroidKeyStore` provider, which Robolectric lacks. Keys are plain
 * AES keys, so the JDK's AES/GCM runs the cipher; the real Keystore is exercised on devices.
 */
object FakeAndroidKeyStore {
    val keys = mutableMapOf<String, SecretKey>()
    val specs = mutableListOf<KeyGenParameterSpec>()
    var strongBox = true

    fun install() {
        keys.clear()
        specs.clear()
        strongBox = true
        // Providers are JVM-wide, but each Robolectric SDK sandbox loads its own copy of this object.
        Security.removeProvider(NAME)
        Security.addProvider(FakeProvider())
    }

    private const val NAME = "AndroidKeyStore"

    @Suppress("DEPRECATION")
    class FakeProvider : Provider(NAME, 1.0, "test keystore") {
        init {
            put("KeyStore.$NAME", Store::class.java.name)
            put("KeyGenerator.AES", Generator::class.java.name)
        }
    }

    class Store : KeyStoreSpi() {
        override fun engineGetKey(alias: String, password: CharArray?): Key? = keys[alias]
        override fun engineContainsAlias(alias: String) = alias in keys
        override fun engineLoad(stream: InputStream?, password: CharArray?) = Unit
        override fun engineAliases(): Enumeration<String> = Collections.enumeration(keys.keys.toList())
        override fun engineSize() = keys.size
        override fun engineDeleteEntry(alias: String) {
            keys -= alias
        }
        override fun engineGetCertificateChain(alias: String): Array<Certificate>? = null
        override fun engineGetCertificate(alias: String): Certificate? = null
        override fun engineGetCreationDate(alias: String): Date? = null
        override fun engineSetKeyEntry(alias: String, key: Key, password: CharArray?, chain: Array<Certificate>?) =
            throw UnsupportedOperationException()
        override fun engineSetKeyEntry(alias: String, key: ByteArray, chain: Array<Certificate>?) =
            throw UnsupportedOperationException()
        override fun engineSetCertificateEntry(alias: String, cert: Certificate) = throw UnsupportedOperationException()
        override fun engineIsKeyEntry(alias: String) = alias in keys
        override fun engineIsCertificateEntry(alias: String) = false
        override fun engineGetCertificateAlias(cert: Certificate): String? = null
        override fun engineStore(stream: OutputStream?, password: CharArray?) = throw UnsupportedOperationException()
    }

    class Generator : KeyGeneratorSpi() {
        private lateinit var spec: KeyGenParameterSpec

        override fun engineInit(params: AlgorithmParameterSpec, random: SecureRandom?) {
            spec = params as KeyGenParameterSpec
        }
        override fun engineInit(random: SecureRandom?) = throw UnsupportedOperationException()
        override fun engineInit(keysize: Int, random: SecureRandom?) = throw UnsupportedOperationException()

        override fun engineGenerateKey(): SecretKey {
            specs += spec
            if (Build.VERSION.SDK_INT >= 28 && !strongBox) StrongBoxRefusal.check(spec)
            return SecretKeySpec(ByteArray(spec.keySize / 8).also(SecureRandom()::nextBytes), "AES")
                .also { keys[spec.keystoreAlias] = it }
        }
    }

    /** Kept apart so API 26's class verifier never meets the API 28 exception. */
    private object StrongBoxRefusal {
        fun check(spec: KeyGenParameterSpec) {
            if (spec.isStrongBoxBacked) throw StrongBoxUnavailableException()
        }
    }
}
