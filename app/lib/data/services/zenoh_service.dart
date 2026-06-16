import 'dart:typed_data';

import 'package:zenoh/zenoh.dart';

/// The single `package:zenoh` boundary for the app — pure bytes transport.
///
/// Connects to the px100 Zenoh gateway as a CLIENT and publishes raw bytes on
/// caller-supplied key expressions. It owns no keys, no serialization, and no
/// domain types: the repository owns the key expressions, a `MessageCodec`
/// owns the wire bytes. Every public signature exposes only plain Dart — no
/// zenoh types (`Session`, `Config`, `Sample`) leak out, so the layers above
/// this stay FFI-free and unit-testable without zenoh.
class ZenohService {
  /// Creates the service, initialising zenoh logging once per process.
  ZenohService() {
    if (!_logInitialised) {
      Zenoh.initLog('error');
      _logInitialised = true;
    }
  }

  /// Guards [Zenoh.initLog] so repeated construction does not re-init.
  static bool _logInitialised = false;

  Session? _session;

  /// Whether a zenoh session is currently open.
  bool get isConnected => _session != null;

  /// Opens a CLIENT session that connects to [endpoint] (e.g.
  /// `tcp/127.0.0.1:7447`).
  ///
  /// `Session.open` is synchronous in the binding, so this is sync — no
  /// decorative `Future`. If already connected, this is a no-op.
  void connect(String endpoint) {
    if (_session != null) return;

    final config = Config()
      ..insertJson5('mode', '"client"')
      ..insertJson5('connect/endpoints', '["$endpoint"]');

    _session = Session.open(config: config);
  }

  /// Publishes [bytes] on [keyExpr] (no Encoding metadata — same `zd_put`
  /// path as the string put, so the wire is byte-identical to v0.2.0).
  ///
  /// `session.putBytes` is synchronous in the binding, so this is sync.
  /// Throws [StateError] if the service is not connected — it never silently
  /// succeeds.
  void publish(String keyExpr, Uint8List bytes) {
    final session = _session;
    if (session == null) {
      throw StateError('Not connected: call connect() before publish()');
    }
    session.putBytes(keyExpr, ZBytes.fromUint8List(bytes));
  }

  /// Sends a request [payload] on [key] (a Zenoh `get`) and completes with the
  /// FIRST reply's payload bytes.
  ///
  /// This is the request/reply (queryable) path: the gateway answers as a
  /// queryable and ALWAYS replies an ok-channel ack — both business outcomes
  /// (`{"ok":true}` and a `{"ok":false,…}` reject) arrive here as ok replies,
  /// so this method returns their bytes verbatim and does NOT branch on the
  /// JSON `ok` field (that is the codec/ViewModel's job).
  ///
  /// Transport-error outcomes ALL surface as a thrown error, never a sentinel:
  /// a Zenoh-error reply (`Reply.isOk == false`), no reply (empty stream), or a
  /// timeout (the reply stream completes empty after the 3 s budget, so
  /// `.first` throws). Throws [StateError] if the service is not connected — it
  /// never silently succeeds and no query reaches the peer.
  ///
  /// Plain Dart in, plain Dart out — no zenoh type leaks (mirrors [publish]).
  Future<Uint8List> query(String key, Uint8List payload) async {
    final session = _session;
    if (session == null) {
      throw StateError('Not connected: call connect() before query()');
    }
    final reply = await session
        .get(
          key,
          payload: ZBytes.fromUint8List(payload),
          timeout: const Duration(seconds: 3),
        )
        .first;
    if (!reply.isOk) {
      throw StateError('Query reply error: ${reply.error.payload}');
    }
    return reply.ok.payloadBytes;
  }

  /// Closes the session and releases resources. Idempotent — a second call is
  /// a no-op and does not throw.
  void dispose() {
    _session?.close();
    _session = null;
  }
}
