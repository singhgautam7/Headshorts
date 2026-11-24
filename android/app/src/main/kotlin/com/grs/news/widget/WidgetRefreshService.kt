package com.grs.news.widget

import android.app.job.JobParameters
import android.app.job.JobService
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Starts a headless Flutter engine on the `widgetRefreshMain` entrypoint, hands it the
 * source ids, and waits for `{ok, failed, total}`. Works with the app process dead.
 */
class WidgetRefreshService : JobService() {
    private var engine: FlutterEngine? = null
    private var finished = false
    private val handler = Handler(Looper.getMainLooper())

    override fun onStartJob(params: JobParameters): Boolean {
        finished = false
        val widgetId = params.extras.getInt("id", 0)
        val ids = WidgetPrefs.sourceIds(this, widgetId)
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)
            val e = FlutterEngine(applicationContext)
            engine = e
            MethodChannel(e.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "ready" -> result.success(mapOf("ids" to ids?.toList()))
                    "done" -> {
                        result.success(null)
                        finish(params, call.arguments as? Map<*, *>)
                    }
                    else -> result.notImplemented()
                }
            }
            e.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "widgetRefreshMain"),
            )
            // Dart has its own 45 s deadline; this is the backstop for a dead isolate.
            handler.postDelayed({ finish(params, null) }, WATCHDOG_MS)
        } catch (_: Throwable) {
            finish(params, null, reschedule = false)
            return false
        }
        return true
    }

    override fun onStopJob(params: JobParameters): Boolean {
        finish(params, null, reschedule = false)
        return false
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        engine?.destroy()
        engine = null
        super.onDestroy()
    }

    private fun finish(params: JobParameters, result: Map<*, *>?, reschedule: Boolean = true) {
        if (finished) return
        finished = true
        handler.removeCallbacksAndMessages(null)
        val total = (result?.get("total") as? Number)?.toInt() ?: 0
        val ok = (result?.get("ok") as? Number)?.toInt() ?: 0
        WidgetPrefs.setRefreshing(this, false)
        // Nothing came back at all, or every feed failed: say so in words.
        val failedAll = result == null || (total > 0 && ok == 0)
        WidgetPrefs.setError(
            this,
            when {
                !failedAll -> ""
                !HeadlinesWidgetProvider.isOnline(this) -> "offline"
                else -> "failed"
            },
        )
        HeadlinesWidgetProvider.updateAll(this)
        engine?.destroy()
        engine = null
        if (reschedule) jobFinished(params, false)
    }

    companion object {
        const val CHANNEL = "headshorts/widget_refresh"
        private const val WATCHDOG_MS = 75_000L
    }
}
