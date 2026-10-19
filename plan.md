# TindaScan — Project Plan

> Working title. An offline Android barcode point-of-sale app with QR-based device-to-device sync.

## 1. Overview

TindaScan lets a small store encode its products by barcode, look them up instantly, ring up sales with a live running total, and copy its catalog to another phone by scanning QR codes. Everything is stored locally on the device, and no internet connection or server is required.

### Goals
- Work fully offline on low- to mid-range Android phones
- Scan common retail 1D barcodes quickly and reliably
- Keep money math exact (integer centavos, no floating point)
- Transfer the item catalog between devices using only cameras and screens

### Non-goals (v1)
- iOS build
- Cloud backup or a web dashboard
- Receipt printing or payment integration
- Multi-user accounts / roles
- Syncing sales history between devices

---

## 2. Modules

### 2.1 Encoding
Add or edit items.
- Fill the barcode field by scanning (1D formats) or typing it manually
- Fields: barcode, item name, price (₱), stock quantity (optional)
- Validation: name required, price > 0, no blank barcode; optional EAN-13/UPC check-digit validation
- If the barcode already exists, open it in edit mode instead of creating a duplicate
- Soft delete (`deleted = 1`) so deletions propagate during sync

### 2.2 Reading
Look up an item by scanning it.
- Scan a 1D barcode and show the item name, price, and stock
- If the barcode is not found, show a "Not found — encode this item?" shortcut that opens Encoding with the barcode pre-filled

### 2.3 Selling
Ring up a sale.
- Continuous scan mode; each accepted scan adds the item to the cart, or adds +1 if it is already there
- Per-barcode cooldown (~1.5 s) to stop duplicate scans of the same item, with beep/vibration feedback on each accepted scan
- Cart list with +/– quantity buttons, remove line, and clear cart
- Running total is always computed from the cart lines
- Checkout:
  - Optional cash tendered field that shows change due
  - Saves `sales` + `sale_items` and decrements stock in **one SQLite transaction**
- Unknown barcode during selling: alert the user with an option to encode it quickly

### 2.4 Sync (QR transfer)
Copy the item catalog from one device to another.
- **Sender:** serialize items → gzip → base64 → split into chunks → display as QR frames that auto-cycle
- **Receiver:** scan frames in any order, show progress (`n / total`), then reassemble, verify, and merge
- Merge rule: upsert by barcode, **last-write-wins on `updated_at`**, soft deletes applied
- The entire merge runs in a single transaction; a failed checksum rejects the whole transfer

---

## 3. Tech Stack

| Concern | Choice |
|---|---|
| Framework | Flutter (stable), Android only |
| Scanning | `mobile_scanner` (ML Kit on Android) |
| QR generation | `qr_flutter` |
| Local storage | `sqflite` (SQLite on device) |
| State management | `flutter_riverpod` |
| Compression | `dart:io` `GZipCodec` + `dart:convert` base64 |
| Utilities | `path`, `intl` (₱ formatting), `uuid` (sale IDs) |
| Testing | `flutter_test`, `sqflite_common_ffi` for DB tests on desktop |

### Setup
```bash
flutter create --org com.yourname --platforms android tindascan
cd tindascan
flutter pub add mobile_scanner qr_flutter sqflite path flutter_riverpod intl uuid
flutter pub add --dev sqflite_common_ffi
```

`android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="false" />
```

Set `minSdk` in `android/app/build.gradle(.kts)` to at least the version `mobile_scanner`'s README requires.

---

## 4. Data Model

All money is stored as **integer centavos** (₱12.50 → `1250`).

```sql
CREATE TABLE items (
  barcode     TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  price_cents INTEGER NOT NULL CHECK (price_cents > 0),
  stock_qty   INTEGER NOT NULL DEFAULT 0,
  updated_at  INTEGER NOT NULL,          -- epoch ms
  deleted     INTEGER NOT NULL DEFAULT 0 -- soft delete
);

CREATE TABLE sales (
  id          TEXT PRIMARY KEY,          -- uuid v4
  created_at  INTEGER NOT NULL,
  total_cents INTEGER NOT NULL,
  cash_cents  INTEGER                    -- nullable
);

CREATE TABLE sale_items (
  sale_id          TEXT NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  barcode          TEXT NOT NULL,
  name_snapshot    TEXT NOT NULL,
  unit_price_cents INTEGER NOT NULL,
  qty              INTEGER NOT NULL CHECK (qty > 0)
);

CREATE INDEX idx_sale_items_sale ON sale_items(sale_id);
```

`name_snapshot` and `unit_price_cents` keep past receipts accurate after items are re-priced.

Version the schema with `onCreate`/`onUpgrade` in `sqflite`, starting at `version: 1`.

---

## 5. Sync Protocol

### Payload
Compact JSON array with short keys:
```json
[{"b":"4800016644290","n":"Lucky Me Pancit Canton","p":1500,"s":24,"u":1760600000000,"d":0}]
```

