import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:math' show Random;

import 'item.dart';

/// Items → compact JSON → gzip → base64 (plan §5). Pure Dart, no Flutter.
///
/// Compact keys: b=barcode, n=name, p=price_cents, s=stock_qty,
/// u=updated_at (epoch ms), d=deleted (0/1). Soft-deleted items must be
/// included by the caller so deletions propagate.
String encodeCatalog(List<Item> items) {
  final json = jsonEncode([
    for (final i in items)
      {
        'b': i.barcode,
        'n': i.name,
        'p': i.priceCents,
        's': i.stockQty,
        'u': i.updatedAt,
        'd': i.deleted ? 1 : 0,
      },
  ]);
  return base64Encode(gzip.encode(utf8.encode(json)));
}

/// Reverse of [encodeCatalog]. The data comes from another phone's camera, so
/// everything is checked: any problem throws a [FormatException] and nothing
/// partial is returned.
List<Item> decodeCatalog(String payload) {
  try {
    final json = jsonDecode(utf8.decode(gzip.decode(base64Decode(payload))));
    if (json is! List) throw const FormatException('not a list');
    return [for (final e in json) _item(e)];
  } on FormatException {
    rethrow;
  } catch (_) {
    // gzip errors (e.g. corrupted/truncated data), bad UTF-8, ...
    throw const FormatException('Invalid sync data');
  }
}

Item _item(Object? e) {
  if (e is! Map) throw const FormatException('bad item');
  final b = e['b'], n = e['n'], p = e['p'], s = e['s'], u = e['u'], d = e['d'];
  if (b is! String || b.trim().isEmpty) {
    throw const FormatException('bad barcode');
  }
  if (n is! String || n.trim().isEmpty) {
    throw const FormatException('bad name');
  }
  if (p is! int || p <= 0) throw const FormatException('bad price');
  if (s is! int) throw const FormatException('bad stock'); // may be negative
  if (u is! int || u < 0) throw const FormatException('bad updated_at');
  if (d != 0 && d != 1) throw const FormatException('bad deleted flag');
  return Item(
    barcode: b,
    name: n,
    priceCents: p,
    stockQty: s,
    updatedAt: u,
    deleted: d == 1,
  );
}

// ---------------------------------------------------------------------------
// Framing (plan §5)
//
//   frame 0 : POS1|<sessionId>|0/<total>|<payloadLength>|<crc32>|<chunk>
//   frame i : POS1|<sessionId>|<i>/<total>|<chunk>          (i > 0)
//
// Indexes are 0-based. The payload is the base64 string from [encodeCatalog];
// base64 never contains '|', so splitting on '|' is unambiguous.
// payloadLength and crc32 describe the FULL base64 string, so the receiver can
// check the reassembled data before decoding it.
// ---------------------------------------------------------------------------

/// Base64 characters per frame: dense enough to be compact, small enough for a
/// phone camera to read the QR reliably (tune on real screens).
const frameChunkSize = 900;

const _magic = 'POS1';
final _sessionRe = RegExp(r'^[A-Za-z0-9]+$');
final _chunkRe = RegExp(r'^[A-Za-z0-9+/=]+$');
final _crcRe = RegExp(r'^[0-9a-f]{8}$');

/// Splits [payload] into frame strings, ready to be shown as QR codes.
/// [sessionId] defaults to a short random id so a receiver can ignore frames
/// that belong to a different transfer.
List<String> buildFrames(
  String payload, {
  String? sessionId,
  int chunkSize = frameChunkSize,
}) {
  if (payload.isEmpty) throw ArgumentError('payload is empty');
  if (chunkSize <= 0) throw ArgumentError('chunkSize must be positive');
  final sid = sessionId ?? _newSessionId();
  if (!_sessionRe.hasMatch(sid)) throw ArgumentError('bad sessionId');

  final total = (payload.length + chunkSize - 1) ~/ chunkSize;
  final crc = crc32Hex(payload);
  return [
    for (var i = 0; i < total; i++)
      [
        _magic,
        sid,
        '$i/$total',
        if (i == 0) ...[payload.length, crc],
        payload.substring(
          i * chunkSize,
          (i + 1) * chunkSize > payload.length
              ? payload.length
              : (i + 1) * chunkSize,
        ),
      ].join('|'),
  ];
}

/// One parsed frame. [payloadLength] and [checksum] are set on frame 0 only.
class SyncFrame {
  const SyncFrame({
    required this.sessionId,
    required this.index,
    required this.total,
    required this.chunk,
    this.payloadLength,
    this.checksum,
  });

  final String sessionId;
  final int index;
  final int total;
  final String chunk;
  final int? payloadLength;
  final String? checksum;

  /// Parses text scanned from a QR code. Anything that isn't a well-formed
  /// frame throws [FormatException] (e.g. a QR code that isn't ours).
  factory SyncFrame.parse(String raw) {
    final parts = raw.split('|');
    if (parts.length < 4 || parts[0] != _magic) {
      throw const FormatException('not a SukiScan frame');
    }
    final sid = parts[1];
    if (!_sessionRe.hasMatch(sid)) throw const FormatException('bad session');

    final pos = parts[2].split('/');
    final index = pos.length == 2 ? int.tryParse(pos[0]) : null;
    final total = pos.length == 2 ? int.tryParse(pos[1]) : null;
    if (index == null ||
        total == null ||
        total < 1 ||
        index < 0 ||
        index >= total) {
      throw const FormatException('bad frame position');
    }

    // Only frame 0 has the length + checksum header.
    if (parts.length != (index == 0 ? 6 : 4)) {
      throw const FormatException('bad frame layout');
    }
    final chunk = parts.last;
    if (!_chunkRe.hasMatch(chunk)) throw const FormatException('bad chunk');

    if (index != 0) {
      return SyncFrame(
        sessionId: sid,
        index: index,
        total: total,
        chunk: chunk,
      );
    }
    final length = int.tryParse(parts[3]);
    if (length == null || length < 1 || !_crcRe.hasMatch(parts[4])) {
      throw const FormatException('bad frame 0 header');
    }
    return SyncFrame(
      sessionId: sid,
      index: 0,
      total: total,
      chunk: chunk,
      payloadLength: length,
      checksum: parts[4],
    );
  }
}

String _newSessionId() {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final r = Random.secure();
  return String.fromCharCodes(
    List.generate(6, (_) => alphabet.codeUnitAt(r.nextInt(alphabet.length))),
  );
}

/// CRC-32 (IEEE, as in zip/png) of the string's UTF-8 bytes, as 8 lowercase hex digits.
String crc32Hex(String s) {
  var crc = 0xFFFFFFFF;
  for (final byte in utf8.encode(s)) {
    crc ^= byte;
    for (var k = 0; k < 8; k++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return ((crc ^ 0xFFFFFFFF) & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
}
