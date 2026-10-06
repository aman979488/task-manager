package com.example.task_manager

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class TaskManagerWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.task_manager_widget).apply {
                val pendingCount = widgetData.getInt("pending_count", 0)
                val hasLoadedTasks = widgetData.getBoolean("has_loaded_tasks", false)
                setTextViewText(
                    R.id.task_widget_summary,
                    if (hasLoadedTasks) {
                        context.resources.getQuantityString(
                            R.plurals.task_widget_pending_count,
                            pendingCount,
                            pendingCount,
                        )
                    } else {
                        context.getString(R.string.task_widget_default_summary)
                    },
                )
                setTextViewText(
                    R.id.task_widget_empty,
                    context.getString(
                        if (!hasLoadedTasks) {
                            R.string.task_widget_no_tasks_loaded
                        } else if (pendingCount == 0) {
                            R.string.task_widget_all_caught_up
                        } else {
                            R.string.task_widget_no_tasks_loaded
                        },
                    ),
                )
                setViewVisibility(
                    R.id.task_widget_empty,
                    if (pendingCount == 0) View.VISIBLE else View.GONE,
                )

                var visibleTaskCount = 0
                val taskViews = intArrayOf(
                    R.id.task_widget_task_0,
                    R.id.task_widget_task_1,
                    R.id.task_widget_task_2,
                )
                taskViews.forEachIndexed { index, viewId ->
                    val taskTitle = widgetData.getString("task_$index", null)
                    if (!taskTitle.isNullOrBlank()) {
                        setTextViewText(viewId, "\u2022  $taskTitle")
                        setViewVisibility(viewId, View.VISIBLE)
                        visibleTaskCount++
                    } else {
                        setViewVisibility(viewId, View.GONE)
                    }
                }
                setViewVisibility(
                    R.id.task_widget_empty,
                    if (visibleTaskCount == 0) View.VISIBLE else View.GONE,
                )
                setOnClickPendingIntent(
                    R.id.task_widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
