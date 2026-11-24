package com.grs.news.widget

import android.content.Context
import android.content.SharedPreferences

/** The widget's two preference files: Flutter's (shared with Dart) and its own state. */
object WidgetPrefs {
    private const val FLUTTER = "FlutterSharedPreferences"
    private const val OWN = "headshorts_widget"
    private const val STALE_MS = 2 * 60 * 1000L

    private fun flutter(ctx: Context): SharedPreferences =
        ctx.getSharedPreferences(FLUTTER, Context.MODE_PRIVATE)

    private fun own(ctx: Context): SharedPreferences =
        ctx.getSharedPreferences(OWN, Context.MODE_PRIVATE)

    fun sourceIds(ctx: Context, widgetId: Int): Set<Int>? =
        WidgetLogic.parseIds(flutter(ctx).getString("flutter.widget_sources_$widgetId", null))

    fun forget(ctx: Context, widgetId: Int) {
        flutter(ctx).edit().remove("flutter.widget_sources_$widgetId").apply()
    }

    /** Theme colours the app writes for devices without system dynamic colour. */
    fun themeColor(ctx: Context, name: String): Int? =
        (flutter(ctx).all["flutter.$name"] as? Number)?.toInt()

    fun isRefreshing(ctx: Context, now: Long = System.currentTimeMillis()): Boolean {
        val since = own(ctx).getLong("refreshing_since", 0)
        return since > 0 && now - since < STALE_MS
    }

    fun setRefreshing(ctx: Context, on: Boolean) {
        own(ctx).edit().putLong("refreshing_since", if (on) System.currentTimeMillis() else 0).apply()
    }

    /** "", "failed" or "offline". */
    fun error(ctx: Context): String = own(ctx).getString("error", "") ?: ""

    fun setError(ctx: Context, v: String) {
        own(ctx).edit().putString("error", v).apply()
    }
}