### Framing
```
POS1|<sessionId>|<index>/<total>|<chunk>
```
- `sessionId`: short random ID, so the receiver ignores frames from another transfer
- Frame `0` also carries the payload length and a checksum (CRC32 or SHA-256 prefix) of the full base64 string
- Chunk size: ~800–1000 characters (balances density against camera readability)
- Frames auto-advance every ~500 ms; the sender can also page through them manually

### Receiver flow
1. Scan any frame and lock onto its `sessionId`
2. Store chunks in a `Map<int, String>` and ignore duplicates
3. Once all `total` chunks are in, concatenate → verify checksum → base64-decode → gunzip → parse
4. Show a preview ("X new, Y updated, Z deleted"), then **Confirm** to merge
5. Merge in one transaction using last-write-wins

### Limits
QR sync is designed for small catalogs (hundreds of items). For thousands of items, consider Nearby Connections or file export/share in a later version.

---

## 6. Architecture

```
lib/
  main.dart
  app.dart                     # MaterialApp, routes, theme
  core/
    db.dart                    # open DB, migrations
    money.dart                 # cents <-> "₱1,234.50"
    clock.dart                 # injectable time source (testability)
  domain/
    item.dart
    cart.dart                  # CartLine, cart totals (pure Dart)
    sync_codec.dart            # encode/chunk/reassemble/decode (pure Dart)
  data/
    item_repository.dart
    sale_repository.dart
    sync_repository.dart       # merge logic
  features/
    home/                      # module menu
    encode/
    read/
    sell/
    sync/
      send_screen.dart
      receive_screen.dart
  shared/
    scanner_view.dart          # reusable MobileScanner wrapper (formats, cooldown, feedback)
test/
  domain/                      # cart math, sync codec round-trips
  data/                        # repository + merge tests via sqflite_common_ffi
```

Layering is UI → Riverpod providers → repositories → SQLite. The domain layer is pure Dart with no Flutter imports, so it is easy to unit test.

### Scanner formats
- Encode / Read / Sell: `ean13`, `ean8`, `upcA`, `upcE`, `code128`, `code39`
- Sync receive: `qrCode` only

---

## 7. Milestones

| # | Milestone | Deliverables | Done when |
|---|---|---|---|
| M0 | Project setup | Flutter project, packages, camera permission, home menu | App runs on device and the camera opens |
| M1 | Data layer | Schema, migrations, `money.dart`, repositories | Unit tests pass for CRUD + cents formatting |
| M2 | Encoding | Scan/type barcode, item form, edit existing, soft delete | Items persist across app restarts |
| M3 | Reading | Scan → details, not-found → encode shortcut | Lookup of a known item shows its details in under 1 s |
| M4 | Selling | Cart, cooldown, quantities, running total, checkout transaction, change due | Sale and stock update are atomic; no double-adds from one scan |
| M5 | Sync codec | Pure-Dart encode/chunk/reassemble/checksum | Round-trip tests pass for 1, 50, and 500 items |
| M6 | Sync UI | Sender carousel, receiver progress, preview + confirm, merge | Two phones sync a 100-item catalog successfully |
| M7 | Polish | Empty states, error messages, haptics, app icon, name | Full manual test checklist passes |
| M8 | Release | Signed release APK, README, screen recording | APK installs cleanly on a fresh device |

---

## 8. Testing Plan

### Unit (pure Dart)
- Cents parsing/formatting: `"12.5"` → `1250`, `1250` → `"₱12.50"`, reject invalid input
- Cart: add, increment, decrement to zero removes the line, total correctness
- Sync codec: round-trip integrity, out-of-order chunks, duplicate chunks, wrong session ignored, corrupted chunk → checksum failure

### Integration (sqflite_common_ffi)
- Item upsert/edit/soft delete
- Checkout transaction: sale + lines + stock decrement all commit, or none do
- Merge: newer wins, older ignored, deletes applied, new items inserted

### Manual device checklist
- [x] Camera permission denied → clear message + retry
- [ x] Scan EAN-13, UPC-A, Code 128 labels from real products
- [ ] Holding one item in view adds it only once per cooldown
- [ ] Low light / glossy packaging
- [ ] Unknown barcode in Read and Sell
- [ ] Checkout with exact cash, overpayment, and no cash entered
- [ ] Sync 10 / 100 / 300 items between two different phones
- [ ] Interrupt a sync midway → nothing is written
- [ ] Kill the app mid-checkout → no partial sale saved

---

## 9. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Duplicate scans in Selling | Per-barcode cooldown + feedback on accepted scans |
| Float rounding in totals | Integer centavos everywhere |
| Large catalogs make QR sync slow | Gzip + chunking; document limits; future Nearby/file export |
| Clock differences between devices break last-write-wins | Acceptable for v1; show a merge preview before confirming |
| Damaged/unreadable labels | Manual barcode entry in Encoding and Selling |
| Data loss on uninstall | Future: export/import a backup file |

---

## 10. Future Ideas
- Sales history screen and daily totals report
- CSV export/import of the catalog
- Low-stock alerts
- Bluetooth receipt printer support
- Nearby Connections sync for large catalogs
- Optional PIN lock for edits and price changes