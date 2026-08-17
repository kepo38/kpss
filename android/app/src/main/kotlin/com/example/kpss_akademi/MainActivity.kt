package com.example.kpss_akademi

import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyTabletPortraitLock()
        applyScreenshotPolicy()
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        applyTabletPortraitLock()
    }

    private fun applyScreenshotPolicy() {
        if (shouldAllowScreenshots()) {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    /**
     * Debug sürümünde her cihazda izin; release'te yalnızca allowlist'teki
     * geliştirici telefonunda (ekran görüntüsü / QA için).
     */
    private fun shouldAllowScreenshots(): Boolean {
        if (BuildConfig.ALLOW_SCREENSHOTS) return true
        val androidId = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ANDROID_ID,
        ).orEmpty()
        if (androidId in ALLOWED_ANDROID_IDS) return true
        val serial = runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Build.getSerial()
            } else {
                @Suppress("DEPRECATION")
                Build.SERIAL
            }
        }.getOrNull().orEmpty()
        return serial in ALLOWED_SERIALS
    }

    private fun applyTabletPortraitLock() {
        if (resources.configuration.smallestScreenWidthDp >= 600) {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        } else {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        }
    }

    companion object {
        // Geliştirici telefonu (2409BRN2CA / Redmi) — release'te de SS alınabilsin.
        private val ALLOWED_ANDROID_IDS = setOf("95cb54eeb2a4ebd4")
        private val ALLOWED_SERIALS = setOf("GAD6ZHBU4LJJ9XVW")
    }
}
