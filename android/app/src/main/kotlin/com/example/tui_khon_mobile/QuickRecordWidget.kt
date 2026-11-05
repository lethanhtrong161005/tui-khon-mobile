package com.example.tui_khon_mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews

/** Action-only widget: never reads accounts, tokens or the notebook database. */
class QuickRecordWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { render(context, manager, it) }
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager,
        appWidgetId: Int, newOptions: Bundle) {
        render(context, manager, appWidgetId)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == Intent.ACTION_CONFIGURATION_CHANGED ||
            intent.action == Intent.ACTION_LOCALE_CHANGED) updateAll(context)
    }

    companion object {
        const val EXTRA_ACTION = "com.example.tui_khon_mobile.WIDGET_ACTION"
        val ACTIONS = setOf("expense", "income", "quickRecord", "scanReceipt")
        private const val PREFS = "home_widget_appearance"

        fun updateAppearance(context: Context, values: Map<*, *>?) {
            if (values == null) return
            // Only presentation strings and theme choices are accepted.
            val editor = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            val labelKeys = listOf("title", "expense", "income", "quickRecord", "scanReceipt")
            val keys = listOf("theme", "language") + labelKeys +
                listOf("vi", "en").flatMap { lang -> labelKeys.map { "${lang}_$it" } }
            for (key in keys) {
                (values[key] as? String)?.let { editor.putString(key, it) }
            }
            editor.apply()
            updateAll(context)
        }

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            manager.getAppWidgetIds(ComponentName(context, QuickRecordWidget::class.java))
                .forEach { render(context, manager, it) }
        }

        private fun render(context: Context, manager: AppWidgetManager, id: Int) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val systemDark = context.resources.configuration.uiMode and
                Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
            val dark = when (prefs.getString("theme", "system")) {
                "dark" -> true
                "light" -> false
                else -> systemDark
            }
            val followsSystem = prefs.getString("theme", "system") == "system"
            val layout = if (followsSystem) R.layout.quick_record_widget else if (dark)
                R.layout.quick_record_widget_dark else R.layout.quick_record_widget_light
            val views = RemoteViews(context.packageName, layout)
            val systemLanguage = prefs.getString("language", "vi") == "system"
            val language = when (prefs.getString("language", "vi")) {
                "system" -> if (context.resources.configuration.locales[0].language == "en") "en" else "vi"
                "en" -> "en"
                else -> "vi"
            }
            fun label(key: String, fallback: Int): String =
                prefs.getString("${language}_$key", prefs.getString(key, context.getString(fallback)))!!
            val color = context.getColor(if (dark) R.color.widget_on_surface_dark else R.color.widget_on_surface_light)
            if (!systemLanguage) views.setTextViewText(R.id.widget_title, label("title", R.string.widget_title))
            if (!followsSystem) views.setTextColor(R.id.widget_title, color)
            // Prioritize action labels at large accessibility font sizes.
            views.setViewVisibility(R.id.widget_title,
                if (context.resources.configuration.fontScale >= 1.5f) View.GONE else View.VISIBLE)
            for ((index, item) in listOf(
                Triple(R.id.widget_expense_action, R.id.widget_expense, "expense"),
                Triple(R.id.widget_scan_action, R.id.widget_scan, "scanReceipt"),
                Triple(R.id.widget_income_action, R.id.widget_income, "income")).withIndex()) {
                val (actionId, viewId, action) = item
                val fallback = when (action) {
                    "income" -> R.string.widget_income
                    "expense" -> R.string.widget_expense
                    else -> R.string.widget_scan
                }
                if (!systemLanguage) views.setTextViewText(viewId, label(action, fallback))
                if (!followsSystem) views.setTextColor(viewId, color)
                val iconId = when (action) {
                    "expense" -> R.id.widget_expense_icon
                    "income" -> R.id.widget_income_icon
                    else -> R.id.widget_scan_icon
                }
                if (!followsSystem) views.setInt(iconId, "setColorFilter",
                    context.getColor(if (dark) R.color.widget_accent_dark else R.color.widget_accent_light))
                val launch = Intent(context, MainActivity::class.java)
                    .setAction("${context.packageName}.widget.$action")
                    .putExtra(EXTRA_ACTION, action)
                    // Reuse the existing Flutter Activity even when a native
                    // camera/account chooser is currently above it. Flutter
                    // routes and their drafts remain in the same engine.
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                val pending = PendingIntent.getActivity(context, index, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                views.setOnClickPendingIntent(actionId, pending)
            }
            manager.updateAppWidget(id, views)
        }
    }
}
