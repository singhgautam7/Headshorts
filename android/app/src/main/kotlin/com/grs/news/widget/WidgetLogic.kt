package com.grs.news.widget

import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

/** One headline as the widget draws it. */
data class WidgetRow(
    val id: Int,
    val title: String,
    val source: String,
    val publishedMs: Long,
    val canonicalUrl: String,
    val titleKey: String,
)

enum class AgoUnit { NOW, MINUTES, HOURS, DATE }

data class Ago(val unit: AgoUnit, val n: Int)

/** Pure decisions: how many rows fit, how old something is, what is a duplicate. */
object WidgetLogic {
    const val MAX_ROWS = 10
    const val MIN_EXPANDED_ROWS = 5

    // Header chrome: 8dp padding top and bottom.
    private const val PADDING_DP = 16.0

    // Title 15sp and status 12sp stacked, at line height 1.25.
    fun headerDp(fontScale: Float): Double = max(48.0, 33.75 * fontScale)

    // Title lines at 15sp, one meta line at 11sp, 4dp padding top and bottom.
    fun rowDp(titleLines: Int, fontScale: Float): Double =
        (titleLines * 18.75 + 13.75) * fontScale + 8.0

    class Fit(val rows: Int, val compact: Boolean)

    /**
     * What fits in [heightDp]. Roomy rows (two-line titles) when at least five
     * of them fit, otherwise one-line rows. Text is in sp, so the estimate
     * grows with the system font scale instead of clipping at the largest.
     */
    fun fit(heightDp: Float, fontScale: Float): Fit {
        val avail = heightDp - PADDING_DP - headerDp(fontScale)
        val roomy = floor(avail / rowDp(2, fontScale)).toInt()
        if (roomy >= MIN_EXPANDED_ROWS) return Fit(min(roomy, MAX_ROWS), false)
        val compact = floor(avail / rowDp(1, fontScale)).toInt()
        return Fit(compact.coerceIn(1, MAX_ROWS), true)
    }

    /** Same story under another address or a near-identical headline is one row. */
    fun dedupe(rows: List<WidgetRow>, limit: Int): List<WidgetRow> {
        val urls = HashSet<String>()
        val keys = HashSet<String>()
        val out = ArrayList<WidgetRow>()
        for (r in rows) {
            if (r.canonicalUrl.isNotEmpty() && r.canonicalUrl in urls) continue
            if (r.titleKey.isNotEmpty() && r.titleKey in keys) continue
            if (r.canonicalUrl.isNotEmpty()) urls.add(r.canonicalUrl)
            if (r.titleKey.isNotEmpty()) keys.add(r.titleKey)
            out.add(r)
            if (out.size >= limit) break
        }
        return out
    }

    fun ago(deltaMs: Long): Ago {
        val minutes = deltaMs / 60_000
        return when {
            deltaMs < 0 || minutes < 1 -> Ago(AgoUnit.NOW, 0)
            minutes < 60 -> Ago(AgoUnit.MINUTES, minutes.toInt())
            minutes < 24 * 60 -> Ago(AgoUnit.HOURS, (minutes / 60).toInt())
            else -> Ago(AgoUnit.DATE, 0)
        }
    }

    /** "1,2,3" to a set; null or "all" or nothing parseable means every source. */
    fun parseIds(raw: String?): Set<Int>? {
        if (raw == null || raw.isBlank() || raw == "all") return null
        return raw.split(',').mapNotNull { it.trim().toIntOrNull() }.toSet()
    }
}
