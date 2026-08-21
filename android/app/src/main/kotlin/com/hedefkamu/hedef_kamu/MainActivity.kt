package com.hedefkamu.hedef_kamu

import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var captureOverrideAllow: Boolean? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "hedef_kamu/screenshot_gate",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setAllowed" -> {
                    val allow = call.argument<Boolean>("allow") == true
                    captureOverrideAllow = allow
                    applyScreenshotPolicy()
                    Log.i(TAG, "screenshotGate setAllowed=$allow")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyTabletPortraitLock()
        applyScreenshotPolicy()
    }

    override fun onResume() {
        super.onResume()
        // Reklam SDK / sistem katmanı FLAG_SECURE'u geri koyabiliyor.
        applyScreenshotPolicy()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            applyScreenshotPolicy()
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        applyTabletPortraitLock()
    }

    private fun applyScreenshotPolicy() {
        val allow = captureOverrideAllow ?: shouldAllowScreenshots()
        if (allow) {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            window.setFlags(0, WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    /**
     * Release: ekran görüntüsü / kayıt yasak (FLAG_SECURE).
     * Debug: serbest. Geliştirici cihaz allowlist yalnızca QA içindir.
     * Uygulama içi yanlış-defteri paylaşımı (filigranlı kart) ayrı kotayla sınırlıdır.
     */
    private fun shouldAllowScreenshots(): Boolean {
        if (BuildConfig.ALLOW_SCREENSHOTS) return true

        val androidId = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ANDROID_ID,
        ).orEmpty()
        val model = Build.MODEL.orEmpty()
        val allowed = androidId in ALLOWED_ANDROID_IDS ||
            model in ALLOWED_MODELS ||
            isAllowedSerial()

        Log.i(
            TAG,
            "screenshotPolicy allow=$allowed model=$model androidId=$androidId",
        )
        return allowed
    }

    private fun isAllowedSerial(): Boolean {
        val candidates = buildList {
            add(Build.SERIAL.orEmpty())
            runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    add(Build.getSerial())
                }
            }
            // ADB / boot prop — izin gerektirmez.
            runCatching {
                val clazz = Class.forName("android.os.SystemProperties")
                val get = clazz.getMethod("get", String::class.java, String::class.java)
                add(get.invoke(null, "ro.serialno", "") as String)
                add(get.invoke(null, "ro.boot.serialno", "") as String)
            }
        }
        return candidates.any { it.isNotBlank() && it in ALLOWED_SERIALS }
    }

    private fun applyTabletPortraitLock() {
        if (resources.configuration.smallestScreenWidthDp >= 600) {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        } else {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        }
    }

    companion object {
        private const val TAG = "KpssScreenshot"

        // Geliştirici telefonu (2409BRN2CA / Redmi) — release'te de SS alınabilsin.
        private val ALLOWED_ANDROID_IDS = setOf(
            "55d7e0039fdd2679", // eski app-scoped (com.example.kpss_odak)
            "95cb54eeb2a4ebd4", // adb settings android_id
        )
        private val ALLOWED_SERIALS = setOf("GAD6ZHBU4LJJ9XVW")
        private val ALLOWED_MODELS = setOf("2409BRN2CA")
    }
}
