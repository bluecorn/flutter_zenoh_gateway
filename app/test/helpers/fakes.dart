import 'dart:async';
import 'dart:typed_data';

import 'package:zenoh_ros_poc/data/models/ack.dart';
import 'package:zenoh_ros_poc/data/models/pose_command.dart';
import 'package:zenoh_ros_poc/data/repositories/robot_repository.dart';
import 'package:zenoh_ros_poc/data/services/zenoh_service.dart';

/// Fake [ZenohService] that records calls and never touches `package:zenoh`.
///
/// Transport-shaped (P1 Slice 6): captures the raw `(keyExpr, bytes)` records
/// that [publish] receives — the fake the repository tests sit on.
///
/// Using `implements` (not `extends`) means the real [ZenohService]
/// constructor — and therefore `Zenoh.initLog` / any FFI — is never invoked,
/// so widget tests run without the native library.
class FakeZenohService implements ZenohService {
  /// Endpoints passed to [connect], in call order.
  final List<String> connectCalls = [];

  /// `(keyExpr, bytes)` records captured from [publish], in call order.
  final List<({String keyExpr, Uint8List bytes})> publishes = [];

  /// `(key, payload)` records captured from [query], in call order.
  final List<({String key, Uint8List payload})> queries = [];

  /// Canned reply bytes returned by [query] on success. Settable per test.
  Uint8List queryReply = Uint8List(0);

  /// When non-null, [query] throws this instead of returning [queryReply] —
  /// for the transport-error path (timeout / Zenoh-error reply).
  Object? queryError;

  /// When true, [connect] throws to simulate a failed connection.
  bool failConnect = false;

  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  void connect(String endpoint) {
    connectCalls.add(endpoint);
    if (failConnect) {
      throw StateError('connect failed');
    }
    _connected = true;
  }

  @override
  void publish(String keyExpr, Uint8List bytes) {
    if (!_connected) {
      throw StateError('Not connected');
    }
    publishes.add((keyExpr: keyExpr, bytes: bytes));
  }

  @override
  Future<Uint8List> query(String key, Uint8List payload) async {
    if (!_connected) {
      throw StateError('Not connected');
    }
    queries.add((key: key, payload: payload));
    if (queryError != null) {
      // The fake re-throws a caller-configured throwable verbatim to drive the
      // transport-error path (the real service throws StateError on a
      // Zenoh-error reply / empty stream / timeout).
      // ignore: only_throw_errors
      throw queryError!;
    }
    return queryReply;
  }

  @override
  void dispose() {
    _connected = false;
  }
}

/// Fake [RobotRepository] that records calls — the fake the ViewModel tests
/// sit on (one layer below the VMs, per the layered-fake strategy).
class FakeRobotRepository implements RobotRepository {
  /// Endpoints passed to [connect], in call order.
  final List<String> connectCalls = [];

  /// Poses passed to [sendPose], in call order.
  final List<PoseCommand> sentPoses = [];

  /// Number of [disconnect] calls.
  int disconnectCalls = 0;

  /// Canned ack [sendPose] returns on success. Settable per test — dumb: the
  /// fake does NOT reimplement gateway semantics (pose map / error codes).
  Ack sendPoseAck = const Ack(ok: true);

  /// When non-null, [sendPose] throws this instead of returning [sendPoseAck]
  /// — the transport-error path (a `query` throw or an undecodable reply).
  Object? sendPoseError;

  /// Settable connection state (driven by [connect]/[disconnect] too).
  @override
  bool isConnected = false;

  @override
  void connect(String endpoint) {
    connectCalls.add(endpoint);
    isConnected = true;
  }

  @override
  void disconnect() {
    disconnectCalls++;
    isConnected = false;
  }

  @override
  Future<Ack> sendPose(PoseCommand pose) async {
    if (!isConnected) {
      throw StateError('Not connected');
    }
    sentPoses.add(pose);
    if (sendPoseError != null) {
      // The fake re-throws a caller-configured throwable verbatim to drive the
      // transport-error path (the repository throws on a query error / an
      // undecodable reply).
      // ignore: only_throw_errors
      throw sendPoseError!;
    }
    return sendPoseAck;
  }
}

/// [RobotRepository] whose [sendPose] stays in flight until [complete] is
/// called — lets a widget test assert the mid-send (in-flight) UI state
/// before the ack resolves. Dumb: no gateway semantics, just a controllable
/// [Completer].
class CompleterFakeRobotRepository implements RobotRepository {
  /// Poses passed to [sendPose], in call order.
  final List<PoseCommand> sentPoses = [];

  Completer<Ack>? _pending;

  @override
  bool isConnected = false;

  @override
  void connect(String endpoint) => isConnected = true;

  @override
  void disconnect() => isConnected = false;

  @override
  Future<Ack> sendPose(PoseCommand pose) {
    if (!isConnected) {
      throw StateError('Not connected');
    }
    sentPoses.add(pose);
    final completer = _pending = Completer<Ack>();
    return completer.future;
  }

  /// Resolves the in-flight [sendPose] with [ack].
  void complete(Ack ack) => _pending?.complete(ack);
}

/// [RobotRepository] whose [connect] always throws — for the error path.
class ThrowingFakeRobotRepository implements RobotRepository {
  @override
  bool get isConnected => false;

  @override
  void connect(String endpoint) => throw StateError('connect failed');

  @override
  void disconnect() {}

  @override
  Future<Ack> sendPose(PoseCommand pose) async =>
      throw StateError('Not connected');
}
