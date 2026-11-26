import SwiftUI
import UniformTypeIdentifiers

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
struct SettingsView: View {
    @ObservedObject var store: ExpenseStore
    let month: Date
    @Environment(\.dismiss) private var dismiss
    @State private var budget = ""
    @State private var carry = true
    @State private var budgetStatus = ""
    @State private var sms = ""
    @State private var importStatus = ""
    @State private var export = false
    @State private var restore = false
    @State private var document = BackupDocument(data: Data())
    @State private var pendingRestore: Ledger?
    @State private var confirmRestore = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack { Label("Tracked account", systemImage: "building.columns"); Spacer(); Text("HDFC · \(TrackedAccount.suffix)").foregroundStyle(Palette.accent) }
                    Text("Only supported outgoing UPI messages for this account are imported. Credits, OTPs and other accounts are ignored.").font(.caption).foregroundStyle(Palette.muted)
                }
                Section("Budget · \(month.formatted(.dateTime.month(.abbreviated).year()))") {
                    TextField("Monthly limit in rupees (optional)", text: $budget).keyboardType(.decimalPad)
                    Toggle("Use for following months too", isOn: $carry)
                    Button("Save budget") {
                        if budget.trimmingCharacters(in: .whitespaces).isEmpty || budget == "0" {
                            if store.setBudget(0, month: month, carry: carry) { budgetStatus = "Budget removed. Tracking continues." }
                        } else if let amount = Money.parse(budget) {
                            if store.setBudget(amount, month: month, carry: carry) { budgetStatus = "Budget saved." }
                        } else { budgetStatus = "Enter a valid positive amount, or leave blank to remove the budget." }
                    }
                    if !budgetStatus.isEmpty { Text(budgetStatus).font(.caption) }
                    Text("A spending limit, not your bank balance. Monthly history is kept automatically.").font(.caption).foregroundStyle(Palette.muted)
                }
                Section("Personality") {
                    Toggle("Roast reactions", isOn: Binding(get: { store.ledger.humour }, set: { value in _ = store.mutate { $0.humour = value } }))
                    Text("Reactions for new manual expenses above ₹1,000 or the seventh expense that day. Never shown during background SMS imports.").font(.caption).foregroundStyle(Palette.muted)
                }
                Section("Automation setup") {
                    NavigationLink("Connect GPay, PhonePe & CRED") { AutomationGuide() }
                    Text("Configure automations yourself in Apple's Shortcuts app. Installing this app does not enable them automatically.").font(.caption).foregroundStyle(Palette.muted)
                }
                Section("Test or paste an HDFC SMS") {
                    TextEditor(text: $sms).frame(minHeight: 140).font(.system(.caption, design: .monospaced)).accessibilityLabel("HDFC message text")
                    Button("Import for review") { importStatus = store.importSMS(sms) ?? "Nothing imported. Check the message." }
                    if !importStatus.isEmpty { Text(importStatus).font(.caption).foregroundStyle(Palette.accent) }
                    Button("Insert sample ₹65 message") { sms = "Sent Rs.65.00\nFrom HDFC Bank A/C *\(TrackedAccount.suffix)\nTo EXAMPLE CAFE\nOn 24/11/26\nRef 100000000001\nNot You?\nCall 18002586161/SMS BLOCK UPI to 7308080808" }
                    Text("This is fictional sample data. Import it only in demo mode unless you want a test transaction recorded.").font(.caption).foregroundStyle(Palette.muted)
                }
                Section("Your data") {
                    Button("Export full backup") {
                        do { document = BackupDocument(data: try JSONEncoder().encode(store.ledger)); export = true } catch { store.error = error.localizedDescription }
                    }
                    Button("Restore a backup…") { restore = true }
                    Text("Stored locally on this iPhone. Deleting the app can delete its data. Keep an exported backup somewhere safe.").font(.caption).foregroundStyle(Palette.muted)
                }
                Section("Preview") {
                    Toggle("Separate demo mode", isOn: Binding(get: { store.demo }, set: { enabled in store.switchDemo(enabled); updateBudget() }))
                    Text(store.demo ? "You are viewing sample data. Your personal ledger is untouched. Imports and edits here affect demo data only." : "Demo mode uses a separate ledger with sample transactions.").font(.caption).foregroundStyle(Palette.muted)
                }
            }.scrollContentBackground(.hidden).pageBackground().navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .onAppear { updateBudget() }
                .fileExporter(isPresented: $export, document: document, contentType: .json, defaultFilename: store.demo ? "this-you-demo-backup" : "this-you-backup") { result in if case .failure(let error) = result { store.error = error.localizedDescription } }
                .fileImporter(isPresented: $restore, allowedContentTypes: [.json]) { result in
                    do {
                        let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                        let data = try Data(contentsOf: url)
                        guard data.count < 20_000_000 else { throw CocoaError(.fileReadTooLarge) }
                        let value = try JSONDecoder().decode(Ledger.self, from: data)
                        let refs = value.transactions.compactMap(\.reference)
                        guard value.version == 1, Set(value.transactions.map(\.id)).count == value.transactions.count,
                              Set(refs).count == refs.count, value.transactions.allSatisfy({ $0.paise > 0 && $0.paise <= 999999999999 }),
                              value.defaultBudget >= 0, value.monthlyBudgets.values.allSatisfy({ $0 >= 0 }) else { throw CocoaError(.fileReadCorruptFile) }
                        pendingRestore = value; confirmRestore = true
                    } catch { store.error = "Could not restore: \(error.localizedDescription)" }
                }
                .confirmationDialog("Replace \(store.demo ? "demo" : "personal") ledger with this backup?", isPresented: $confirmRestore, titleVisibility: .visible) {
                    Button("Replace with \(pendingRestore?.transactions.count ?? 0) transactions", role: .destructive) {
                        if let value = pendingRestore { _ = store.mutate { $0 = value }; updateBudget() }; pendingRestore = nil
                    }
                    Button("Cancel", role: .cancel) { pendingRestore = nil }
                } message: { Text("This replaces the current ledger, including notes, categories and budgets. Export your current data first if you need to keep it.") }
        }.tint(Palette.accent)
    }
    private func updateBudget() { let value = store.budget(in: month); budget = value > 0 ? Money.input(value) : "" }

}

