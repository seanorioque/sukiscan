# SukiScan — Sprint 1

**Goal:** A running app where a store owner can add, edit, and look up items by barcode, with all data persisting locally.
**Scope:** M0 (setup) + M1 (data layer) + M2 (encoding) + M3 (reading), per [plan.md](plan.md).
**Length:** 2 weeks.

## Tasks

### M0 — Project setup
- [x] `flutter create` (Android only) and add packages from plan §3
- [x] Add CAMERA permission + `uses-feature` to AndroidManifest; set `minSdk` (Flutter default 24 ≥ mobile_scanner's 23)
- [x] `app.dart` with theme + routes; `home` screen with menu (Encode, Read, Sell, Sync)
- [ ] `shared/scanner_view.dart`: `MobileScanner` wrapper with format list, permission-denied message + retry

**Done when:** app runs on a real phone and the camera opens.

### M1 — Data layer
- [ ] `core/money.dart`: parse `"12.5"` → `1250`, format → `₱12.50`, reject invalid input
- [ ] `core/clock.dart`: injectable time source
- [ ] `core/db.dart`: schema v1 (`items`, `sales`, `sale_items`, index) with `onCreate`/`onUpgrade`
- [ ] `domain/item.dart` + `data/item_repository.dart` (get, upsert, soft delete)
- [ ] Tests: money parse/format; item CRUD + soft delete via `sqflite_common_ffi`

**Done when:** unit tests pass.

### M2 — Encoding
- [ ] Encode screen: barcode (scan or type), name, price, optional stock
- [ ] Validation: name required, price > 0, barcode not blank
- [ ] Existing barcode → open in edit mode (no duplicate)
- [ ] Delete button → soft delete
- [ ] Riverpod providers wiring screen → repository

**Done when:** items survive an app restart.

### M3 — Reading
- [ ] Read screen: scan → show name, price, stock
- [ ] Not found → "Encode this item?" button opens Encode with barcode pre-filled

**Done when:** scanning a known item shows details in under 1 s.

## Suggested order
M0 → M1 → M2 → M3 (each depends on the previous). Do M1 tests alongside the code, not after.

## Definition of done
- Unit/integration tests green
- Verified on a physical Android phone (not just emulator) with at least one EAN-13 and one UPC-A label
- No float math on money anywhere

## Risks this sprint
- Camera/`minSdk` config issues → do M0 first, test on device on day 1
- Scanning flaky on glossy packaging → keep manual barcode entry working

## Later sprints (outline)
| Sprint | Milestones |
|---|---|
| 2 | M4 Selling |
| 3 | M5 Sync codec + M6 Sync UI |
| 4 | M7 Polish + M8 Release |
