package com.gpm.expensemanager_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/**
 * Widget 2×2 con 4 botones circulares:
 *   - Arriba izquierda : añadir transacción manual  → expensemanager://widget/add
 *   - Arriba derecha   : chat IA                    → expensemanager://widget/chat
 *   - Abajo izquierda  : transacción por voz        → expensemanager://widget/voice
 *   - Abajo derecha    : transacción por foto        → expensemanager://widget/photo
 */
class QuadWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.home_widget_quad)

            views.setOnClickPendingIntent(
                R.id.btn_add,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("expensemanager://widget/add"),
                ),
            )

            views.setOnClickPendingIntent(
                R.id.btn_chat,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("expensemanager://widget/chat"),
                ),
            )

            views.setOnClickPendingIntent(
                R.id.btn_voice,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("expensemanager://widget/voice"),
                ),
            )

            views.setOnClickPendingIntent(
                R.id.btn_camera,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("expensemanager://widget/photo"),
                ),
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
