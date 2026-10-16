# Graph Report - sukiscan  (2026-10-16)

## Corpus Check
- Corpus is ~28,164 words - fits in a single context window. You may not need a graph.

## Summary
- 748 nodes · 1086 edges · 49 communities (42 shown, 7 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 9 edges (avg confidence: 0.77)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Riverpod Providers & Screens
- Sync Receive & Test Fakes
- Sync Codec & Chunking
- Plan Docs & App Shell
- Sync Repository Merge
- CSV Parsing Rules
- Send Screen & Lints
- CSV File Access
- Scanner UI Widgets
- Money & Database Schema
- Feedback Cues
- Item & Cart Domain
- Misc 12
- Misc 13
- Misc 14
- Misc 15
- Misc 16
- Misc 17
- Misc 18
- Misc 19
- Misc 20
- Misc 21
- Misc 22
- Misc 23
- Misc 24
- Misc 25
- Misc 26
- Misc 27
- Misc 28
- Misc 29
- Misc 30
- Misc 31
- Misc 32
- Misc 33
- Misc 34
- Misc 35
- Misc 36
- Misc 37
- Misc 38
- Misc 39
- Misc 40
- Misc 41
- Misc 42
- Misc 43
- Misc 44
- Misc 48

## God Nodes (most connected - your core abstractions)
1. `feedbackProvider` - 20 edges
2. `cartProvider` - 11 edges
3. `itemRepositoryProvider` - 10 edges
4. `_ItemListScreenState` - 8 edges
5. `syncRepositoryProvider` - 6 edges
6. `_ReadScreenState` - 6 edges
7. `_SellScreenState` - 6 edges
8. `ScannerBuilder` - 6 edges
9. `FakeItemRepo` - 6 edges
10. `SukiScan Project Plan` - 6 edges

## Surprising Connections (you probably didn't know these)
- `file_picker package` --conceptually_related_to--> `SukiScan Project Plan`  [AMBIGUOUS]
  pubspec.yaml → plan.md
- `FakeCsvFiles` --implements--> `CsvFiles`  [EXTRACTED]
  test/helpers/fake_csv_files.dart → lib/data/csv_files.dart
- `FakeItemRepo` --implements--> `ItemRepository`  [EXTRACTED]
  test/helpers/fake_item_repo.dart → lib/data/item_repository.dart
- `FakeSaleRepo` --implements--> `SaleRepository`  [EXTRACTED]
  test/helpers/fake_sale_repo.dart → lib/data/sale_repository.dart
- `FakeSyncRepo` --implements--> `SyncRepository`  [EXTRACTED]
  test/helpers/fake_sync_repo.dart → lib/data/sync_repository.dart

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **QR sync pipeline** — lib_domain_sync_codec, lib_data_sync_repository, lib_features_sync_send_screen, lib_features_sync_receive_screen [INFERRED 0.85]
- **Selling checkout flow** — lib_domain_cart, lib_data_sale_repository, lib_shared_scanner_view, atomic_checkout_transaction [INFERRED 0.85]
- **Data layer with integer centavos** — lib_core_money, lib_core_db, lib_data_item_repository, sqlite_schema_v1 [INFERRED 0.75]

## Communities (49 total, 7 thin omitted)

### Community 0 - "Riverpod Providers & Screens"
Cohesion: 0.06
Nodes (45): clockProvider, csvFilesProvider, itemListProvider, itemRepositoryProvider, _barcode, build, cents, _clearForm (+37 more)

### Community 1 - "Sync Receive & Test Fakes"
Cohesion: 0.05
Nodes (31): SyncRepository, main, frames, main, payload, main, show, corrupt (+23 more)

### Community 2 - "Sync Codec & Chunking"
Cohesion: 0.04
Nodes (43): add, alphabet, assembled, b, base64Encode, buildFrames, checksum, chunk (+35 more)

### Community 3 - "Plan Docs & App Shell"
Cohesion: 0.05
Nodes (35): Atomic checkout SQLite transaction, Encoding module (Encode screen), Last-write-wins merge on updated_at, Clock, allLive, countLive, _db, _now (+27 more)

### Community 4 - "Sync Repository Merge"
Cohesion: 0.05
Nodes (39): changes, created, _db, deleted, exportAll, _loadAll, merge, MergeSummary (+31 more)

### Community 5 - "CSV Parsing Rules"
Cohesion: 0.05
Nodes (35): bad, barcode, _barcodeCol, cell, cellStarted, cents, col, CsvImport (+27 more)

### Community 6 - "Send Screen & Lints"
Cohesion: 0.07
Nodes (26): analysis_options.yaml (flutter_lints), _body, build, createState, dispose, _error, _frames, _frameTime (+18 more)

### Community 7 - "CSV File Access"
Cohesion: 0.07
Nodes (21): CsvFiles, DeviceCsvFiles, pick, save, bytes, header, main, read (+13 more)

### Community 8 - "Scanner UI Widgets"
Cohesion: 0.08
Nodes (20): _ScanPage, _ScanPageState, _ManualEntryDialog, _ManualEntryDialogState, ScannerView, _ScannerViewState, build, _CameraProbe (+12 more)

### Community 9 - "Money & Database Schema"
Cohesion: 0.07
Nodes (22): Integer centavos money model, databaseProvider, dbVersion, f, INTEGER, items, openAppDb, openDatabase (+14 more)

### Community 10 - "Feedback Cues"
Cohesion: 0.11
Nodes (14): AppFeedback, error, _run, scan, success, confirm, moneyInputFormatters, ShowMessage (+6 more)

### Community 11 - "Item & Cart Domain"
Cohesion: 0.11
Nodes (15): add, barcode, CartLine, _change, clear, decrement, increment, isEmpty (+7 more)

### Community 12 - "Misc 12"
Cohesion: 0.11
Nodes (15): confirmButton, confirmEnabled, feedback, gum, inLine, items, main, noodles (+7 more)

### Community 13 - "Misc 13"
Cohesion: 0.13
Nodes (11): build, _controller, cooldown, createState, dispose, error, formats, _onDetect (+3 more)

### Community 14 - "Misc 14"
Cohesion: 0.15
Nodes (8): _cash, CheckoutSheet, _CheckoutSheetState, createState, dispose, _error, _saving, showCheckoutSheet

### Community 15 - "Misc 15"
Cohesion: 0.14
Nodes (12): _busy, cart, _controller, _cooldown, createState, _defaultScanner, dispose, _enterManually (+4 more)

### Community 16 - "Misc 16"
Cohesion: 0.14
Nodes (8): createState, _empty, _list, _matches, _open, problems, _query, _shown

### Community 17 - "Misc 17"
Cohesion: 0.15
Nodes (8): AppShell, _AppShellState, AppTab, createState, _index, scannerBuilder, _tab, ScannerBuilder

### Community 18 - "Misc 18"
Cohesion: 0.15
Nodes (7): _code, createState, _defaultScanner, _encode, _item, noItems, scannerBuilder

### Community 19 - "Misc 19"
Cohesion: 0.18
Nodes (8): db, main, db, item, main, repo, row, seed

### Community 20 - "Misc 20"
Cohesion: 0.17
Nodes (8): Cart, add, build, CartNotifier, clear, decrement, increment, remove

### Community 21 - "Misc 21"
Cohesion: 0.17
Nodes (10): csv, feedback, gum, header, main, noodles, pump, repo (+2 more)

### Community 22 - "Misc 22"
Cohesion: 0.17
Nodes (8): coffee, field, gum, main, names, noodles, pump, repo

### Community 23 - "Misc 23"
Cohesion: 0.17
Nodes (11): allLive, countLive, deleted, failReads, failWrites, imported, lookups, softDelete (+3 more)

### Community 24 - "Misc 24"
Cohesion: 0.20
Nodes (3): main, field, main

### Community 25 - "Misc 25"
Cohesion: 0.22
Nodes (9): itemCountProvider, build, cartProvider, build, _confirm, build, _CartList, _confirmClear (+1 more)

### Community 26 - "Misc 26"
Cohesion: 0.20
Nodes (7): ItemRepository, feedback, main, noodles, pump, repo, FakeItemRepo

### Community 27 - "Misc 27"
Cohesion: 0.22
Nodes (4): build, onRetry, scannerBuilder, SukiScanApp

### Community 28 - "Misc 28"
Cohesion: 0.22
Nodes (7): actionLabel, build, compact, icon, message, onAction, title

### Community 29 - "Misc 29"
Cohesion: 0.22
Nodes (7): StartupErrorApp, _ImportFailedDialog, _Result, _TotalBar, BrandAppBar, EmptyState, ScannerErrorView

### Community 30 - "Misc 30"
Cohesion: 0.25
Nodes (5): feedback, field, main, noodles, pumpScreen

### Community 31 - "Misc 31"
Cohesion: 0.25
Nodes (4): actions, BrandLogo, build, preferredSize

### Community 32 - "Misc 32"
Cohesion: 0.25
Nodes (4): gum, main, noodles, catalog

### Community 33 - "Misc 33"
Cohesion: 0.25
Nodes (7): db, gum, main, n, noodles, repo, stock

### Community 34 - "Misc 34"
Cohesion: 0.29
Nodes (5): SaleRepository, calls, checkout, fail, FakeSaleRepo

### Community 35 - "Misc 35"
Cohesion: 0.29
Nodes (5): db, main, noodles, now, repo

### Community 36 - "Misc 36"
Cohesion: 0.33
Nodes (4): accept, duration, _lastAccepted, ScanCooldown

### Community 37 - "Misc 37"
Cohesion: 0.33
Nodes (4): appTheme, rounded, scheme, _seed

### Community 38 - "Misc 38"
Cohesion: 0.33
Nodes (3): main, retries, show

### Community 39 - "Misc 39"
Cohesion: 0.33
Nodes (4): error, events, scan, success

### Community 41 - "Misc 41"
Cohesion: 0.40
Nodes (3): build, CameraCard, child

### Community 42 - "Misc 42"
Cohesion: 0.40
Nodes (3): main, make, t

## Ambiguous Edges - Review These
- `SukiScan Project Plan` → `file_picker package`  [AMBIGUOUS]
  pubspec.yaml · relation: conceptually_related_to

## Knowledge Gaps
- **446 isolated node(s):** `onRetry`, `scannerBuilder`, `build`, `dbVersion`, `databaseProvider` (+441 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 513 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `SukiScan Project Plan` connect `Send Screen & Lints` to `Plan Docs & App Shell`?**
  _High betweenness centrality (0.009) - this node is a cross-community bridge._
- **What connects `onRetry`, `scannerBuilder`, `build` to the rest of the system?**
  _446 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Riverpod Providers & Screens` be split into smaller, more focused modules?**
  _Cohesion score 0.05952380952380952 - nodes in this community are weakly interconnected._
- **Should `Sync Receive & Test Fakes` be split into smaller, more focused modules?**
  _Cohesion score 0.04591836734693878 - nodes in this community are weakly interconnected._
- **Should `Sync Codec & Chunking` be split into smaller, more focused modules?**
  _Cohesion score 0.041666666666666664 - nodes in this community are weakly interconnected._
- **Should `Plan Docs & App Shell` be split into smaller, more focused modules?**
  _Cohesion score 0.05353535353535353 - nodes in this community are weakly interconnected._

### Low-confidence Hints
_AMBIGUOUS edges — the extractor was unsure. Verify before acting on these._

- **What is the exact relationship between `SukiScan Project Plan` and `file_picker package`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._