import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

enum AuthOutcome {
  /// The user proved who they are.
  granted,

  /// The user backed out or got it wrong.
  cancelled,

  /// The phone has no screen lock (PIN, pattern, password), so there is
  /// nothing to check against.
  noScreenLock,

  /// Something else went wrong.
  failed,
}

/// Asks for the phone's own lock (fingerprint / face / PIN / pattern /
/// password) before a sensitive action.
abstract class DeviceAuth {
  Future<AuthOutcome> verify(String reason);
}

class LocalDeviceAuth implements DeviceAuth {
  final _auth = LocalAuthentication();

  @override
  Future<AuthOutcome> verify(String reason) async {
    try {
      if (!await _auth.isDeviceSupported()) return AuthOutcome.noScreenLock;
      final ok = await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
      return ok ? AuthOutcome.granted : AuthOutcome.cancelled;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.noCredentialsSet => AuthOutcome.noScreenLock,
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.userRequestedFallback ||
        LocalAuthExceptionCode.systemCanceled => AuthOutcome.cancelled,
        _ => AuthOutcome.failed,
      };
    } catch (_) {
      return AuthOutcome.failed;
    }
  }
}

final deviceAuthProvider = Provider<DeviceAuth>((_) => LocalDeviceAuth());
