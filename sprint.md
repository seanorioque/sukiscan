# SukiScan — Sprint 1

**Goal:** A running app where a store owner can add, edit, and look up items by barcode, with all data persisting locally.
**Scope:** M0 (setup) + M1 (data layer) + M2 (encoding) + M3 (reading), per [plan.md](plan.md).
**Length:** 2 weeks.

## Tasks

### M0 — Project setup
- [x] `flutter create` (Android only) and add packages from plan §3
- [x] Add CAMERA permission + `uses-feature` to AndroidManifest; set `minSdk` (Flutter default 24 ≥ mobile_scanner's 23)
- [x] `app.dart` with theme + routes; `home` screen with menu (Encode, Read, Sell, Sync)
- [x] `shared/scanner_view.dart`: `MobileScanner` wrapper with format list, permission-denied message + retry

**Done when:** app runs on a real phone and the camera opens.

### M1 — Data layer
- [x] `core/money.dart`: parse `"12.5"` → `1250`, format → `₱12.50`, reject invalid input
- [x] `core/clock.dart`: injectable time source
- [x] `core/db.dart`: schema v1 (`items`, `sales`, `sale_items`, index) with `onCreate`/`onUpgrade`
- [x] `domain/item.dart` + `data/item_repository.dart` (get, upsert, soft delete)
- [x] Tests: money parse/format; item CRUD + soft delete via `sqflite_common_ffi`

**Done when:** unit tests pass.

### M2 — Encoding
- [x] Encode screen: barcode (scan or type), name, price, optional stock
- [x] Validation: name required, price > 0, barcode not blank
- [x] Existing barcode → open in edit mode (no duplicate)
- [x] Delete button → soft delete
- [x] Riverpod providers wiring screen → repository

**Done when:** items survive an app restart.

### M3 — Reading
- [x] Read screen: scan → show name, price, stock
- [x] Not found → "Encode this item?" button opens Encode with barcode pre-filled

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

---

# Sprint 2 — Selling

**Goal:** Ring up a sale with continuous scanning, a live total, and an atomic checkout.
**Scope:** M4, per [plan.md](plan.md). **Length:** 2 weeks.
**Carry-over from Sprint 1:** on-phone checks (camera opens, items survive restart, lookup < 1 s).

## Tasks

### M4 — Selling
- [x] `domain/cart.dart` (pure Dart): `CartLine`, add / +1 if present, increment, decrement (0 removes the line), remove, clear, total in centavos
- [x] Tests: cart add, increment, decrement-to-zero removes line, total correctness
- [x] `data/sale_repository.dart`: `checkout(cart, cashCents?)` saves `sales` + `sale_items` and decrements stock in **one transaction**; `uuid` v4 sale ids; `name_snapshot` / `unit_price_cents` copied from the item
- [x] Tests (`sqflite_common_ffi`): sale + lines + stock all commit, or none do (force a failure mid-way)
- [x] `ScannerView`: per-barcode cooldown (~1.5 s) and beep/vibration on each accepted scan
- [x] Sell screen: continuous scan → cart; each accepted scan adds the item or +1
- [x] Cart list UI: +/– buttons, remove line, clear cart, running total always computed from the lines
- [x] Checkout: optional cash tendered field, shows change due; confirm saves the sale and clears the cart
- [x] Unknown barcode while selling: alert with an option to encode it quickly (reuse Encode `initialBarcode`)
- [x] Manual barcode entry in Sell for damaged labels

**Done when:** sale and stock update are atomic; holding one item in view never double-adds.

## Definition of done
- Tests green; no float math on money
- On phone: exact cash, overpayment, no cash entered; unknown barcode in Sell
- Kill the app mid-checkout → no partial sale saved

## Risks
- Duplicate scans → cooldown is per barcode, test with the item held steady
- Stock going negative → decide the rule up front (allow, or warn and allow)

---

# Sprint 3 — Sync

**Goal:** Copy the item catalog between two phones using only QR codes.
**Scope:** M5 (codec) + M6 (UI), per [plan.md](plan.md) §5. **Length:** 2 weeks.

## Tasks

### M5 — Sync codec (pure Dart)
- [x] `domain/sync_codec.dart`: items → compact JSON (`b n p s u d`) → gzip → base64
- [x] Chunk into frames `POS1|<sessionId>|<index>/<total>|<chunk>`, ~800–1000 chars; frame 0 carries payload length + checksum (CRC32 or SHA-256 prefix) of the full base64 string
- [x] Reassembler: lock onto the first `sessionId`, ignore other sessions, accept frames in any order, ignore duplicates, report progress `n / total`
- [x] Verify checksum → base64-decode → gunzip → parse; corrupted chunk → checksum failure
- [x] Tests: round-trip with 1, 50 and 500 items; out-of-order; duplicates; wrong session ignored; corrupted chunk rejected

**Done when:** round-trip tests pass for 1, 50 and 500 items.

### M6 — Sync UI + merge
- [x] `data/sync_repository.dart`: merge in **one transaction**, upsert by barcode, last-write-wins on `updated_at`, soft deletes applied; keep the incoming `updated_at` (do not restamp)
- [x] Tests: newer wins, older ignored, deletes applied, new items inserted, failure rolls everything back
- [x] Preview counts ("X new, Y updated, Z deleted") before merging
- [x] `send_screen.dart`: QR carousel auto-advancing ~500 ms, manual paging, frame counter
- [x] `receive_screen.dart`: `ScannerView(formats: qrFormats)`, progress `n / total`, preview, **Confirm** to merge
- [x] Error states: wrong/foreign QR, checksum failure rejects the whole transfer, cancel midway writes nothing

**Done when:** two phones sync a 100-item catalog successfully.

## Definition of done
- Tests green
- On two phones: sync 10 / 100 / 300 items; interrupt midway → nothing written

## Risks
- QR too dense to read → tune chunk size on real screens
- Clock differences break last-write-wins → accepted for v1; the preview is the safety net
- Slow transfers at 300+ items → document the limit, no new transport in v1

---

# Sprint 4 — Polish & Release

**Goal:** A signed APK that installs cleanly and passes the full manual checklist.
**Scope:** M7 + M8, per [plan.md](plan.md). **Length:** 1–2 weeks.

## Tasks

### M7 — Polish
- [ ] Empty states (no items yet, empty cart)
- [ ] Clear error messages (camera denied, DB errors, sync failures)
- [ ] Haptics / sound feedback consistent across modules
- [ ] App name and launcher icon (replace the Flutter default)
- [ ] Low-light / glossy packaging pass (torch toggle if needed)
- [ ] Run the full manual device checklist from plan §8

**Done when:** the full manual test checklist passes.

### M8 — Release
- [ ] Release keystore + `key.properties`; keep the keystore out of version control and back it up
- [ ] Signed release APK (`flutter build apk --release`); check `minSdk` and permissions
- [ ] README: what it is, setup, how to sync, known limits (QR sync is for hundreds of items)
- [ ] Screen recording of a scan → sell → sync run
- [ ] Install on a fresh device and run through the main flows

**Done when:** the APK installs cleanly on a fresh device.

## Risks
- Lost keystore means no updates under the same signature → back it up
- Release build behaving differently from debug (R8 / permissions) → test the release APK, not only debug

---

## Roadmap

| Sprint | Milestones | Outcome |
|---|---|---|
| 1 | M0–M3 | Encode and look up items |
| 2 | M4 | Sell with an atomic checkout |
| 3 | M5–M6 | Sync the catalog between phones |
| 4 | M7–M8 | Polished, signed release |

Future ideas (not scheduled): sales history and daily totals, CSV import/export, low-stock alerts, Bluetooth receipt printer, Nearby Connections sync for large catalogs, optional PIN lock. See [plan.md](plan.md) §10.
