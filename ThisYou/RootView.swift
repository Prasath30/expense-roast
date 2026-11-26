import SwiftUI
import Charts

struct RootView: View {
    @ObservedObject var store: ExpenseStore
    @Environment(\.scenePhase) private var phase
    @State private var tab: Int
    @State private var month = Date()
    @State private var quick = false
    @State private var quickCandidate: Transaction?
    @State private var settings = false
    @State private var quickAfterSettings = false
    @State private var reviewOnly = false

    init(store: ExpenseStore, initialTab: Int = 0) {
        self.store = store
        _tab = State(initialValue: initialTab)
    }
    var body: some View {
        Group {
            switch tab {
            case 1: NavigationStack { LedgerView(store: store, month: $month, reviewOnly: $reviewOnly) }
            case 2: NavigationStack { InsightsView(store: store, month: $month) }
            default: NavigationStack { home }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Rectangle().fill(Palette.line).frame(height: 0.5)
                HStack(spacing: 0) {
                    tabButton("Overview", symbol: "square.grid.2x2", index: 0)
                    tabButton("Transactions", symbol: "list.bullet.rectangle", index: 1)
                    tabButton("Insights", symbol: "chart.pie", index: 2)
                }.padding(.top, 10).padding(.bottom, 5)
            }.background(Palette.background)
        }.tint(Palette.accent)
        .sheet(isPresented: $quick) { EntryEditor(store: store, entry: quickCandidate) }
        .sheet(isPresented: $settings, onDismiss: {
            if quickAfterSettings { quickAfterSettings = false; quick = true }
        }) { SettingsView(store: store, month: month) }
        .alert("Something needs attention", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("OK") { store.error = nil } } message: { Text(store.error ?? "") }
        .onChange(of: phase) { _, value in if value == .active { store.reload(); consumeQuickEntry() } }
        .onReceive(NotificationCenter.default.publisher(for: .quickExpense)) { _ in consumeQuickEntry() }
        .onOpenURL { url in if url.scheme == "thisyou", url.host == "add" { quickCandidate = nil; quick = true } }
        .task { consumeQuickEntry() }
    }
    private func tabButton(_ title: String, symbol: String, index: Int) -> some View {
        Button { tab = index } label: {
            VStack(spacing: 6) {
                Image(systemName: tab == index ? symbol + ".fill" : symbol).font(.system(size: 20, weight: tab == index ? .semibold : .regular))
                Text(title).font(.system(size: 10, weight: .medium))
            }.foregroundStyle(tab == index ? Palette.accent : Palette.faint)
                .frame(maxWidth: .infinity).frame(height: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityAddTraits(tab == index ? .isSelected : [])
    }
    private func consumeQuickEntry() {
        if UserDefaults.standard.bool(forKey: "openQuickExpense") {
            UserDefaults.standard.set(false, forKey: "openQuickExpense")
            store.reload()
            let recent = store.ledger.transactions.filter { $0.bankConfirmed && $0.requiresReview && $0.createdAt > Date().addingTimeInterval(-300) && Dates.sameDay($0.date, Date()) }
            quickCandidate = recent.count == 1 ? recent[0] : nil
            if settings { quickAfterSettings = true; settings = false }
            else { quick = true }
        }
    }
    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PageHeading(title: "Overview") {
                    HStack(spacing: 6) {
                        ToolbarIcon(symbol: "gearshape") { settings = true }.accessibilityLabel("Settings and backup")
                        ToolbarIcon(symbol: "plus", primary: true) { quickCandidate = nil; quick = true }.accessibilityLabel("Add expense")
                    }
                }
                HStack(spacing: 6) {
                    Image(systemName: "building.columns").font(.system(size: 11))
                    Text("HDFC Bank · \(TrackedAccount.suffix)").font(.system(size: 12))
                    if store.demo { Text("· Demo").font(.system(size: 12)) }
                }.foregroundStyle(Palette.muted).padding(.top, 8).padding(.bottom, 22)
                MonthPicker(month: $month)
                spendingSummary.padding(.top, 10).padding(.bottom, 20)
                activitySummary.padding(.bottom, 26)
                if store.reviewCount > 0 {
                    Button { reviewOnly = true; tab = 1 } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "tray").font(.system(size: 17)).foregroundStyle(Palette.accent).frame(width: 35, height: 35).background(Palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(store.reviewCount) \(store.reviewCount == 1 ? "transaction" : "transactions") to review").font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.ink)
                                Text("Add a category or check a transfer").font(.system(size: 12)).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.faint)
                        }.padding(15).background(Palette.card, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.accent.opacity(0.12), lineWidth: 1))
                    }.buttonStyle(.plain).padding(.bottom, 28)
                }
                HStack {
                    SectionHeading(title: "Recent transactions")
                    Spacer()
                    Button("See all") { reviewOnly = false; tab = 1 }.font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.muted)
                }.padding(.bottom, 8)
                if store.entries(in: month).isEmpty { EmptyLedger() }
                else {
                    VStack(spacing: 0) {
                        ForEach(store.entries(in: month).prefix(6)) { entry in
                            NavigationLink { EntryDetail(store: store, entryID: entry.id) } label: { TransactionRow(entry: entry) }.buttonStyle(.plain)
                            Rectangle().fill(Palette.line).frame(height: 0.5).padding(.leading, 48)
                        }
                    }
                }
            }.padding(.horizontal, 22).padding(.bottom, 28)
        }.scrollDismissesKeyboard(.interactively).pageBackground().toolbar(.hidden, for: .navigationBar)
    }
    private var spendingSummary: some View {
        let budget = store.budget(in: month)
        let spent = store.spent(in: month)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Spent this month").font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.75))
                Spacer()
                if budget > 0 {
                    Text(String(format: "%.1f%% of budget", max(0, Double(spent) / Double(budget) * 100)))
                        .font(.system(size: 10, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(spent > budget ? Palette.coral : Color(hex: 0xBCD4F9))
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .background(.white.opacity(0.07), in: Capsule())
                } else { Image(systemName: "creditcard").foregroundStyle(.white.opacity(0.6)) }
            }
            Text(Money.display(spent))
                .font(.system(size: 46, weight: .medium)).tracking(-1.8).monospacedDigit()
                .foregroundStyle(.white).minimumScaleFactor(0.6).lineLimit(1).padding(.top, 13)
            if budget > 0 {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.12))
                        Capsule().fill(spent > budget ? Palette.coral : Color(hex: 0xA9CCFC))
                            .frame(width: g.size.width * min(max(Double(spent) / Double(budget), 0), 1))
                    }
                }.frame(height: 5).padding(.top, 24).padding(.bottom, 20)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(spent > budget ? "Over budget" : "Left to spend").font(.system(size: 11)).foregroundStyle(.white.opacity(0.65))
                        Text(Money.display(abs(budget - spent))).font(.system(size: 18, weight: .semibold)).foregroundStyle(spent > budget ? Palette.coral : .white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("Monthly budget").font(.system(size: 11)).foregroundStyle(.white.opacity(0.65))
                        Button(Money.display(budget)) { settings = true }.font(.system(size: 18, weight: .medium)).foregroundStyle(.white.opacity(0.9))
                    }
                }
            } else {
                Button { settings = true } label: { Label("Set a monthly budget", systemImage: "plus.circle").font(.system(size: 13)).foregroundStyle(Color(hex: 0xBCD4F9)) }.padding(.top, 22)
            }
        }.padding(22)
            .background(LinearGradient(colors: [Color(hex: 0x293F5B), Color(hex: 0x1C2A3C)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.10), lineWidth: 0.7))
    }
    private var activitySummary: some View {
        let entries = store.entries(in: month)
        let today = store.ledger.transactions.filter { Dates.sameDay($0.date, Date()) }
        let todaySpent = today.reduce(Int64(0)) { $0 + ($1.kind == .expense ? $1.paise : $1.kind == .refund ? -$1.paise : 0) }
        return HStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "sun.max").font(.system(size: 17)).foregroundStyle(Color(hex: 0xD5BE7C))
                VStack(alignment: .leading, spacing: 5) {
                    Text("Today").font(.system(size: 11)).foregroundStyle(Palette.muted)
                    Text(Money.display(todaySpent)).font(.system(size: 17, weight: .semibold)).monospacedDigit()
                }
                Spacer(minLength: 0)
            }
            Rectangle().fill(Palette.line).frame(width: 1, height: 32)
            HStack(spacing: 10) {
                Image(systemName: "arrow.up.right").font(.system(size: 17)).foregroundStyle(Palette.accent)
                VStack(alignment: .leading, spacing: 5) {
                    Text("This month").font(.system(size: 11)).foregroundStyle(Palette.muted)
                    Text("\(entries.count) \(entries.count == 1 ? "transaction" : "transactions")").font(.system(size: 14, weight: .medium))
                }
                Spacer(minLength: 0)
            }
        }.padding(.horizontal, 4)
    }

}

