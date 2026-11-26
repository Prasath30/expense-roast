import SwiftUI

struct EntryEditor: View {
    @ObservedObject var store: ExpenseStore
    let entry: Transaction?
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var merchant = ""
    @State private var category = ExpenseCategory.uncategorised
    @State private var note = ""
    @State private var date = Date()
    @State private var kind = EntryKind.expense
    @State private var validation = ""
    @State private var roast: ExpenseReaction?
    @State private var saved = false
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 7) {
                        Image(systemName: "building.columns").font(.system(size: 12))
                        Text("HDFC Bank · \(TrackedAccount.suffix)").font(.system(size: 13))
                        Spacer()
                        if entry?.bankConfirmed == true { Text("From SMS").font(.system(size: 11)) }
                    }.foregroundStyle(Palette.muted)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount").font(.system(size: 13)).foregroundStyle(Palette.muted)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("₹").font(.system(size: 29, weight: .regular)).foregroundStyle(Palette.muted)
                            TextField("0", text: $amount).keyboardType(.decimalPad)
                                .font(.system(size: 46, weight: .regular)).tracking(-1).accessibilityLabel("Amount in rupees")
                        }
                    }.padding(.vertical, 6)
                    Picker("Transaction type", selection: $kind) { ForEach(EntryKind.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category").font(.system(size: 15, weight: .semibold))
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(ExpenseCategory.allCases) { cat in
                                Button { category = cat } label: {
                                    HStack(spacing: 9) {
                                        Image(systemName: cat.symbol).font(.system(size: 14)).frame(width: 18)
                                        Text(cat == .uncategorised ? "Decide later" : cat.rawValue).font(.system(size: 12, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
                                        Spacer(minLength: 0)
                                        if category == cat { Image(systemName: "checkmark").font(.system(size: 10, weight: .semibold)) }
                                    }.padding(.horizontal, 12).frame(height: 46)
                                        .foregroundStyle(category == cat ? Palette.accent : Palette.muted)
                                        .background(category == cat ? Palette.accent.opacity(0.07) : Palette.card, in: RoundedRectangle(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(category == cat ? Palette.accent.opacity(0.45) : .clear, lineWidth: 1))
                                }.buttonStyle(.plain).accessibilityAddTraits(category == cat ? .isSelected : [])
                            }
                        }
                    }
                    VStack(spacing: 16) {
                        TextField("Merchant or title", text: $merchant).font(.system(size: 14))
                        Divider()
                        TextField("Note (optional)", text: $note, axis: .vertical).font(.system(size: 14)).lineLimit(2...3)
                        Divider()
                        DatePicker("Date", selection: $date, displayedComponents: .date).font(.system(size: 14))
                    }.panel()
                    if !validation.isEmpty { Text(validation).font(.system(size: 12)).foregroundStyle(Palette.coral) }
                    if kind == .transfer { Text("Excluded from spending totals.").font(.system(size: 12)).foregroundStyle(Palette.muted) }
                    else if category == .uncategorised { Text("You can categorise this later in Review.").font(.system(size: 12)).foregroundStyle(Palette.muted) }
                }.padding(22)
            }.scrollDismissesKeyboard(.interactively).pageBackground()
                .safeAreaInset(edge: .bottom) {
                    if !saved {
                        Button(action: save) {
                            Text(entry == nil ? "Save expense" : "Save changes").font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(Palette.accent, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(Palette.background)
                        }.padding(.horizontal, 22).padding(.vertical, 12).background(Palette.background)
                    }
                }
                .navigationTitle(entry == nil ? "New expense" : "Edit transaction").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(entry == nil ? "Skip" : "Cancel") { dismiss() }.foregroundStyle(Palette.muted) } }
                .interactiveDismissDisabled(saved)
                .sheet(item: $roast, onDismiss: {
                    // Dismiss the editor only after its reaction sheet has finished closing.
                    if saved { dismiss() }
                }) { reaction in
                    RoastScene(reaction: reaction) { roast = nil }
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.hidden)
                        .interactiveDismissDisabled()
                }
                .onAppear {
                    if let entry { amount = Money.input(entry.paise); merchant = entry.merchant; category = entry.category; note = entry.note; date = entry.date; kind = entry.kind }
                }
        }.tint(Palette.accent)
    }
    private func save() {
        guard !saved else { return }
        guard let value = Money.parse(amount) else { validation = "Enter a valid amount greater than zero, with up to two decimal places."; return }
        var result = entry ?? Transaction(paise: value, merchant: "", date: date)
        result.paise = value; result.merchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines); result.category = category; result.note = note; result.date = date; result.kind = kind
        result.needsReview = category == .uncategorised && kind == .expense
        guard store.save(result) else { return }
        saved = true
        let count = store.ledger.transactions.filter { $0.kind == .expense && Dates.sameDay($0.date, date) }.count
        if entry == nil && kind == .expense && store.ledger.humour {
            if value > 100000 { roast = .bigSpend }
            else if count == 7 { roast = .busyDay }
            else { dismiss() }
        } else { dismiss() }
    }
}

