import 'package:flutter_test/flutter_test.dart';
import 'package:sukiscan/domain/item.dart';
import 'package:sukiscan/domain/sync_codec.dart';

void main() {
  final payload = List.generate(3500, (i) => 'ABCDEFGH'[i % 8]).join();
  List<String> frames(String session, [String? p]) =>
      buildFrames(p ?? payload, sessionId: session, chunkSize: 900); // 4 frames

  test('starts empty', () {
    final r = SyncReassembler();
    expect(r.sessionId, isNull);
    expect(r.total, isNull);
    expect(r.received, 0);
    expect(r.isComplete, isFalse);
    expect(r.assembled, isNull);
  });

  test('locks onto the first frame and reports progress n / total', () {
    final r = SyncReassembler();
    final f = frames('aaa');
    expect(r.add(f[2]), FrameResult.accepted); // not frame 0
    expect(r.sessionId, 'aaa');
    expect(r.total, 4);
    expect(r.received, 1);

    r.add(f[0]);
    expect(r.received, 2);
    r.add(f[3]);
    expect(r.received, 3);
    expect(r.isComplete, isFalse);
    expect(r.assembled, isNull);

    r.add(f[1]);
    expect(r.received, 4);
    expect(r.isComplete, isTrue);
  });

  test('frames in any order rebuild the same payload', () {
    final f = frames('aaa');
    for (final order in [
      [0, 1, 2, 3],
      [3, 2, 1, 0],
      [2, 0, 3, 1],
      [1, 3, 0, 2],
    ]) {
      final r = SyncReassembler();
      for (final i in order) {
        r.add(f[i]);
      }
      expect(r.assembled, payload, reason: '$order');
    }
  });

  test('duplicates are ignored and do not advance progress', () {
    final r = SyncReassembler();
    final f = frames('aaa');
    expect(r.add(f[1]), FrameResult.accepted);
    expect(r.add(f[1]), FrameResult.duplicate);
    expect(r.add(f[1]), FrameResult.duplicate);
    expect(r.received, 1);

    // The first copy wins, even if a later "duplicate" has different content.
    final tampered = f[1].replaceFirst(RegExp(r'\|[^|]*$'), '|ZZZZ');
    expect(r.add(tampered), FrameResult.duplicate);
    for (final i in [0, 2, 3]) {
      r.add(f[i]);
    }
    expect(r.assembled, payload);
  });

  test('frames from another session are ignored', () {
    final r = SyncReassembler();
    final mine = frames('aaa');
    final other = frames('bbb', 'Z' * 3500);

    r.add(mine[0]);
    expect(r.add(other[1]), FrameResult.otherSession);
    expect(r.add(other[0]), FrameResult.otherSession);
    expect(r.received, 1);
    expect(r.sessionId, 'aaa');

    for (final i in [1, 2, 3]) {
      r.add(mine[i]);
    }
    expect(r.assembled, payload);
  });

  test('a session id match with a different frame count is invalid', () {
    final r = SyncReassembler();
    r.add(frames('aaa')[0]); // total 4
    final shorter = buildFrames(
      'A' * 1000,
      sessionId: 'aaa',
      chunkSize: 900,
    ); // total 2
    expect(r.add(shorter[1]), FrameResult.invalid);
    expect(r.received, 1);
  });

  test('non-frame QR codes are invalid and do not lock a session', () {
    final r = SyncReassembler();
    expect(r.add('https://example.com'), FrameResult.invalid);
    expect(r.add(''), FrameResult.invalid);
    expect(r.sessionId, isNull);
    expect(r.add(frames('aaa')[0]), FrameResult.accepted); // still usable
  });

  test('frame 0 supplies payload length and checksum, whenever it arrives', () {
    final r = SyncReassembler();
    final f = frames('aaa');
    r.add(f[3]);
    expect(r.payloadLength, isNull);
    expect(r.checksum, isNull);
    r.add(f[0]);
    expect(r.payloadLength, 3500);
    expect(r.checksum, crc32Hex(payload));
  });

  test('a single-frame transfer completes immediately', () {
    final r = SyncReassembler();
    r.add(buildFrames('QUJD', sessionId: 's').single);
    expect(r.isComplete, isTrue);
    expect(r.assembled, 'QUJD');
  });

  group('decode', () {
    final items = [
      for (var i = 0; i < 120; i++)
        Item(
          barcode: '4800${(i * 7919 % 100000000).toString().padLeft(9, '0')}',
          name: 'Item ${i * 31 % 977} brand ${i % 53}',
          priceCents: 1000 + (i * 37 % 9000),
          stockQty: i % 30,
          updatedAt: 1760600000000 + i * 1234567,
          deleted: i % 10 == 0,
        ),
    ];
    // Several frames (chunkSize 500 keeps the test payload multi-frame).
    final good = buildFrames(
      encodeCatalog(items),
      sessionId: 'aaa',
      chunkSize: 500,
    );

    SyncReassembler feed(Iterable<String> frames) {
      final r = SyncReassembler();
      for (final f in frames) {
        r.add(f);
      }
      return r;
    }

    String corrupt(String frame) {
      // Change one base64 character of the chunk to a different valid one.
      final i = frame.length - 3;
      return frame.substring(0, i) +
          (frame[i] == 'A' ? 'B' : 'A') +
          frame.substring(i + 1);
    }

    test('verified transfer decodes to the original items', () {
      expect(good.length, greaterThan(2));
      final back = feed(good).decode();
      expect(back.map((i) => i.toMap()), items.map((i) => i.toMap()));
    });

    test('works whatever order the frames arrived in', () {
      final back = feed(good.reversed).decode();
      expect(back, hasLength(items.length));
    });

    test('a misread chunk is a checksum failure', () {
      for (var i = 0; i < good.length; i++) {
        final frames = [...good]..[i] = corrupt(good[i]);
        expect(
          () => feed(frames).decode(),
          throwsA(isA<SyncChecksumException>()),
          reason: 'corrupted frame $i',
        );
      }
    });

    test('a chunk that lost characters is a checksum failure', () {
      final frames = [...good];
      frames[1] = frames[1].substring(0, frames[1].length - 4);
      expect(
        () => feed(frames).decode(),
        throwsA(isA<SyncChecksumException>()),
      );
    });

    test('a tampered frame 0 header is a checksum failure', () {
      final parts = good[0].split('|');
      parts[4] = crc32Hex('something else');
      final frames = [...good]..[0] = parts.join('|');
      expect(
        () => feed(frames).decode(),
        throwsA(isA<SyncChecksumException>()),
      );
    });

    test('decoding before every frame arrived is a StateError', () {
      expect(() => feed(good.take(2)).decode(), throwsStateError);
      expect(() => SyncReassembler().decode(), throwsStateError);
    });

    test('intact data that is not a catalog is a FormatException', () {
      // Valid base64, correct length and CRC, but not gzip.
      final r = feed(buildFrames('QUJDRA==', sessionId: 's'));
      expect(r.decode, throwsFormatException);
    });
  });

  group('full pipeline round trip (items -> frames -> reassembler -> items)', () {
    for (final n in [1, 50, 500]) {
      test('$n item(s)', () {
        final items = [
          for (var i = 0; i < n; i++)
            Item(
              barcode:
                  '4800${(i * 7919 % 100000000).toString().padLeft(9, '0')}',
              name: 'Item ${i * 31 % 977} brand ${i % 53} ₱',
              priceCents: 1000 + (i * 37 % 9000),
              stockQty: (i % 30) - 2,
              updatedAt: 1760600000000 + i * 1234567,
              deleted: i % 7 == 0,
            ),
        ];
        final frames = buildFrames(encodeCatalog(items));
        // Shuffle deterministically and re-scan every frame twice, as a camera would.
        final scanned = [...frames.reversed, ...frames];
        final r = SyncReassembler();
        for (final f in scanned) {
          r.add(f);
        }
        expect(r.received, frames.length);
        final back = r.decode();
        expect(back.map((i) => i.toMap()), items.map((i) => i.toMap()));
      });
    }
  });
}
