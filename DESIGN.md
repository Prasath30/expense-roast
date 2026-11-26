# UI direction

This is a daily ledger, not a marketing page. Prioritise readable amounts, repeatable row alignment and an obvious add/review flow.

## References consulted

- [Copilot Money](https://www.copilot.money/) and its [transaction overview](https://help.copilot.money/en/articles/9554412-transactions-tab-overview): a scan-friendly financial hierarchy, review/search/filter patterns, and direct access to details. These informed the structure; no brand assets or proprietary layouts were copied.
- [Monarch mobile reports](https://www.monarch.com/blog/june-product-update): separate summary and category analysis.
- [Taste Skill](https://github.com/Leonxlnx/taste-skill): reviewed as design reference. Its current workflow targets company websites and browser checking, so it was not installed or treated as the build workflow for this native app. Applicable ideas: consistent edges, a coherent palette and plain copy. No web dependencies or scripts added.
- [Apple Xcode previews](https://developer.apple.com/documentation/xcode/adding-previews-to-your-interface-files): native preview iteration.

## Palette

| Role | Hex |
| --- | --- |
| Background | #131416 |
| Surface | #20242A |
| Elevated surface | #292C30 |
| Primary text | #F2F0ED |
| Secondary text | #A3A5AA |
| Tertiary text | #858C97 |
| Action / review | #8EB7F4 |
| Warning | #D89B8B |

Muted category colours appear in icons, the donut and comparison bars. Buttons, headings and navigation do not borrow category colours. One restrained tonal blue gradient anchors the monthly spending summary. Other surfaces remain flat. No neon fills, rounded headline font, slogans, mascot card or floating pill navigation.

## Hierarchy

- Overview: header/add → tracked account → month → spending/budget → review → recent transactions. The spending figure sits in a single tonal blue summary surface; budget progress and remaining allowance share that surface. Today’s spending and the monthly transaction count provide a compact secondary row below it.
- Transactions: header/add → month → search and filters → filtered totals → compact daily groups. Merchant and amount share a baseline; notes stay secondary. Review is a small dot rather than a loud badge.
- Insights: restrained thin donut → category amounts, percentages and comparison bars → daily bars → expense/refund/net summary.
- Entry: amount → transaction type → compact neutral category choices → optional merchant/note/date. Save stays reachable at the bottom; the reaction only runs after persistence succeeds.

## Live iteration

Open `Theme.swift` in Xcode. Show Canvas and resume previews. The `ThisYou_Previews` provider has Overview, Transactions, Insights and Quick entry variants on an iPhone 17 Pro. Standard PreviewProvider is used rather than a compiler macro so the source also typechecks in the restricted command-line environment.

`ExpenseStore.preview()` uses an **in-memory ledger**. Interaction works without reading or modifying personal or demo files. Normal simulator/device runs still use persistent storage. UI edits update in Canvas when preview compilation succeeds; this is Xcode's SwiftUI workflow, not Metro Fast Refresh. A cold preview build can take longer than subsequent edits.

Preview entry points live at the bottom of `Theme.swift`, UI layout in `RootView.swift` / `EntryViews.swift`, and all colour/spacing primitives in `Theme.swift`.
