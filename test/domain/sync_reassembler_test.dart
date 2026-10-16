import 'package:flutter_test/flutter_test.dart';
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
}
