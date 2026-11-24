package com.grs.news

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import com.grs.news.widget.WidgetChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingArticle: Int? = null
    private var widgetChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A recreated activity gets its old intent back; that tap was already handled.
        if (savedInstanceState == null) pendingArticle = articleIdOf(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val id = articleIdOf(intent) ?: return
        pendingArticle = id
        // Dart takes it if its handler is up; otherwise it stays for takeLaunchArticle.
        widgetChannel?.invokeMethod("openArticle", id, object : MethodChannel.Result {
            override fun success(result: Any?) { if (pendingArticle == id) pendingArticle = null }
            override fun error(code: String, message: String?, details: Any?) {}
            override fun notImplemented() {}
        })
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        widgetChannel = WidgetChannel.register(flutterEngine, this, takeLaunchArticle = {
            pendingArticle.also { pendingArticle = null }
        })
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "headshorts/platform")
            .setMethodCallHandler { call, result ->
                if (call.method == "deviceMemory") {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    val info = ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }
                    result.success(mapOf("ramMb" to (info.totalMem / (1024 * 1024)).toInt(), "lowRam" to am.isLowRamDevice))
                } else if (call.method == "wallpaperSeed") {
                    // The accent Android derives from the wallpaper; Material You starts at 12.
                    result.success(
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                            resources.getColor(android.R.color.system_accent1_600, theme)
                        else null
                    )
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun articleIdOf(intent: Intent?): Int? {
        val uri = intent?.data ?: return null
        if (uri.scheme != "headshorts" || uri.host != "article") return null
        return uri.lastPathSegment?.toIntOrNull()
    }
}
