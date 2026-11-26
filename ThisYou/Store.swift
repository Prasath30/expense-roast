import Foundation
import SwiftUI
import Darwin

enum LedgerDisk {
    static var root: URL {
        get throws {
            #if TESTING
            if let path = ProcessInfo.processInfo.environment["THISYOU_TEST_STORAGE"] {
                let url = URL(fileURLWithPath: path, isDirectory: true)
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                return url
            }
            #endif
            let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("ThisYou", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            return root
        }
    }
    static func access<T>(demo: Bool = false, _ body: (inout Ledger) throws -> T) throws -> T {
        let root = try root
        let url = root.appendingPathComponent(demo ? "demo.json" : "ledger.json")
        let lock = open(root.appendingPathComponent("ledger.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard lock >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { close(lock) }
        guard flock(lock, LOCK_EX) == 0 else { throw CocoaError(.fileLocking) }
        defer { flock(lock, LOCK_UN) }
        var ledger: Ledger
        if FileManager.default.fileExists(atPath: url.path) {
            ledger = try JSONDecoder().decode(Ledger.self, from: Data(contentsOf: url))
            guard ledger.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
        } else { ledger = Ledger() }
        let result = try body(&ledger)
        let data = try JSONEncoder().encode(ledger)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return result
    }
    static func importSMS(_ message: String, demo: Bool = false) throws -> String {
        let transaction = try HDFCParser.parse(message)
        return try access(demo: demo) { ledger in
            guard !ledger.transactions.contains(where: { $0.reference == transaction.reference }),
                  !ledger.ignoredReferences.contains(transaction.reference!) else { return "Already captured. No duplicate was added." }
            ledger.transactions.append(transaction)
            return "Captured \(Money.display(transaction.paise)) to \(transaction.merchant). Ready for review."
        }
    }
}

@MainActor final class ExpenseStore: ObservableObject {
    @Published var ledger = Ledger()
    @Published var error: String?
    @Published var demo = false
    @Published var loaded = false
    private let inMemory: Bool
    init(inMemory: Bool = false) {
        self.inMemory = inMemory
        if inMemory { loaded = true } else { reload() }
    }
    static func preview() -> ExpenseStore {
        let store = ExpenseStore(inMemory: true)
        let now = Date()
        let entries: [(Int64, String, ExpenseCategory, Int, String)] = [
            (28500, "Third Wave Coffee", .food, 0, "Coffee with friends"),
            (124900, "Fresh market", .groceries, 0, "Weekly groceries"),
            (6500, "EXAMPLE CAFE", .uncategorised, 0, ""),
            (18000, "Auto ride", .transport, 1, "Office to home"),
            (69900, "Bookshop", .shopping, 1, "Weekend reading"),
            (42000, "Lunch", .food, 2, ""),
            (1650000, "Rent", .bills, 3, "Monthly rent"),
            (35000, "Badminton", .entertainment, 4, "Court booking")
        ]
        store.ledger.defaultBudget = 3000000
        store.ledger.transactions = entries.map { amount, name, category, offset, note in
            Transaction(paise: amount, merchant: name, date: Dates.calendar.date(byAdding: .day, value: -offset, to: now)!, category: category, note: note, needsReview: category == .uncategorised)
        }
        return store
    }
    func reload() {
        guard !inMemory else { return }
        do { ledger = try LedgerDisk.access(demo: demo) { $0 }; loaded = true }
        catch { self.error = "Could not open your saved expenses. Your file has not been replaced. \(error.localizedDescription)"; loaded = false }
    }
    @discardableResult func mutate(_ body: (inout Ledger) throws -> Void) -> Bool {
        guard loaded else { error = "Storage is unavailable. Resolve the storage error before saving."; return false }
        do {
            if inMemory { var value = ledger; try body(&value); ledger = value }
            else { ledger = try LedgerDisk.access(demo: demo) { value in try body(&value); return value } }
            return true
        }
        catch { self.error = "Could not save. \(error.localizedDescription)"; return false }
    }
    func save(_ entry: Transaction) -> Bool {
        mutate { l in
            if let i = l.transactions.firstIndex(where: { $0.id == entry.id }) { l.transactions[i] = entry }
            else { l.transactions.append(entry) }
        }
    }
    func remove(_ entry: Transaction) -> Bool {
        mutate { l in
            if let ref = entry.reference { l.ignoredReferences.append(ref) }
            l.transactions.removeAll { $0.id == entry.id }
        }
    }
    func candidates(for entry: Transaction) -> [Transaction] {
        guard entry.bankConfirmed else { return [] }
        return ledger.transactions.filter { !$0.bankConfirmed && $0.id != entry.id && $0.paise == entry.paise && Dates.sameDay($0.date, entry.date) }
    }
    func merge(sms: Transaction, manual: Transaction) -> Bool {
        mutate { l in
            guard sms.bankConfirmed, !manual.bankConfirmed, sms.id != manual.id, sms.paise == manual.paise, Dates.sameDay(sms.date, manual.date), l.transactions.contains(where: { $0.id == sms.id }), let i = l.transactions.firstIndex(where: { $0.id == manual.id }) else { throw CocoaError(.validationMissingMandatoryProperty) }
            l.transactions[i].reference = sms.reference
            l.transactions[i].merchant = sms.merchant
            l.transactions[i].needsReview = l.transactions[i].kind == .expense && l.transactions[i].category == .uncategorised
            l.transactions.removeAll { $0.id == sms.id }
        }
    }
    func importSMS(_ text: String) -> String? {
        if inMemory {
            do {
                let entry = try HDFCParser.parse(text)
                if ledger.transactions.contains(where: { $0.reference == entry.reference }) { return "Already captured." }
                _ = save(entry)
                return "Captured for preview review."
            } catch { self.error = error.localizedDescription; return nil }
        }
        do { let result = try LedgerDisk.importSMS(text, demo: demo); reload(); return result }
        catch { self.error = error.localizedDescription; return nil }
    }
    var reviewCount: Int { ledger.transactions.filter { $0.requiresReview }.count }
    func entries(in month: Date) -> [Transaction] { ledger.transactions.filter { Dates.monthKey($0.date) == Dates.monthKey(month) }.sorted { $0.date == $1.date ? $0.createdAt > $1.createdAt : $0.date > $1.date } }
    func spent(in month: Date) -> Int64 { entries(in: month).reduce(0) { $0 + ($1.kind == .expense ? $1.paise : $1.kind == .refund ? -$1.paise : 0) } }
    func budget(in month: Date) -> Int64 { ledger.monthlyBudgets[Dates.monthKey(month)] ?? ledger.defaultBudget }
    func setBudget(_ value: Int64, month: Date, carry: Bool) -> Bool {
        mutate { l in
            // Freeze known historical months before changing the carry-forward default.
            if carry {
                for entry in l.transactions {
                    let key = Dates.monthKey(entry.date)
                    if key < Dates.monthKey(month), l.monthlyBudgets[key] == nil { l.monthlyBudgets[key] = l.defaultBudget }
                }
                l.defaultBudget = value
            }
            l.monthlyBudgets[Dates.monthKey(month)] = value
        }
    }
    func switchDemo(_ enabled: Bool) {
        demo = enabled; reload()
        if enabled && ledger.transactions.isEmpty {
            let now = Date()
            let examples: [(Int64, String, ExpenseCategory, Int, String)] = [
                (6500,"EXAMPLE CAFE",.uncategorised,0,""), (10000,"ALEX B",.uncategorised,0,"Check whether this is a transfer"),
                (28500,"Third Wave Coffee",.food,0,"Coffee & a catch-up"), (124900,"Fresh market",.groceries,0,"Weekly groceries"),
                (18000,"Auto ride",.transport,1,"Office → home"), (69900,"Bookshop",.shopping,1,"Weekend reading"),
                (42000,"Lunch",.food,2,"Lunch with friends"), (1650000,"Rent",.bills,3,"November rent"),
                (35000,"Badminton",.entertainment,4,"Court booking")]
            _ = mutate { l in
                l.defaultBudget = 3000000
                l.transactions = examples.map { amount, name, cat, offset, note in
                    Transaction(paise: amount, merchant: name, date: Dates.calendar.date(byAdding: .day, value: -offset, to: now)!, category: cat, note: note, reference: cat == .uncategorised ? "DEMO-\(amount)" : nil, needsReview: cat == .uncategorised)
                }
            }
        }
    }
}
