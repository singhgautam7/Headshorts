package com.grs.news.widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/** Hosts the Flutter sources screen at `/widget/<id>`; Back is RESULT_CANCELED. */
class WidgetConfigActivity : FlutterActivity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        setResult(Activity.RESULT_CANCELED, WidgetChannel.resultIntent(widgetId))
        super.onCreate(savedInstanceState)
    }

    override fun getInitialRoute(): String = "/widget/$widgetId"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WidgetChannel.register(flutterEngine, this, onFinishConfig = { id ->
            setResult(Activity.RESULT_OK, WidgetChannel.resultIntent(id))
            finish()
            true
        })
    }
}