struct LedgerView: View {
    @ObservedObject var store: ExpenseStore
    @Binding var month: Date
    @Binding var reviewOnly: Bool
    @State private var search = ""
    @State private var exactDay = false
    @State private var day = Date()
    @State private var category: ExpenseCategory?
    @State private var filters = false
    @State private var add = false
    private var filtered: [Transaction] {
        store.ledger.transactions.filter { entry in
            let period = exactDay ? Dates.sameDay(entry.date, day) : Dates.monthKey(entry.date) == Dates.monthKey(month)
            let match = search.isEmpty || [entry.merchant, entry.note, entry.category.rawValue, entry.reference ?? "", Money.input(entry.paise), entry.date.formatted(date: .numeric, time: .omitted)].joined(separator: " ").localizedCaseInsensitiveContains(search)
            return period && match && (category == nil || entry.category == category) && (!reviewOnly || entry.requiresReview)
        }.sorted { $0.date == $1.date ? $0.createdAt > $1.createdAt : $0.date > $1.date }
    }
    private var days: [Date] { Array(Set(filtered.map { Dates.calendar.startOfDay(for: $0.date) })).sorted(by: >) }
    private var net: Int64 { filtered.reduce(0) { $0 + ($1.kind == .expense ? $1.paise : $1.kind == .refund ? -$1.paise : 0) } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PageHeading(title: "Transactions") { ToolbarIcon(symbol: "plus", primary: true) { add = true }.accessibilityLabel("Add expense") }
                MonthPicker(month: $month).padding(.top, 13)
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundStyle(Palette.faint)
                    TextField("Search transactions", text: $search).font(.system(size: 14))
                    if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.muted) }.accessibilityLabel("Clear search") }
                }.padding(12).background(Palette.card, in: RoundedRectangle(cornerRadius: 10)).padding(.top, 12)
                HStack(spacing: 8) {
                    Menu {
                        Button("All transactions") { reviewOnly = false }
                        Button("Needs review") { reviewOnly = true }
                    } label: {
                        HStack(spacing: 6) {
                            if reviewOnly { Circle().fill(Palette.accent).frame(width: 5, height: 5) }
                            Text(reviewOnly ? "Needs review" : "All transactions")
                            Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                        }.font(.system(size: 12, weight: .medium)).foregroundStyle(reviewOnly ? Palette.accent : Palette.muted)
                            .padding(.vertical, 10).padding(.horizontal, 12).background(Palette.card, in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                    Spacer()
                    Button { filters = true } label: {
                        Label(exactDay ? day.formatted(.dateTime.day().month(.abbreviated)) : category?.rawValue ?? "Filter", systemImage: "line.3.horizontal.decrease")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.muted).padding(.vertical, 10).padding(.horizontal, 12)
                            .background(Palette.card, in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }.padding(.top, 10)
                HStack {
                    Text("\(filtered.count) \(filtered.count == 1 ? "transaction" : "transactions")").font(.system(size: 12)).foregroundStyle(Palette.muted)
                    Spacer()
                    Text(Money.display(net)).font(.system(size: 14, weight: .medium)).monospacedDigit()
                }.padding(.vertical, 20)
                if filtered.isEmpty { EmptyLedger(title: "No matching transactions", detail: "Try another date, category or search.") }
                LazyVStack(spacing: 22) {
                    ForEach(days, id: \.self) { date in
                        let entries = filtered.filter { Dates.sameDay($0.date, date) }
                        VStack(spacing: 0) {
                            HStack {
                                Text(dayTitle(date))
                                Spacer()
                                Text(Money.display(entries.reduce(0) { $0 + ($1.kind == .expense ? $1.paise : $1.kind == .refund ? -$1.paise : 0) })).monospacedDigit()
                            }.font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.muted).padding(.bottom, 5)
                            ForEach(entries) { entry in
                                NavigationLink { EntryDetail(store: store, entryID: entry.id) } label: { TransactionRow(entry: entry) }.buttonStyle(.plain)
                                Rectangle().fill(Palette.line).frame(height: 0.5).padding(.leading, 48)
                            }
                        }
                    }
                }
            }.padding(.horizontal, 22).padding(.bottom, 28)
        }.scrollDismissesKeyboard(.interactively).pageBackground().toolbar(.hidden, for: .navigationBar)
        .onChange(of: month) { _, _ in exactDay = false }
        .sheet(isPresented: $add) { EntryEditor(store: store, entry: nil) }
        .sheet(isPresented: $filters) {
            NavigationStack {
                Form {
                    Toggle("Filter a specific day", isOn: $exactDay)
                    if exactDay { DatePicker("Date", selection: $day, displayedComponents: .date) }
                    Picker("Category", selection: $category) { Text("All categories").tag(nil as ExpenseCategory?); ForEach(ExpenseCategory.allCases) { Text($0.rawValue).tag(Optional($0)) } }
                    Button("Clear filters") { exactDay = false; category = nil; reviewOnly = false; search = "" }
                }.navigationTitle("Filter transactions").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { filters = false } } }
            }.tint(Palette.accent).presentationDetents([.medium, .large])
        }
    }
    private func dayTitle(_ date: Date) -> String {
        if Dates.sameDay(date, Date()) { return "Today · " + date.formatted(.dateTime.day().month(.abbreviated)) }
        if let yesterday = Dates.calendar.date(byAdding: .day, value: -1, to: Date()), Dates.sameDay(date, yesterday) { return "Yesterday · " + date.formatted(.dateTime.day().month(.abbreviated)) }
        return date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }
}

