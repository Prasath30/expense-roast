import Foundation

enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case uncategorised = "Uncategorised", food = "Food & drinks", groceries = "Groceries", transport = "Transport", shopping = "Shopping", bills = "Bills & rent", entertainment = "Entertainment", health = "Health", other = "Other"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .uncategorised: "tray"; case .food: "fork.knife"; case .groceries: "basket"; case .transport: "tram.fill"; case .shopping: "bag"; case .bills: "house"; case .entertainment: "play.rectangle"; case .health: "cross.case"; case .other: "ellipsis"
        }
    }
}
enum EntryKind: String, Codable, CaseIterable { case expense = "Expense", transfer = "Transfer", refund = "Refund" }
struct Transaction: Identifiable, Codable, Equatable {
    var id = UUID()
    var paise: Int64
    var merchant: String
    var date: Date
    var category: ExpenseCategory = .uncategorised
    var note = ""
    var kind: EntryKind = .expense
    var reference: String? = nil
    var needsReview = false
    var createdAt = Date()
    var bankConfirmed: Bool { reference != nil }
    var requiresReview: Bool { needsReview || (kind == .expense && category == .uncategorised) }
}
struct Ledger: Codable {
    var version = 1
    var transactions: [Transaction] = []
    var monthlyBudgets: [String: Int64] = [:]
    var defaultBudget: Int64 = 0
    var humour = true
    var ignoredReferences: [String] = []
}
enum Money {
    static func parse(_ text: String) -> Int64? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "")
        guard cleaned.range(of: #"^\d{1,10}(\.\d{1,2})?$"#, options: .regularExpression) != nil,
              let decimal = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")), decimal > 0 else { return nil }
        return NSDecimalNumber(decimal: decimal * 100).int64Value
    }
    static func display(_ paise: Int64) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "INR"; f.locale = Locale(identifier: "en_IN")
        f.minimumFractionDigits = paise % 100 == 0 ? 0 : 2; f.maximumFractionDigits = 2
        return f.string(from: NSDecimalNumber(value: paise).dividing(by: 100)) ?? "₹0"
    }
    static func input(_ paise: Int64) -> String { String(format: "%.2f", Double(paise) / 100) }
}
enum Dates {
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Kolkata")!; return c
    }
    static func monthKey(_ date: Date) -> String {
        let p = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", p.year!, p.month!)
    }
    static func sameDay(_ a: Date, _ b: Date) -> Bool { calendar.isDate(a, inSameDayAs: b) }
}
enum TrackedAccount {
    static var suffix: String {
        #if TESTING
        return "0000"
        #else
        let value = Bundle.main.object(forInfoDictionaryKey: "TrackedAccountSuffix") as? String ?? "0000"
        return value.range(of: #"^\d{4}$"#, options: .regularExpression) != nil ? value : "0000"
        #endif
    }
}

enum ImportError: LocalizedError {
    case unsupported
    var errorDescription: String? { "Not a supported HDFC outgoing UPI message for account \(TrackedAccount.suffix). Nothing was saved." }
}
enum HDFCParser {
    static func parse(_ text: String) throws -> Transaction {
        // Full structured match; never treat a bare 'debit' keyword or an OTP as an expense.
        let normal = text.replacingOccurrences(of: "\u{00a0}", with: " ")
        let pattern = #"(?is)^\s*Sent\s+Rs\.?\s*([\d,]+(?:\.\d{1,2})?)\s+From\s+HDFC\s+Bank\s+A/C\s*\*\#(TrackedAccount.suffix)\s+To\s+(.+?)\s+On\s+(\d{2}/\d{2}/\d{2})\s+Ref\s+(\d{6,30})(?:\s|$)"#
        let r = try NSRegularExpression(pattern: pattern)
        guard let match = r.firstMatch(in: normal, range: NSRange(normal.startIndex..., in: normal)) else { throw ImportError.unsupported }
        func group(_ index: Int) -> String { String(normal[Range(match.range(at: index), in: normal)!]) }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.calendar = Dates.calendar; f.timeZone = Dates.calendar.timeZone; f.dateFormat = "dd/MM/yy"; f.isLenient = false
        guard let amount = Money.parse(group(1)), let date = f.date(from: group(3)), f.string(from: date) == group(3) else { throw ImportError.unsupported }
        // SMS provides a date only. Do not fabricate a payment time.
        return Transaction(paise: amount, merchant: group(2).split(whereSeparator: { $0.isWhitespace }).joined(separator: " "), date: date, reference: group(4), needsReview: true)
    }
}
