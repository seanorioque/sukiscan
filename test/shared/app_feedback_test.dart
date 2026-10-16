import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukiscan/shared/app_feedback.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];

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

  setUp(() {
    calls.clear();
    mockPlatform();
  });
  tearDown(
    () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('scan: system click + medium tick', () async {
    const AppFeedback().scan();
    await settle();

    expect(calls.map((c) => c.method), [
      'SystemSound.play',
      'HapticFeedback.vibrate',
    ]);
    expect(calls[0].arguments, 'SystemSoundType.click');
    expect(calls[1].arguments, 'HapticFeedbackType.mediumImpact');
  });

  test('success: system click + strong tick', () async {
    const AppFeedback().success();
    await settle();

    expect(calls[0].arguments, 'SystemSoundType.click');
    expect(calls[1].arguments, 'HapticFeedbackType.heavyImpact');
  });

  test('error: one long buzz and no click', () async {
    const AppFeedback().error();
    await settle();

    expect(calls.map((c) => c.method), ['HapticFeedback.vibrate']);
    expect(calls.single.arguments, isNull); // plain vibrate()
  });

  test('the three kinds feel different', () async {
    const f = AppFeedback();
    f.scan();
    f.success();
    f.error();
    await settle();
    final haptics = [
      for (final c in calls)
        if (c.method == 'HapticFeedback.vibrate') c.arguments,
    ];
    expect(haptics.toSet(), hasLength(3));
  });

  test('a platform failure never throws into the calling flow', () async {
    mockPlatform((call) async => throw PlatformException(code: 'no vibrator'));

    const f = AppFeedback();
    f.scan();
    f.success();
    f.error();
    await settle(); // an unhandled async error here would fail the test
  });
}
