//  ExpenseManagerWidget.swift
//
//  Widget de pantalla de inicio (Plan 3 — A7). Muestra el gasto y el balance
//  del mes que la app publica vía home_widget (UserDefaults del App Group);
//  los strings llegan YA formateados desde Dart (home_widget_sync_provider.dart)
//  — aquí no se formatea divisa ni números, igual que en Android.
//
//  Este archivo NO está añadido todavía al proyecto Xcode: sigue los pasos de
//  ios/ExpenseManagerWidget/README.md para crear el target.

import SwiftUI
import WidgetKit

private let appGroupId = "group.com.gpm.expensemanagerapp"
private let widgetKind = "ExpenseManagerWidget" // debe coincidir con iOSName en home_widget_gateway.dart

// MARK: - Timeline

struct ExpenseEntry: TimelineEntry {
    let date: Date
    let monthSpent: String?
    let balance: String?

    var hasData: Bool { monthSpent != nil && balance != nil }
}

struct ExpenseProvider: TimelineProvider {
    func placeholder(in context: Context) -> ExpenseEntry {
        ExpenseEntry(date: Date(), monthSpent: "€250.50", balance: "€749.50")
    }

    func getSnapshot(in context: Context, completion: @escaping (ExpenseEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ExpenseEntry>) -> Void) {
        // La app fuerza el repintado tras cada CRUD/sync (HomeWidget.updateWidget),
        // así que no hace falta timeline propio.
        completion(Timeline(entries: [load()], policy: .never))
    }

    private func load() -> ExpenseEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        return ExpenseEntry(
            date: Date(),
            monthSpent: defaults?.string(forKey: "month_spent"),
            balance: defaults?.string(forKey: "balance")
        )
    }
}

// MARK: - View

struct ExpenseWidgetView: View {
    let entry: ExpenseEntry

    var body: some View {
        content
            // Abre la app en añadir transacción (mismo deep link que Android).
            .widgetURL(URL(string: "expensemanager://widget/add"))
    }

    @ViewBuilder
    private var content: some View {
        if entry.hasData {
            HStack(spacing: 12) {
                column(label: "Gastado", value: entry.monthSpent ?? "—")
                Divider()
                column(label: "Balance", value: entry.balance ?? "—")
            }
            .padding()
        } else {
            VStack(spacing: 6) {
                Image(systemName: "banknote")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Abre la app para ver tus datos")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }

    private func column(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Widget

struct ExpenseManagerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: widgetKind, provider: ExpenseProvider()) { entry in
            if #available(iOS 17.0, *) {
                ExpenseWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                ExpenseWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Resumen del mes")
        .description("Gasto y balance del mes actual.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct ExpenseManagerWidgetBundle: WidgetBundle {
    var body: some Widget {
        ExpenseManagerWidget()
    }
}
