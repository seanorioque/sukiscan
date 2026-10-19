import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tindascan/shared/app_feedback.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[]; // vibrations
  final beeps = <String>[];
  var beepFails = false;

  void mockPlatform([Future<Object?> Function(MethodCall)? handler]) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      handler ??
          (call) async {
            calls.add(call);
            return null;
          },
    );
  }

  Future<void> record(String name) async {
    if (beepFails) throw PlatformException(code: 'no audio');
    beeps.add(name);
  }

  AppFeedback feedback() => AppFeedback(beep: record);

  setUp(() {
    calls.clear();
    beeps.clear();
    beepFails = false;
    mockPlatform();
  });
  tearDown(
    () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('scan: short beep + medium tick', () async {
    feedback().scan();
    await settle();

    expect(beeps, ['scan']);
    expect(calls.single.method, 'HapticFeedback.vibrate');
    expect(calls.single.arguments, 'HapticFeedbackType.mediumImpact');
  });

  test('success: two-note beep + strong tick', () async {
    feedback().success();
    await settle();

    expect(beeps, ['success']);
    expect(calls.single.arguments, 'HapticFeedbackType.heavyImpact');
  });

  test('error: low buzz + one long vibration', () async {
    feedback().error();
    await settle();

    expect(beeps, ['error']);
    expect(calls.single.method, 'HapticFeedback.vibrate');
    expect(calls.single.arguments, isNull); // plain vibrate()
  });

  test('the three kinds sound and feel different', () async {
    final f = feedback();
    f.scan();
    f.success();
    f.error();
    await settle();

    expect(beeps.toSet(), hasLength(3));
    expect({for (final c in calls) c.arguments}, hasLength(3));
  });

  test('a platform failure never throws into the calling flow', () async {
    mockPlatform((call) async => throw PlatformException(code: 'no vibrator'));
    beepFails = true;

    final f = feedback();
    f.scan();
    f.success();
    f.error();
    await settle(); // an unhandled async error here would fail the test
  });
}
