package com.pinglo.tracker.config

import com.pinglo.tracker.BuildConfig

object Environment {
    val apiKey: String get() = BuildConfig.SUPABASE_API_KEY
    val endpoint: String get() = BuildConfig.SUPABASE_ENDPOINT
    val adminPassword: String get() = BuildConfig.HOME_LOCK_PASSWORD
}