enum ExpenseReaction: String, Identifiable {
    case bigSpend, busyDay
    var id: String { rawValue }
}

struct RoastScene: View {
    let reaction: ExpenseReaction
    var done: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Text("Expense saved").eyebrow().foregroundStyle(Palette.accent)
            if reaction == .bigSpend {
                Image("SabashReaction").resizable().scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Samuthirakani applauding sarcastically")
                Text("sabash beta sabash")
                    .font(.system(size: 27, weight: .semibold)).multilineTextAlignment(.center)
            } else {
                Text("7 payments today.\n\nProve you are not funding the entire economy.")
                    .font(.title2.weight(.semibold)).multilineTextAlignment(.center)
            }
            Button(action: done) {
                Text("Done").font(.headline)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Palette.accent, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(Palette.background)
            .accessibilityIdentifier("dismissExpenseReaction")
        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.background.ignoresSafeArea())
    }
}

struct EntryDetail: View {
    @ObservedObject var store: ExpenseStore
    let entryID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var edit = false
    @State private var delete = false
    @State private var confirmMerge: Transaction?
    private var entry: Transaction? { store.ledger.transactions.first { $0.id == entryID } }
    var body: some View {
        Group {
            if let entry {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Image(systemName: entry.category.symbol).font(.system(size: 30)).foregroundStyle(entry.category.color).padding(20).background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
                        Text(Money.display(entry.paise)).font(.system(size: 38, weight: .regular))
                        Text(entry.merchant.isEmpty ? entry.category.rawValue : entry.merchant).font(.title2.weight(.semibold))
                        VStack(spacing: 18) {
                            detail("Category", entry.category.rawValue)
                            detail("Type", entry.kind.rawValue)
                            detail("Date", entry.date.formatted(date: .abbreviated, time: .omitted))
                            detail("Account", "HDFC · \(TrackedAccount.suffix)")
                            detail("Source", entry.bankConfirmed ? "HDFC SMS" : "Manual entry")
                            if let reference = entry.reference { detail("Reference", reference) }
                            if !entry.note.isEmpty { VStack(alignment: .leading, spacing: 9) { Text("Note").foregroundStyle(Palette.muted); Text(entry.note).frame(maxWidth: .infinity, alignment: .leading) }.font(.subheadline) }
                        }.panel()
                        let candidates = store.candidates(for: entry)
                        if !candidates.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                Label("Possible duplicate", systemImage: "square.on.square").font(.headline).foregroundStyle(Palette.accent)
                                Text("Same amount and day as a manual entry. Both currently count. Link only if this is the same payment.").font(.caption).foregroundStyle(Palette.muted)
                                ForEach(candidates) { candidate in Button { confirmMerge = candidate } label: { VStack(alignment: .leading, spacing: 4) { Text("Link to \(candidate.merchant.isEmpty ? candidate.category.rawValue : candidate.merchant)"); Text(candidate.note.isEmpty ? Money.display(candidate.paise) : candidate.note).font(.caption).foregroundStyle(Palette.muted) } }.buttonStyle(.bordered) }
                            }.panel()
                        }
                        Button { edit = true } label: { Text(entry.needsReview ? "Review & categorise" : "Edit transaction").font(.headline).frame(maxWidth: .infinity).padding(18).background(Palette.accent, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(Palette.background) }
                        if entry.needsReview && entry.category != .uncategorised {
                            Button("Mark reviewed") { var updated = entry; updated.needsReview = false; _ = store.save(updated) }
                        }
                        Button("Delete transaction", role: .destructive) { delete = true }.font(.subheadline).frame(maxWidth: .infinity)
                    }.padding(24)
                }.sheet(isPresented: $edit) { EntryEditor(store: store, entry: entry) }
                    .confirmationDialog("Delete this transaction?", isPresented: $delete, titleVisibility: .visible) { Button("Delete", role: .destructive) { if store.remove(entry) { dismiss() } } } message: { Text("Export a backup first if you may need to restore it. Re-importing the same SMS will not bring it back.") }
                    .confirmationDialog("Link these as one payment?", isPresented: Binding(get: { confirmMerge != nil }, set: { if !$0 { confirmMerge = nil } }), titleVisibility: .visible) {
                        if let manual = confirmMerge { Button("Link and keep manual category & note") { if store.merge(sms: entry, manual: manual) { dismiss() }; confirmMerge = nil } }
                    } message: { Text("The SMS record will be combined with your manual entry. Its category, note and date will be preserved.") }
            } else { EmptyLedger(title: "Transaction unavailable.", detail: "It may have been linked to another entry or deleted.") }
        }.scrollDismissesKeyboard(.interactively).pageBackground().navigationTitle("Transaction").navigationBarTitleDisplayMode(.inline)
    }
    private func detail(_ label: String, _ value: String) -> some View { HStack(alignment: .top) { Text(label).foregroundStyle(Palette.muted); Spacer(); Text(value).multilineTextAlignment(.trailing) }.font(.subheadline) }
}
