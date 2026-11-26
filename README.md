# Expense Roast

An offline iPhone expense tracker that helps you record spending—and occasionally judges your choices.

Built with **SwiftUI**, **Swift Charts**, and **App Intents**. No account, server, analytics, or LLM required.

## What it does

- Track expenses, transfers and refunds with categories, dates, merchants and notes.
- Browse transactions by day; search and filter by date, category or review status.
- Set a monthly budget and view category breakdowns and daily spending charts.
- Import supported outgoing HDFC UPI messages through a Shortcuts automation, with reference-number deduplication and manual review.
- Reconcile an imported payment with an existing manual entry without losing its category or note.
- Export and restore a JSON backup. Personal data stays in the app sandbox.
- Show a sarcastic image after saving a new expense above ₹1,000. Reactions are optional, and never block saving.

## Run it

Requires Xcode with an iOS 17+ SDK and an iPhone or simulator.

1. Open `ThisYou.xcodeproj` and select the **ThisYou** scheme. These internal names are retained for compatibility; the installed app is named **Expense Roast**.
2. Copy `Local.xcconfig.example` to `Local.xcconfig`.
3. Set `HDFC_ACCOUNT_SUFFIX` to the four account digits printed in your bank messages. The checked-in default is the fictional `0000`.
4. Set `DEVELOPMENT_TEAM` to your Apple development team ID, or choose a team in Xcode. For a new installation, set a unique bundle identifier.
5. Select a simulator or your iPhone and Run.

`Local.xcconfig` is ignored by Git. Never commit your signing files, ledger or exported backups.

**Existing installations:** keep your current bundle identifier and signing team, and install updates over the existing app to retain its sandbox. Renaming the display name does not reset its ledger. Export a backup before updates.

## Try the interface safely

Settings → **Separate demo mode** loads fictional transactions in a separate ledger. Turn it off to return to your personal data. The `--demo` launch argument also selects demo mode.

For live SwiftUI previews, open `ThisYou/Theme.swift` and enable Xcode Canvas. Preview data is in memory and cannot modify your ledger. See [DESIGN.md](DESIGN.md) for layout and colour decisions.

## Set up Shortcuts

### Payment app exit → reminder → entry form

In Shortcuts, create an **App → Is Closed** personal automation for GPay, PhonePe and/or CRED. Choose **Run Immediately**, then add these actions in order:

1. Apple's **Show Alert**: title **Record expense**, message **Ready to record your expense?**. Turn **Show Cancel Button** off.
2. **Expense Roast → Quick Expense**.

The alert has a single **Done** button. Tapping it continues to the entry form. If upgrading from the earlier prototype, remove **Show Expense Roast** from that automation. No custom reminder snippets or GIF playback remain.

Exiting a payment app does not prove that a payment happened; skip the entry if you did not pay. iOS controls alert presentation and may require unlocking.

### HDFC SMS → review inbox

Create a Message automation matching `From HDFC Bank A/C *0000` (replace `0000` with your configured suffix). Choose **Run Immediately**, then add **Expense Roast → Import HDFC SMS** and pass the incoming message's text into **Message**.

The app validates this structured format; examples below are fictional:

```text
Sent Rs.65.00
From HDFC Bank A/C *0000
To EXAMPLE CAFE
On 24/11/26
Ref 100000000001
```

Only matching outgoing payments are accepted. Credits, OTPs, other accounts, failed payments and repeated references are ignored or rejected. Categories are never guessed. The app cannot read your Messages inbox or historical transactions.

If the SMS arrives first, review the imported entry. If you already entered it manually, explicitly link the matching record. Same amount/day suggestions are not automatic merges; both records count until linked.

## Data and accounting

- Amounts are stored as integer paise.
- Transfers are excluded from spending; refunds reduce the month's net spend. Category charts show gross expenses.
- Each month keeps its history. A new month does not delete previous records.
- Personal and demo ledgers are separate, written atomically with file locking. Background SMS imports always target the personal ledger.
- Corrupt-file and storage errors are surfaced instead of replacing your ledger silently.
- Deleting an imported transaction remembers its reference so the same SMS cannot recreate it.
- Restore replaces the selected ledger after confirmation. Keep backups outside the app; deleting the app can remove its local data.

The legacy `thisyou://add` URL opens an empty entry form. The app's internal storage path is kept stable for existing users.

## Checks

```sh
bash test-core.sh
```

Core checks use a temporary directory and fictional account `0000`. They cover SMS validation, amounts, duplicates, persistence, reconciliation, transfers, refunds, budgets, demo isolation, preview isolation and backup round-trips.

Real incoming SMS, payment-app exit triggers, native alerts and locked-device behaviour need testing on an iPhone. The simulator checks the ledger, forms and reaction dismissal. See [TESTING.md](TESTING.md).

## Media

The optional reaction uses a user-supplied film still of Samuthirakani. It is third-party media, not original project artwork. No GIFs or generated meme images are bundled.
