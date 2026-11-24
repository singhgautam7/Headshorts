package com.grs.news.widget

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File

enum class WidgetKind { NO_SOURCES, EMPTY, ROWS }

class WidgetSnapshot(val kind: WidgetKind, val rows: List<WidgetRow>, val lastFetchedMs: Long?)

/** Reads the app's own SQLite file. Never writes. */
object WidgetData {
    private const val CUTOFF_DAYS = 90L
    private const val RAW_LIMIT = 80

    fun load(ctx: Context, ids: Set<Int>?): WidgetSnapshot {
        // path_provider's documents directory on Android is the "flutter" dir.
        val file = File(ctx.getDir("flutter", Context.MODE_PRIVATE), "headshorts.sqlite")
        if (!file.exists()) return none()
        val db = open(file) ?: return none()
        try {
            val scope = if (ids == null) "s.enabled = 1 AND s.muted_in_latest = 0"
            else "s.enabled = 1 AND s.id IN (${ids.joinToString(",")})"
            // An explicit empty choice names no source at all.
            if (ids != null && ids.isEmpty()) return none()

            var sourceCount = 0
            var lastFetched: Long? = null
            db.rawQuery(
                "SELECT COUNT(*), MAX(last_fetched_at) FROM sources s WHERE $scope", null,
            ).use { c ->
                if (c.moveToFirst()) {
                    sourceCount = c.getInt(0)
                    if (!c.isNull(1)) lastFetched = c.getLong(1) * 1000
                }
            }
            if (sourceCount == 0) return none()

            val cutoff = System.currentTimeMillis() / 1000 - CUTOFF_DAYS * 86_400
            val raw = ArrayList<WidgetRow>()
            db.rawQuery(
                "SELECT a.id, a.title, s.title, a.published_at, a.canonical_url, a.title_key " +
                    "FROM articles a JOIN sources s ON s.id = a.source_id " +
                    "WHERE $scope AND a.published_at >= ? " +
                    "ORDER BY a.published_at DESC, a.id DESC LIMIT $RAW_LIMIT",
                arrayOf(cutoff.toString()),
            ).use { c ->
                while (c.moveToNext()) {
                    raw.add(
                        WidgetRow(
                            c.getInt(0), c.getString(1) ?: "", c.getString(2) ?: "",
                            c.getLong(3) * 1000, c.getString(4) ?: "", c.getString(5) ?: "",
                        ),
                    )
                }
            }
            val rows = WidgetLogic.dedupe(raw, WidgetLogic.MAX_ROWS)
            return WidgetSnapshot(
                if (rows.isEmpty()) WidgetKind.EMPTY else WidgetKind.ROWS, rows, lastFetched,
            )
        } catch (_: Exception) {
            // Missing table, locked file, half-migrated schema: nothing to show.
            return none()
        } finally {
            db.close()
        }
    }

    private fun none() = WidgetSnapshot(WidgetKind.NO_SOURCES, emptyList(), null)

    private fun open(file: File): SQLiteDatabase? {
        val path = file.path
        for (flags in intArrayOf(SQLiteDatabase.OPEN_READONLY, SQLiteDatabase.OPEN_READWRITE)) {
            try {
                return SQLiteDatabase.openDatabase(path, null, flags or SQLiteDatabase.NO_LOCALIZED_COLLATORS)
            } catch (_: Exception) {
                // A read-only open of a WAL file can fail without its -shm; retry read-write.
            }
        }
        return null
    }
}
