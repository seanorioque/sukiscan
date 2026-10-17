import 'package:tindascan/shared/app_feedback.dart';

/// Records which feedback a screen asked for instead of buzzing the phone.
class RecordingFeedback implements AppFeedback {
  final events = <String>[];

  @override
  Beep get beep => throw UnimplementedError('RecordingFeedback plays nothing');

  @override
  void scan() => events.add('scan');

  @override
  void success() => events.add('success');

  @override
  void error() => events.add('error');
}
