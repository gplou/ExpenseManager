package com.gpm.expensemanager_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Widget 2×2 con datos del mes y 4 botones circulares:
 *   - Cabecera         : gastado / balance del mes (strings YA formateados
 *                        desde Dart vía home_widget; aquí no se formatea nada
 *                        — ver home_widget_sync_provider.dart). Oculta hasta
 *                        que la app publica datos por primera vez.
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
        val prefs = HomeWidgetPlugin.getData(context)
        val monthSpent = prefs.getString("month_spent", null)
        val balance = prefs.getString("balance", null)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.home_widget_quad)

            if (monthSpent != null && balance != null) {
                views.setViewVisibility(R.id.data_strip, View.VISIBLE)
                views.setTextViewText(R.id.txt_month_spent, monthSpent)
                views.setTextViewText(R.id.txt_balance, balance)
            } else {
                views.setViewVisibility(R.id.data_strip, View.GONE)
            }

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
