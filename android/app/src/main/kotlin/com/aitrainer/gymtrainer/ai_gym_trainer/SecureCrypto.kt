package com.aitrainer.gymtrainer.ai_gym_trainer

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/// Device-bound AES-256-GCM key stored in Android Keystore. Ciphertext is what
/// reaches SQLite; plaintext exists only in memory while a screen needs it.
class SecureCrypto(context: Context) {
    private val keyStore: KeyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    private val key: SecretKey
        get() {
            val alias = "ai_gym_trainer_data_key"
            if (!keyStore.containsAlias(alias)) {
                val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
                generator.init(
                    KeyGenParameterSpec.Builder(
                        alias,
                        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                    )
                        .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                        .setKeySize(256)
                        .build(),
                )
                generator.generateKey()
            }
            return keyStore.getKey(alias, null) as SecretKey
        }

    fun encrypt(plaintext: String): Map<String, Any?> {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key)
        val iv = cipher.iv
        val ciphertext = cipher.doFinal(plaintext.toByteArray(Charsets.UTF_8))
        return mapOf(
            "schema_version" to 1,
            "alg" to "AES-256-GCM",
            "iv" to Base64.encodeToString(iv, Base64.NO_WRAP),
            "ct" to Base64.encodeToString(ciphertext, Base64.NO_WRAP),
        )
    }

    @Suppress("UNCHECKED_CAST")
    fun decrypt(payload: Map<*, *>): String {
        val iv = Base64.decode(payload["iv"] as String, Base64.NO_WRAP)
        val ct = Base64.decode(payload["ct"] as String, Base64.NO_WRAP)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, iv))
        return String(cipher.doFinal(ct), Charsets.UTF_8)
    }
}