struct InsightsView: View {
    @ObservedObject var store: ExpenseStore
    @Binding var month: Date
    private var slices: [(category: ExpenseCategory, amount: Int64)] {
        ExpenseCategory.allCases.compactMap { cat in
            let amount = store.entries(in: month).filter { $0.category == cat && $0.kind == .expense }.reduce(Int64(0)) { $0 + $1.paise }
            return amount > 0 ? (cat, amount) : nil
        }.sorted { $0.amount > $1.amount }
    }
    private var gross: Int64 { slices.reduce(0) { $0 + $1.amount } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PageHeading(title: "Insights") { EmptyView() }
                MonthPicker(month: $month).padding(.top, 13)
                if slices.isEmpty { EmptyLedger(title: "No spending to show", detail: "A category breakdown appears when you add expenses.") }
                else {
                    Chart(slices, id: \.category) { item in
                        SectorMark(angle: .value("Spent", Double(item.amount)), innerRadius: .ratio(0.83), angularInset: 0.6).cornerRadius(2).foregroundStyle(item.category.color)
                    }.frame(height: 210).chartLegend(.hidden)
                        .chartBackground { _ in
                            VStack(spacing: 7) {
                                Text("Total expenses").font(.system(size: 12)).foregroundStyle(Palette.muted)
                                Text(Money.display(gross)).font(.system(size: 25, weight: .medium)).tracking(-0.7).monospacedDigit().minimumScaleFactor(0.6)
                            }
                        }.accessibilityLabel("Category spending. Total expenses \(Money.display(gross)). Category amounts follow.")
                        .padding(.vertical, 24)
                    SectionHeading(title: "By category").padding(.top, 4).padding(.bottom, 16)
                    VStack(spacing: 20) {
                        ForEach(slices, id: \.category) { item in
                            VStack(spacing: 9) {
                                HStack(spacing: 8) {
                                    Circle().fill(item.category.color).frame(width: 6, height: 6)
                                    Text(item.category.rawValue).font(.system(size: 14))
                                    Spacer()
                                    Text(Money.display(item.amount)).font(.system(size: 14, weight: .medium)).monospacedDigit()
                                    Text(String(format: "%.1f%%", Double(item.amount) / Double(max(gross, 1)) * 100)).font(.system(size: 11)).foregroundStyle(Palette.muted).frame(width: 43, alignment: .trailing)
                                }
                                GeometryReader { g in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Palette.elevated)
                                        Capsule().fill(item.category.color).frame(width: g.size.width * Double(item.amount) / Double(max(gross, 1)))
                                    }
                                }.frame(height: 3)
                            }
                        }
                    }
                    Rectangle().fill(Palette.line).frame(height: 0.5).padding(.vertical, 28)
                    SectionHeading(title: "Daily spending").padding(.bottom, 18)
                    Chart(daily, id: \.date) { item in
                        BarMark(x: .value("Day", item.date, unit: .day), y: .value("Rupees", Double(item.amount) / 100)).foregroundStyle(Palette.accent.opacity(0.8)).cornerRadius(2)
                    }.frame(height: 125)
                        .chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) { _ in AxisValueLabel(format: .dateTime.day()).foregroundStyle(Palette.faint) } }
                        .chartYAxis { AxisMarks(position: .trailing) { _ in AxisGridLine().foregroundStyle(Palette.line); AxisValueLabel().foregroundStyle(Palette.faint) } }
                    Rectangle().fill(Palette.line).frame(height: 0.5).padding(.vertical, 24)
                    let refunds = store.entries(in: month).filter { $0.kind == .refund }.reduce(Int64(0)) { $0 + $1.paise }
                    summaryRow("Expenses", value: gross)
                    summaryRow("Refunds", value: refunds).padding(.top, 14)
                    summaryRow("Net spending", value: store.spent(in: month), strong: true).padding(.top, 14)
                    Text("Transfers excluded. Uncategorised expenses included.").font(.system(size: 11)).foregroundStyle(Palette.faint).padding(.top, 18)
                }
            }.padding(.horizontal, 22).padding(.bottom, 28)
        }.pageBackground().toolbar(.hidden, for: .navigationBar)
    }
    private func summaryRow(_ title: String, value: Int64, strong: Bool = false) -> some View {
        HStack { Text(title).foregroundStyle(strong ? Palette.ink : Palette.muted); Spacer(); Text(Money.display(value)).monospacedDigit() }.font(.system(size: 14, weight: strong ? .semibold : .regular))
    }
    private var daily: [(date: Date, amount: Int64)] {
        let grouped = Dictionary(grouping: store.entries(in: month).filter { $0.kind == .expense }) { Dates.calendar.startOfDay(for: $0.date) }
        return grouped.map { (date: $0.key, amount: $0.value.reduce(0) { $0 + $1.paise }) }.sorted { $0.date < $1.date }
    }
}