struct AutomationGuide: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                Label("Set up once. Test on your phone.", systemImage: "bolt").font(.headline).foregroundStyle(Palette.accent)
                guide("01", "Payment app → simple reminder", "In Shortcuts, edit your App → Is Closed automation for GPay, PhonePe and CRED. Keep Run Immediately. Remove Show Expense Roast and any old Open App action.\n\nAdd Apple’s Show Alert action first: title Record expense, message Ready to record your expense? Expand its options and turn Show Cancel Button off. Then add Expense Roast → Quick Expense immediately below it.\n\nThe alert has one Done button. Tapping Done continues to Quick Expense, which opens the entry form. Do not put Quick Expense before the alert. Leaving a payment app does not prove a payment happened. This setup requires the phone to be unlocked for interaction.")
                guide("02", "HDFC message → review inbox", "Create a Message automation matching ‘From HDFC Bank A/C *\(TrackedAccount.suffix)’. Choose Run Immediately. Add Expense Roast → Import HDFC SMS and pass the incoming message’s text (Shortcut Input → Content) into Message.\n\nThe parser validates the full outgoing payment format and ignores duplicate reference numbers. No category is guessed.")
                guide("03", "Check the complete loop", "Make a small HDFC payment, leave the UPI app, then confirm the incoming SMS appears in Transactions. If the SMS arrived first, skip manual entry and categorise it there. If you entered it first, open the SMS transaction and link the matching manual record.\n\nSMS dates do not include a payment time, so matching stays under your control.")
                guide("04", "Simulator limitations", "The simulator can test manual entry, pasted SMS imports, duplicates, categories, notes, dates, charts and persistence. Real incoming SMS, payment-app switching and locked-phone behaviour must be verified on the iPhone.\n\nUI actions may require unlocking. Background import may require the device to have been unlocked once after restart. Do not delete this app to update it—install over it and keep backups.")
            }.padding(24)
        }.pageBackground().navigationTitle("Shortcuts setup").navigationBarTitleDisplayMode(.inline)
    }
    private func guide(_ number: String, _ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(number).font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.accent)
            Text(title).font(.title3.weight(.semibold))
            Text(text).font(.subheadline).foregroundStyle(Palette.muted).lineSpacing(5)
        }.frame(maxWidth: .infinity, alignment: .leading).panel()
    }
}
