package com.grs.news.widget

import android.app.PendingIntent
import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.PersistableBundle
import android.util.SizeF
import android.widget.RemoteViews
import com.grs.news.MainActivity
import com.grs.news.R
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors

/** Headlines home screen widget. Draws from the app's database; never fetches itself. */
class HeadlinesWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        updateAll(context, goAsync())
    }

    override fun onAppWidgetOptionsChanged(
        context: Context, manager: AppWidgetManager, id: Int, newOptions: android.os.Bundle,
    ) {
        updateAll(context, goAsync())
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        ids.forEach { WidgetPrefs.forget(context, it) }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_REFRESH) {
            startRefresh(context, intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID), goAsync())
        } else {
            super.onReceive(context, intent)
        }
    }

    companion object {
        const val ACTION_REFRESH = "com.grs.news.widget.REFRESH"
        const val JOB_ID = 7001
        private val executor = Executors.newSingleThreadExecutor()

        /** Redraws every placed widget from the database. */
        fun updateAll(ctx: Context, pending: android.content.BroadcastReceiver.PendingResult? = null) {
            val app = ctx.applicationContext
            executor.execute {
                try {
                    val mgr = AppWidgetManager.getInstance(app)
                    val ids = mgr.getAppWidgetIds(ComponentName(app, HeadlinesWidgetProvider::class.java))
                    ids.forEach { render(app, mgr, it) }
                } catch (_: Exception) {
                    // A failed redraw leaves the previous frame in place.
                } finally {
                    pending?.finish()
                }
            }
        }

        private fun online(ctx: Context): Boolean {
            val cm = ctx.getSystemService(ConnectivityManager::class.java)
            val caps = cm.getNetworkCapabilities(cm.activeNetwork ?: return false) ?: return false
            return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        }

        fun isOnline(ctx: Context) = online(ctx)

        private fun startRefresh(ctx: Context, widgetId: Int, pending: android.content.BroadcastReceiver.PendingResult?) {
            try {
                if (WidgetPrefs.isRefreshing(ctx)) { pending?.finish(); return }
                if (!online(ctx)) {
                    WidgetPrefs.setError(ctx, "offline")
                } else {
                    WidgetPrefs.setRefreshing(ctx, true)
                    WidgetPrefs.setError(ctx, "")
                    if (!scheduleJob(ctx, widgetId)) {
                        WidgetPrefs.setRefreshing(ctx, false)
                        WidgetPrefs.setError(ctx, "failed")
                    }
                }
            } catch (e: Exception) {
                WidgetPrefs.setRefreshing(ctx, false)
            }
            updateAll(ctx, pending)
        }

        /** Runs the headless Dart refresh as a job, expedited where the OS allows. */
        fun scheduleJob(ctx: Context, widgetId: Int): Boolean {
            val extras = PersistableBundle().apply { putInt("id", widgetId) }
            val builder = JobInfo.Builder(JOB_ID, ComponentName(ctx, WidgetRefreshService::class.java))
                .setExtras(extras)
            if (Build.VERSION.SDK_INT >= 31) builder.setExpedited(true) else builder.setOverrideDeadline(0)
            return try {
                ctx.getSystemService(JobScheduler::class.java).schedule(builder.build()) == JobScheduler.RESULT_SUCCESS
            } catch (_: Exception) {
                false
            }
        }

        private fun render(ctx: Context, mgr: AppWidgetManager, widgetId: Int) {
            val snap = WidgetData.load(ctx, WidgetPrefs.sourceIds(ctx, widgetId))
            val options = mgr.getAppWidgetOptions(widgetId)
            val fontScale = ctx.resources.configuration.fontScale
            fun height(key: String) = options.getInt(key, 0).let { if (it > 0) it.toFloat() else 320f }

            @Suppress("DEPRECATION")
            val sizes = if (Build.VERSION.SDK_INT >= 31)
                options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES) else null
            val views = if (!sizes.isNullOrEmpty()) {
                RemoteViews(sizes.take(16).associateWith { build(ctx, snap, it.height, fontScale, widgetId) })
            } else {
                // The launcher reports two heights: the short one in landscape, the tall one upright.
                RemoteViews(
                    build(ctx, snap, height(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT), fontScale, widgetId),
                    build(ctx, snap, height(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT), fontScale, widgetId),
                )
            }
            mgr.updateAppWidget(widgetId, views)
        }

        private fun build(
            ctx: Context, snap: WidgetSnapshot, heightDp: Float, fontScale: Float, widgetId: Int,
        ): RemoteViews {
            val v = RemoteViews(ctx.packageName, R.layout.widget_headlines)
            val legacy = Build.VERSION.SDK_INT < 31
            val bg = if (legacy) WidgetPrefs.themeColor(ctx, "widget_bg") else null
            val fg = if (legacy) WidgetPrefs.themeColor(ctx, "widget_fg") else null
            val fg2 = if (legacy) WidgetPrefs.themeColor(ctx, "widget_fg2") else null
            val accent = if (legacy) WidgetPrefs.themeColor(ctx, "widget_accent") else null
            bg?.let { v.setInt(R.id.widget_bg, "setColorFilter", it) }
            accent?.let {
                v.setTextColor(R.id.widget_title, it)
                v.setInt(R.id.widget_refresh, "setColorFilter", it)
            }
            fg2?.let { v.setTextColor(R.id.widget_status, it); v.setTextColor(R.id.widget_message, it) }

            // Header: status line, refresh button, tap to open the app.
            val refreshing = WidgetPrefs.isRefreshing(ctx)
            val status = statusText(ctx, snap, refreshing)
            v.setTextViewText(R.id.widget_status, status)
            v.setViewVisibility(R.id.widget_status, if (status.isEmpty()) android.view.View.GONE else android.view.View.VISIBLE)
            v.setContentDescription(R.id.widget_header_open, ctx.getString(R.string.widget_header_cd, status))
            ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)?.let {
                v.setOnClickPendingIntent(
                    R.id.widget_header_open,
                    PendingIntent.getActivity(ctx, 0, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT),
                )
            }
            // Never disabled: taps during a refresh are ignored in onReceive, and if the refresh
            // process is killed the button must still work once the flag is stale.
            // View.setAlpha is not remotable before API 31; ImageView.setImageAlpha always is.
            v.setInt(R.id.widget_refresh, "setImageAlpha", if (refreshing) 102 else 255)
            v.setContentDescription(
                R.id.widget_refresh,
                ctx.getString(if (refreshing) R.string.widget_refreshing_cd else R.string.widget_refresh_cd),
            )
            val refresh = Intent(ctx, HeadlinesWidgetProvider::class.java)
                .setAction(ACTION_REFRESH)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                .setData(Uri.parse("headshorts://widget/refresh/$widgetId"))
            v.setOnClickPendingIntent(
                R.id.widget_refresh,
                PendingIntent.getBroadcast(ctx, widgetId, refresh, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT),
            )

            // Body.
            if (snap.kind != WidgetKind.ROWS) {
                v.setTextViewText(
                    R.id.widget_message,
                    ctx.getString(if (snap.kind == WidgetKind.NO_SOURCES) R.string.widget_no_sources else R.string.widget_empty),
                )
                v.setViewVisibility(R.id.widget_message, android.view.View.VISIBLE)
                v.setViewVisibility(R.id.widget_rows, android.view.View.GONE)
                return v
            }
            v.setViewVisibility(R.id.widget_message, android.view.View.GONE)
            v.setViewVisibility(R.id.widget_rows, android.view.View.VISIBLE)
            v.removeAllViews(R.id.widget_rows)

            val fit = WidgetLogic.fit(heightDp, fontScale)
            val now = System.currentTimeMillis()
            for (r in snap.rows.take(fit.rows)) {
                val row = RemoteViews(ctx.packageName, if (fit.compact) R.layout.widget_row_compact else R.layout.widget_row)
                val time = agoText(ctx, r.publishedMs, now)
                row.setTextViewText(R.id.row_title, r.title)
                row.setTextViewText(R.id.row_meta, ctx.getString(R.string.widget_row_meta, r.source, time))
                row.setContentDescription(R.id.widget_row, ctx.getString(R.string.widget_row_cd, r.title, r.source, time))
                fg?.let { row.setTextColor(R.id.row_title, it) }
                fg2?.let { row.setTextColor(R.id.row_meta, it) }
                val open = Intent(ctx, MainActivity::class.java)
                    .setAction(Intent.ACTION_VIEW)
                    .setData(Uri.parse("headshorts://article/${r.id}"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                row.setOnClickPendingIntent(
                    R.id.widget_row,
                    PendingIntent.getActivity(ctx, r.id, open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT),
                )
                v.addView(R.id.widget_rows, row)
            }
            return v
        }

        private fun statusText(ctx: Context, snap: WidgetSnapshot, refreshing: Boolean): String {
            if (refreshing) return ctx.getString(R.string.widget_refreshing)
            when (WidgetPrefs.error(ctx)) {
                "offline" -> return ctx.getString(R.string.widget_offline)
                "failed" -> return ctx.getString(R.string.widget_error)
            }
            val last = snap.lastFetchedMs ?: return ""
            val a = WidgetLogic.ago(System.currentTimeMillis() - last)
            return when (a.unit) {
                AgoUnit.NOW -> ctx.getString(R.string.widget_updated_now)
                AgoUnit.MINUTES -> ctx.getString(R.string.widget_updated_min, a.n)
                AgoUnit.HOURS -> ctx.getString(R.string.widget_updated_hour, a.n)
                AgoUnit.DATE -> ctx.getString(R.string.widget_updated_date, dateOf(last))
            }
        }

        private fun agoText(ctx: Context, whenMs: Long, now: Long): String {
            val a = WidgetLogic.ago(now - whenMs)
            return when (a.unit) {
                AgoUnit.NOW -> ctx.getString(R.string.widget_ago_now)
                AgoUnit.MINUTES -> ctx.getString(R.string.widget_ago_min, a.n)
                AgoUnit.HOURS -> ctx.getString(R.string.widget_ago_hour, a.n)
                AgoUnit.DATE -> dateOf(whenMs)
            }
        }

        private fun dateOf(ms: Long): String = SimpleDateFormat("d MMM", Locale.getDefault()).format(Date(ms))
    }
}
