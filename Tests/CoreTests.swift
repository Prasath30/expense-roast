import Foundation

@main struct CoreTests {
    @MainActor static func main() throws {
        var checks = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError("FAILED: \(message)") }; checks += 1
        }
        let sample = "Sent Rs.65.00\nFrom HDFC Bank A/C *0000\nTo EXAMPLE CAFE\nOn 24/11/26\nRef 100000000001\nNot You?\nCall 18002586161/SMS BLOCK UPI to 7308080808"
        let parsed = try HDFCParser.parse(sample)
        expect(parsed.paise == 6500, "integer paise")
        expect(parsed.merchant == "EXAMPLE CAFE", "merchant extraction")
        expect(parsed.reference == "100000000001", "reference extraction")
        expect(Dates.monthKey(parsed.date) == "2026-11", "SMS date")
        expect(parsed.requiresReview && parsed.category == .uncategorised, "never auto categorise")
        let other = try HDFCParser.parse(sample.replacingOccurrences(of: "EXAMPLE CAFE", with: "ALEX  B").replacingOccurrences(of: "65.00", with: "100.00"))
        expect(other.merchant == "ALEX B" && other.kind == .expense, "self-name not automatically transfer")
        for invalid in [sample.replacingOccurrences(of: "0000", with: "9999"), sample.replacingOccurrences(of: "HDFC", with: "ICICI"), sample.replacingOccurrences(of: "Sent", with: "Received"), sample.replacingOccurrences(of: "24/11/26", with: "31/11/26"), "OTP 123456 to debit Rs.65", "Your payment failed", sample.replacingOccurrences(of: "65.00", with: "0.00")] {
            do { _ = try HDFCParser.parse(invalid); fatalError("Accepted invalid SMS") } catch { checks += 1 }
        }
        expect(Money.parse("1,234.56") == 123456, "comma amount")
        expect(Money.parse("0.01") == 1, "one paisa")
        expect(Money.parse("-4") == nil && Money.parse("1.234") == nil && Money.parse("nan") == nil, "invalid amount")
        _ = try LedgerDisk.importSMS(sample)
        _ = try LedgerDisk.importSMS(sample)
        let store = ExpenseStore()
        expect(store.loaded && store.ledger.transactions.count == 1, "SMS duplicate reference blocked")
        expect(store.spent(in: parsed.date) == 6500, "uncategorised counts toward spending")
        var manual = Transaction(paise: 6500, merchant: "Lunch", date: parsed.date, category: .food, note: "Keep this note")
        expect(store.save(manual), "manual saved")
        expect(store.candidates(for: parsed).count == 1, "possible duplicate offered")
        expect(store.merge(sms: store.ledger.transactions.first(where: { $0.reference == parsed.reference })!, manual: manual), "explicit reconciliation")
        expect(store.ledger.transactions.count == 1 && store.ledger.transactions[0].note == "Keep this note", "merge preserves note, removes duplicate")
        expect(store.ledger.transactions[0].category == .food && store.reviewCount == 0, "merge preserves manual category")
        manual = store.ledger.transactions[0]; manual.kind = .transfer; manual.category = .uncategorised
        expect(store.save(manual) && store.spent(in: parsed.date) == 0 && store.reviewCount == 0, "transfers excluded and do not require category")
        let reloaded = ExpenseStore()
        expect(reloaded.ledger.transactions == store.ledger.transactions, "disk round trip")
        expect(store.setBudget(100000, month: parsed.date, carry: true), "budget saved")
        let next = Dates.calendar.date(byAdding: .month, value: 1, to: parsed.date)!
        expect(store.setBudget(200000, month: next, carry: true), "next-month budget")
        expect(store.budget(in: parsed.date) == 100000 && store.budget(in: next) == 200000, "past budget preserved")
        store.switchDemo(true)
        expect(store.demo && store.ledger.transactions.count == 9, "isolated demo")
        store.switchDemo(false)
        expect(store.ledger.transactions.count == 1, "real ledger untouched")
        var refund = Transaction(paise: 2000, merchant: "Refund", date: parsed.date, category: .food); refund.kind = .refund
        expect(store.save(refund) && store.spent(in: parsed.date) == -2000, "refund accounting")
        let backup = try JSONEncoder().encode(store.ledger)
        let decoded = try JSONDecoder().decode(Ledger.self, from: backup)
        expect(decoded.transactions == store.ledger.transactions, "backup round trip")
        expect(store.remove(manual), "delete")
        _ = try LedgerDisk.importSMS(sample)
        store.reload()
        expect(store.ledger.transactions.count == 1, "deleted SMS stays ignored")
        let diskBeforePreview = store.ledger.transactions
        let preview = ExpenseStore.preview()
        expect(preview.loaded && preview.ledger.transactions.count == 8, "preview fixtures available offline")
        let previewEntry = Transaction(paise: 9900, merchant: "Preview only", date: Date(), category: .other)
        expect(preview.save(previewEntry) && preview.ledger.transactions.contains(where: { $0.id == previewEntry.id }), "preview edits work in memory")
        store.reload()
        expect(store.ledger.transactions == diskBeforePreview, "preview cannot change personal ledger")
        print("PASS: \(checks) core checks (HDFC parsing, amounts, duplicates, persistence, reconciliation, transfers, refunds, budgets, demo isolation, backup).")
    }
}
