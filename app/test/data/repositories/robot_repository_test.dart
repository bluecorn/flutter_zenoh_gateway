import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zenoh_ros_poc/data/codecs/message_codec.dart';
import 'package:zenoh_ros_poc/data/models/pose_command.dart';
import 'package:zenoh_ros_poc/data/repositories/robot_repository.dart';

import '../../helpers/fakes.dart';

/// P1 Slice 6 — [RobotRepositoryImpl] composes key + codec + service: it owns
/// the contract key `px100/cmd/pose` and turns poses into wire bytes through
/// the injected [MessageCodec], publishing via the transport-only service
/// (fake-the-layer-below: the `(keyExpr, bytes)`-capturing [FakeZenohService]).
void main() {
  const poseKey = 'px100/cmd/pose';

  group('RobotRepositoryImpl', () {
    late FakeZenohService service;
    late RobotRepositoryImpl repository;

    setUp(() {
      service = FakeZenohService();
      repository = RobotRepositoryImpl(service, const JsonMessageCodec());
    });

    test('T1 — connect delegates to the service and reports connected', () {
      repository.connect('tcp/robot:7447');

      expect(service.connectCalls, ['tcp/robot:7447']);
      expect(repository.isConnected, isTrue);
    });

    test('T1 — sendPose queries the contract key + exact codec bytes, '
        'returns the decoded ok ack', () async {
      service.queryReply = Uint8List.fromList(utf8.encode('{"ok":true}'));
      repository.connect('tcp/robot:7447');

      final ack = await repository.sendPose(PoseCommand.home);

      expect(service.queries, hasLength(1));
      expect(service.queries.single.key, poseKey);
      expect(service.queries.single.payload, utf8.encode('{"pose":"home"}'));
      expect(ack.ok, isTrue);
    });

    test('T2 — a business reject ack is returned as Ack(ok:false), no throw',
        () async {
      service.queryReply = Uint8List.fromList(
        utf8.encode('{"ok":false,"error":"unknown_pose"}'),
      );
      repository.connect('tcp/robot:7447');

      final ack = await repository.sendPose(PoseCommand.home);

      expect(ack.ok, isFalse);
      expect(ack.error, 'unknown_pose');
    });

    test('T3 (edge) — a query throw propagates (error outcome)', () async {
      service.queryError = StateError('Query reply error');
      repository.connect('tcp/robot:7447');

      await expectLater(
        repository.sendPose(PoseCommand.home),
        throwsA(isA<StateError>()),
      );
    });

    test('T4 (edge) — an undecodable reply throws (MODIFY-1: null -> throw)',
        () async {
      service.queryReply = Uint8List.fromList(utf8.encode('not json'));
      repository.connect('tcp/robot:7447');

      await expectLater(
        repository.sendPose(PoseCommand.home),
        throwsA(isA<StateError>()),
      );
    });

    test('T3c — disconnect releases the service', () {
      repository.connect('tcp/robot:7447');
      expect(repository.isConnected, isTrue);

      repository.disconnect();

      expect(service.isConnected, isFalse);
      expect(repository.isConnected, isFalse);
    });

    test('T5 (edge) — sendPose before connect surfaces the StateError',
        () async {
      await expectLater(
        repository.sendPose(PoseCommand.home),
        throwsStateError,
      );
      expect(service.queries, isEmpty);
    });

    test('T6 (edge) — disconnect is idempotent', () {
      repository
        ..connect('tcp/robot:7447')
        ..disconnect();
      expect(repository.isConnected, isFalse);

      // Second call is a no-op and must not throw (mirrors the service's
      // idempotent dispose()).
      expect(repository.disconnect, returnsNormally);
      expect(repository.isConnected, isFalse);
    });
  });
}
