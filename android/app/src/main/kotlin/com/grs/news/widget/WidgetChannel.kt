package com.grs.news.widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** The `headshorts/widget` channel, shared by MainActivity and the config activity. */
object WidgetChannel {
    const val NAME = "headshorts/widget"

    fun register(
        engine: FlutterEngine,
        activity: Activity,
        takeLaunchArticle: () -> Int? = { null },
        onFinishConfig: ((Int) -> Boolean)? = null,
    ): MethodChannel {
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, NAME)
        channel.setMethodCallHandler { call, result ->
            val mgr = AppWidgetManager.getInstance(activity)
            val component = ComponentName(activity, HeadlinesWidgetProvider::class.java)
            when (call.method) {
                "update" -> {
                    // The app just finished a fetch: any earlier failure is stale.
                    WidgetPrefs.setError(activity, "")
                    HeadlinesWidgetProvider.updateAll(activity)
                    result.success(null)
                }
                "takeLaunchArticle" -> result.success(takeLaunchArticle())
                "finishConfig" -> {
                    val id = (call.arguments as? Number)?.toInt() ?: AppWidgetManager.INVALID_APPWIDGET_ID
                    HeadlinesWidgetProvider.updateAll(activity)
                    result.success(onFinishConfig?.invoke(id) ?: false)
                }
                "placedWidgets" -> result.success(mgr.getAppWidgetIds(component).toList())
                "canPin" -> result.success(mgr.isRequestPinAppWidgetSupported)
                "requestPin" -> result.success(
                    if (mgr.isRequestPinAppWidgetSupported) mgr.requestPinAppWidget(component, null, null) else false,
                )
                else -> result.notImplemented()
            }
        }
        return channel
    }

    fun resultIntent(id: Int): Intent = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
}
