import SwiftUI
import AppIntents

@main struct ThisYouApp: App {
    @StateObject private var store = ExpenseStore()
    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .preferredColorScheme(.dark)
                .task { if ProcessInfo.processInfo.arguments.contains("--demo") { store.switchDemo(true) } }
        }
    }
}

struct ImportHDFCSMS: AppIntent {
    static var title: LocalizedStringResource = "Import HDFC SMS"
    static var description = IntentDescription("Capture a supported outgoing HDFC UPI message for your configured account. Saves locally for review; does not choose a category.")
    static var openAppWhenRun = false
    @Parameter(title: "Message") var message: String
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = try LedgerDisk.importSMS(message)
        return .result(value: result)
    }
}
struct QuickExpense: AppIntent {
    static var title: LocalizedStringResource = "Quick Expense"
    static var description = IntentDescription("Open a compact amount, category and note form. Skip if no HDFC payment was made.")
    static var openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "openQuickExpense")
        NotificationCenter.default.post(name: .quickExpense, object: nil)
        return .result()
    }
}
extension Notification.Name { static let quickExpense = Notification.Name("quickExpense") }
struct ThisYouShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: QuickExpense(), phrases: ["Add an expense in \(.applicationName)"], shortTitle: "Quick Expense", systemImageName: "plus.circle")

    }
}
