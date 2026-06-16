import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zenoh_ros_poc/providers/providers.dart';

/// Connection lifecycle status — a plain Dart enum (no zenoh types).
enum ConnectionStatus {
  /// Not connected to the gateway.
  disconnected,

  /// Successfully connected to the gateway.
  connected,

  /// The last connection attempt failed.
  error,
}

/// Immutable connection state: the persisted endpoint plus the live status.
class ConnectionState {
  /// Creates a [ConnectionState].
  const ConnectionState({
    required this.endpoint,
    this.status = ConnectionStatus.disconnected,
    this.error,
  });

  /// The endpoint to connect to (e.g. `tcp/localhost:7447`).
  final String endpoint;

  /// The current connection status.
  final ConnectionStatus status;

  /// Error message when [status] is [ConnectionStatus.error].
  final String? error;

  /// Whether the app is currently connected to the gateway.
  bool get isConnected => status == ConnectionStatus.connected;

  /// Returns a copy with the given fields replaced.
  ///
  /// Maintains the invariant that [error] is non-null only while [status]
  /// is [ConnectionStatus.error]: leaving the error status clears the
  /// message; staying in it preserves the existing message unless replaced.
  ConnectionState copyWith({
    String? endpoint,
    ConnectionStatus? status,
    String? error,
  }) {
    final nextStatus = status ?? this.status;
    return ConnectionState(
      endpoint: endpoint ?? this.endpoint,
      status: nextStatus,
      error: nextStatus == ConnectionStatus.error
          ? (error ?? this.error)
          : null,
    );
  }
}

/// Drives the connection: loads/saves the endpoint via the settings
/// repository and connects through the (mockable) [robotRepositoryProvider].
///
/// `build()` is sync — the persisted endpoint loads synchronously — so the
/// state is a plain [ConnectionState] from the first read (no `AsyncValue`).
class ConnectionViewModel extends Notifier<ConnectionState> {
  @override
  ConnectionState build() {
    final endpoint = ref.read(settingsRepositoryProvider).loadEndpoint();
    return ConnectionState(endpoint: endpoint);
  }

  /// Persists [endpoint] and reflects it in the state without connecting.
  Future<void> setEndpoint(String endpoint) async {
    await ref.read(settingsRepositoryProvider).saveEndpoint(endpoint);
    state = state.copyWith(endpoint: endpoint);
  }

  /// Disconnects from the gateway via the repository and drives the status
  /// to [ConnectionStatus.disconnected] (so the connect→control navigation
  /// listener does not re-fire).
  void disconnect() {
    ref.read(robotRepositoryProvider).disconnect();
    state = state.copyWith(status: ConnectionStatus.disconnected);
  }

  /// Connects to [endpoint] via the repository, driving the status to
  /// [ConnectionStatus.connected] on success or [ConnectionStatus.error] on
  /// failure. Persists the endpoint so it survives a reload.
  Future<void> connect(String endpoint) async {
    await ref.read(settingsRepositoryProvider).saveEndpoint(endpoint);
    final base = state.copyWith(endpoint: endpoint);
    try {
      ref.read(robotRepositoryProvider).connect(endpoint);
      state = base.copyWith(status: ConnectionStatus.connected);
    } on Object catch (e) {
      state = base.copyWith(
        status: ConnectionStatus.error,
        error: e.toString(),
      );
    }
  }
}
