import SwiftUI

// One neutral hierarchy; category hues are reserved for data, not chrome.
enum Palette {
    static let background = Color(hex: 0x131416)
    static let card = Color(hex: 0x20242A)
    static let elevated = Color(hex: 0x292C30)
    static let ink = Color(hex: 0xF2F0ED)
    static let accent = Color(hex: 0x8EB7F4)
    static let muted = Color(hex: 0xA3A5AA)
    static let faint = Color(hex: 0x858C97)
    static let line = Color.white.opacity(0.09)
    static let coral = Color(hex: 0xD89B8B)
}
extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}
extension ExpenseCategory {
    var color: Color {
        switch self {
        case .uncategorised: Color(hex: 0x999B9F)
        case .food: Color(hex: 0xE3AD8E)
        case .groceries: Color(hex: 0xA3C39A)
        case .transport: Color(hex: 0x8CBFCB)
        case .shopping: Color(hex: 0xB7A0D2)
        case .bills: Color(hex: 0x8BAEF0)
        case .entertainment: Color(hex: 0xD5BE7C)
        case .health: Color(hex: 0x8FC6B2)
        case .other: Color(hex: 0xB1A697)
        }
    }
}
extension View {
    func panel() -> some View { padding(18).background(Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous)) }
    func pageBackground() -> some View { foregroundStyle(Palette.ink).background(Palette.background.ignoresSafeArea()) }
    func eyebrow() -> some View { font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.muted) }
}
struct PageHeading<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing
    var body: some View {
        HStack {
            Text(title).font(.system(size: 28, weight: .bold)).tracking(-0.7)
            Spacer()
            trailing()
        }.padding(.top, 12)
    }
}
struct ToolbarIcon: View {
    let symbol: String
    var primary = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 17, weight: .medium))
                .frame(width: 44, height: 44)
                .foregroundStyle(primary ? Palette.background : Palette.muted)
                .background(primary ? Palette.accent : .clear, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }
}
struct MonthPicker: View {
    @Binding var month: Date
    var body: some View {
        HStack(spacing: 8) {
            Text(month.formatted(.dateTime.month(.wide).year())).font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.muted)
            Spacer()
            Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("Previous month")
            Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.accessibilityLabel("Next month")
        }.font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.muted)
    }
    private func shift(_ value: Int) { month = Dates.calendar.date(byAdding: .month, value: value, to: month)! }
}
struct TransactionRow: View {
    let entry: Transaction
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.kind == .transfer ? "arrow.left.arrow.right" : entry.category.symbol)
                .font(.system(size: 15, weight: .regular)).foregroundStyle(entry.category.color)
                .frame(width: 36, height: 36).background(entry.category.color.opacity(0.17), in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(entry.merchant.isEmpty ? entry.category.rawValue : entry.merchant)
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.ink).lineLimit(1)
                HStack(spacing: 5) {
                    if entry.requiresReview { Circle().fill(Palette.accent).frame(width: 5, height: 5) }
                    Text(entry.note.isEmpty ? (entry.kind == .transfer ? "Transfer" : entry.category.rawValue) : entry.note)
                        .font(.system(size: 12)).foregroundStyle(Palette.muted).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text((entry.kind == .refund ? "+" : "") + Money.display(entry.paise))
                .font(.system(size: 15, weight: .medium)).monospacedDigit()
                .foregroundStyle(entry.kind == .refund ? Color(hex: 0xA3C39A) : Palette.ink)
        }.padding(.vertical, 12).contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(entry.requiresReview ? "Needs review" : "Open transaction")
    }
}
struct SectionHeading: View {
    let title: String
    var body: some View { Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.ink) }
}
struct EmptyLedger: View {
    var title = "No expenses yet"
    var detail = "Add an expense to start tracking this month."
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray").font(.system(size: 27, weight: .light)).foregroundStyle(Palette.faint)
            Text(title).font(.system(size: 17, weight: .medium))
            Text(detail).font(.system(size: 14)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 42)
    }
}

#if DEBUG
struct ThisYou_Previews: PreviewProvider {
    @MainActor static var previews: some View {
        Group {
            RootView(store: ExpenseStore.preview(), initialTab: 0).previewDisplayName("Overview")
            RootView(store: ExpenseStore.preview(), initialTab: 1).previewDisplayName("Transactions")
            RootView(store: ExpenseStore.preview(), initialTab: 2).previewDisplayName("Insights")
            EntryEditor(store: ExpenseStore.preview(), entry: nil).previewDisplayName("Quick entry")
        }.preferredColorScheme(.dark).previewDevice("iPhone 17 Pro")
    }
}
#endif
