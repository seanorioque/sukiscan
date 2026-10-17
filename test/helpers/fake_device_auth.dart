import 'package:tindascan/data/device_auth.dart';

/// Stands in for the phone's lock screen: answers with [outcome] and records
/// every time it was asked.
class FakeDeviceAuth implements DeviceAuth {
  AuthOutcome outcome = AuthOutcome.granted;
  final reasons = <String>[];

  @override
  Future<AuthOutcome> verify(String reason) async {
    reasons.add(reason);
    return outcome;
  }
}
