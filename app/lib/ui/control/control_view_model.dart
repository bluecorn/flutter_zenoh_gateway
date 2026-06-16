import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zenoh_ros_poc/data/models/pose_command.dart';
import 'package:zenoh_ros_poc/providers/providers.dart';
import 'package:zenoh_ros_poc/ui/connection/connection_view_model.dart';

/// The outcome of the most recent pose command — a sealed union so a
/// rejection carries its reason while the other states stay payload-free.
sealed class SendResult {
  const SendResult();
}

/// No command has been sent (or the last result has been reset).
class IdleResult extends SendResult {
  /// Creates an [IdleResult].
  const IdleResult();
}

/// A command is in flight; the gateway ack has not yet arrived.
class SendingResult extends SendResult {
  /// Creates a [SendingResult].
  const SendingResult();
}

/// The gateway accepted and forwarded the command (`ok:true`).
class DeliveredResult extends SendResult {
  /// Creates a [DeliveredResult].
  const DeliveredResult();
}

/// The gateway rejected the command for a business reason (`ok:false`).
class RejectedResult extends SendResult {
  /// Creates a [RejectedResult] carrying the gateway's [reason].
  const RejectedResult(this.reason);

  /// The gateway's reject reason (e.g. `unknown_pose`).
  final String reason;
}

/// A transport error occurred — timeout, Zenoh-error, not connected, or an
/// undecodable reply. ALL such failures arrive here through one catch path.
class ErrorResult extends SendResult {
  /// Creates an [ErrorResult].
  const ErrorResult();
}

/// Immutable control state — the connection-derived [canSend] gate plus the
/// most recent send [result].
class ControlState {
  /// Creates a [ControlState].
  const ControlState({
    this.canSend = false,
    this.result = const IdleResult(),
  });

  /// Whether pose commands may be issued (true only when connected).
  final bool canSend;

  /// The outcome of the most recent pose command.
  final SendResult result;

  /// Returns a copy with the given fields replaced.
  ControlState copyWith({bool? canSend, SendResult? result}) {
    return ControlState(
      canSend: canSend ?? this.canSend,
      result: result ?? this.result,
    );
  }
}

/// Issues pose commands through the (mockable) repository, gated on
/// connection, and maps the gateway ack to a [SendResult] state machine.
///
/// When the connection is not [ConnectionStatus.connected], [sendPose] is a
/// no-op — nothing reaches the repository — and [ControlState.canSend] is
/// false. A 2nd tap while a send is in flight ([SendingResult]) is also a
/// no-op (decision 4: ignore in-flight taps; no last-wins race).
class ControlViewModel extends Notifier<ControlState> {
  @override
  ControlState build() {
    final connection = ref.watch(connectionViewModelProvider);
    final connected = connection.status == ConnectionStatus.connected;
    return ControlState(canSend: connected);
  }

  /// Sends [pose] through the repository when allowed; otherwise a no-op.
  ///
  /// Gated on [ControlState.canSend] (disconnected) AND on no send already
  /// being in flight. Drives the result through [SendingResult] then maps:
  /// `Ack(ok:true)` → [DeliveredResult], `Ack(ok:false)` →
  /// [RejectedResult] (surfacing the reason), and ANY thrown transport-error
  /// → [ErrorResult] via a single catch path (MODIFY-1 — no sentinel ack).
  Future<void> sendPose(PoseCommand pose) async {
    if (!state.canSend || state.result is SendingResult) return;
    state = state.copyWith(result: const SendingResult());
    try {
      final ack = await ref.read(robotRepositoryProvider).sendPose(pose);
      state = state.copyWith(
        result: ack.ok
            ? const DeliveredResult()
            : RejectedResult(ack.error ?? 'unknown'),
      );
    } on Object {
      state = state.copyWith(result: const ErrorResult());
    }
  }
}
