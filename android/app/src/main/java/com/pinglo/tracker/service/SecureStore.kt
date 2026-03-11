package com.pinglo.tracker.service

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

enum class SecureStoreKey(val key: String) {
    UID("secure_uid"),
    HOME_LATITUDE("secure_home_latitude"),
    HOME_LONGITUDE("secure_home_longitude"),
}

@Singleton
class SecureStore @Inject constructor(
    @ApplicationContext context: Context,
) {
    private val prefs: SharedPreferences

    init {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()

        prefs = EncryptedSharedPreferences.create(
            context,
            "pinglo_secure_prefs",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }

    fun setString(value: String, key: SecureStoreKey) {
        prefs.edit().putString(key.key, value).apply()
    }

    fun getString(key: SecureStoreKey): String? =
        prefs.getString(key.key, null)

    fun setDouble(value: Double, key: SecureStoreKey) {
        setString(value.toString(), key)
    }

    fun getDouble(key: SecureStoreKey): Double? =
        getString(key)?.toDoubleOrNull()

    fun remove(key: SecureStoreKey) {
        prefs.edit().remove(key.key).apply()
    }
}
