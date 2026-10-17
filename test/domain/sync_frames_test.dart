import 'package:flutter_test/flutter_test.dart';
import 'package:tindascan/domain/sync_codec.dart';

import '../helpers/catalog.dart';

void main() {
  test('crc32 matches the standard check values', () {
    expect(crc32Hex('123456789'), 'cbf43926'); // the CRC-32 test vector
    expect(crc32Hex(''), '00000000');
    expect(crc32Hex('a'), 'e8b7be43');
  });

  group('buildFrames', () {
    final payload = List.generate(2500, (i) => 'ABCDEFGH'[i % 8]).join();

    test('splits into numbered frames that rebuild the payload', () {
      final frames = buildFrames(payload, sessionId: 'abc123', chunkSize: 900);
      expect(frames, hasLength(3)); // 900 + 900 + 700

      final parsed = frames.map(SyncFrame.parse).toList();
      expect([for (final f in parsed) f.index], [0, 1, 2]);
      expect(parsed.every((f) => f.total == 3), isTrue);
      expect(parsed.every((f) => f.sessionId == 'abc123'), isTrue);
      expect(parsed.map((f) => f.chunk).join(), payload);
      expect(parsed.every((f) => f.chunk.length <= 900), isTrue);
    });

    test('frame text matches POS1|session|index/total|...', () {
      final frames = buildFrames(payload, sessionId: 'abc123', chunkSize: 900);
      expect(
        frames[0],
        startsWith('POS1|abc123|0/3|2500|${crc32Hex(payload)}|'),
      );
      expect(frames[1], startsWith('POS1|abc123|1/3|'));
      expect(frames[1].split('|'), hasLength(4)); // no header after frame 0
    });

    test('only frame 0 carries payload length and checksum', () {
      final parsed = buildFrames(payload, chunkSize: 900).map(SyncFrame.parse);
      final first = parsed.first;
      expect(first.payloadLength, 2500);
      expect(first.checksum, crc32Hex(payload));
      for (final f in parsed.skip(1)) {
        expect(f.payloadLength, isNull);
        expect(f.checksum, isNull);
      }
    });

    test('a short payload is a single frame', () {
      final frames = buildFrames('QUJD', sessionId: 's');
      expect(frames, ['POS1|s|0/1|4|${crc32Hex('QUJD')}|QUJD']);
    });

    test('payload exactly a multiple of the chunk size has no empty frame', () {
      final frames = buildFrames('A' * 1800, chunkSize: 900);
      expect(frames, hasLength(2));
      expect(
        frames.map(SyncFrame.parse).every((f) => f.chunk.length == 900),
        isTrue,
      );
    });

    test('session ids are short, alphanumeric and differ per transfer', () {
      final a = SyncFrame.parse(buildFrames(payload).first).sessionId;
      final b = SyncFrame.parse(buildFrames(payload).first).sessionId;
      expect(a, matches(RegExp(r'^[a-z0-9]{6}$')));
      expect(a, isNot(b));
    });

    test('a real 500-item catalog fits in frames of at most 1000 chars', () {
      final payload = encodeCatalog(catalog(500));
      final frames = buildFrames(payload);
      expect(frames.every((f) => f.length <= 1000), isTrue);
      expect(frames.length, greaterThan(1));
      final back = frames.map(SyncFrame.parse).map((f) => f.chunk).join();
      expect(decodeCatalog(back), hasLength(500));
    });

    test('rejects bad arguments', () {
      expect(() => buildFrames(''), throwsArgumentError);
      expect(() => buildFrames('QUJD', chunkSize: 0), throwsArgumentError);
      expect(() => buildFrames('QUJD', sessionId: 'a|b'), throwsArgumentError);
      expect(() => buildFrames('QUJD', sessionId: ''), throwsArgumentError);
    });
  });

  group('SyncFrame.parse rejects', () {
    final crc = crc32Hex('QUJD');
    void rejects(String name, String raw) => test(
      name,
      () => expect(() => SyncFrame.parse(raw), throwsFormatException),
    );

    rejects('a random QR code', 'https://example.com');
    rejects('empty text', '');
    rejects('another version', 'POS2|s|0/1|4|$crc|QUJD');
    rejects('a missing session', 'POS1||0/1|4|$crc|QUJD');
    rejects('a session with odd characters', 'POS1|s-1|0/1|4|$crc|QUJD');
    rejects('a non-numeric position', 'POS1|s|a/b|4|$crc|QUJD');
    rejects('a position without a slash', 'POS1|s|01|4|$crc|QUJD');
    rejects('index equal to total', 'POS1|s|1/1|QUJD');
    rejects('a negative index', 'POS1|s|-1/2|QUJD');
    rejects('zero total', 'POS1|s|0/0|4|$crc|QUJD');
    rejects('frame 0 without its header', 'POS1|s|0/2|QUJD');
    rejects('a later frame with a header', 'POS1|s|1/2|4|$crc|QUJD');
    rejects('a bad checksum', 'POS1|s|0/1|4|XYZ|QUJD');
    rejects('an uppercase checksum', 'POS1|s|0/1|4|CBF43926|QUJD');
    rejects('a zero payload length', 'POS1|s|0/1|0|$crc|QUJD');
    rejects('an empty chunk', 'POS1|s|1/2|');
    rejects('a chunk with non-base64 characters', 'POS1|s|1/2|QU JD!');
  });
}
