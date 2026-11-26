# Verification

## Core checks

Run `bash test-core.sh` on macOS. Tests isolate all disk operations in a temporary directory and use fictional SMS data for account `0000`.

Coverage includes integer-paise parsing, account filtering, invalid dates and messages, merchant/reference extraction, duplicate imports, manual reconciliation, transfers/refunds, atomic persistence, monthly budgets, demo isolation, in-memory previews and JSON backups.

## UI regression checked on 25 November 2026

Xcode 26.6; iPhone 17 Pro Max simulator running iOS 26.5:

- Saved a ₹1,001 expense in the isolated demo ledger.
- Confirmed the supplied still image and “sabash beta sabash” appeared after saving.
- Tapped Done and returned to Overview with the saved expense visible exactly once.
- Confirmed custom App Intent snippets and GIF rendering were removed.

## Before relying on device automations

Verify a real supported HDFC message reaches Import HDFC SMS, repeated imports do not duplicate it, Show Alert waits for Done before Quick Expense opens, and the flow behaves as expected while the phone is locked and after restart.

The interactive Files export/restore picker requires a device walkthrough; JSON backup encoding and decoding are covered by core checks.
