import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenoh_ros_poc/data/codecs/message_codec.dart';
import 'package:zenoh_ros_poc/data/models/pose_command.dart';
import 'package:zenoh_ros_poc/data/models/serialization_format.dart';
import 'package:zenoh_ros_poc/providers/providers.dart';

import '../helpers/fakes.dart';

/// A sync provider read surfaces a build-time error as a [ProviderException]
/// wrapping the original (riverpod 3.x); the cause must be the explicit
/// [UnsupportedError] placeholder.
final Matcher throwsUnsupportedViaProvider = throwsA(
  isA<ProviderException>().having(
    (e) => e.exception,
    'exception',
    isA<UnsupportedError>(),
  ),
);

void main() {
  /// Builds a container over freshly-read mocked prefs (call
  /// `SharedPreferences.setMockInitialValues` first) plus any [overrides].
  Future<ProviderContainer> makeContainer({
    List<Override> overrides = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('format → codec → repository DI chain', () {
    test('T4 — default DI graph yields the JSON codec', () async {
      SharedPreferences.setMockInitialValues({});
      final container = await makeContainer();

      expect(container.read(messageCodecProvider), isA<JsonMessageCodec>());
    });

    test('T5 — format provider persists through its notifier', () async {
      SharedPreferences.setMockInitialValues({});
      final container = await makeContainer();

      await container
          .read(serializationFormatProvider.notifier)
          .setFormat(SerializationFormat.protobuf);

      // A fresh container over the same mocked storage reads it back.
      final fresh = await makeContainer();
      expect(
        fresh.read(serializationFormatProvider),
        SerializationFormat.protobuf,
      );
    });

    test('T6 — DI chain queries the unchanged wire', () async {
      SharedPreferences.setMockInitialValues({});
      // Slice 7: the pose path is now request/reply, so the DI chain reaches
      // the service via query(); the dumb fake returns a canned ok ack.
      final fake = FakeZenohService()
        ..queryReply = Uint8List.fromList(utf8.encode('{"ok":true}'));
      final container = await makeContainer(
        overrides: [zenohServiceProvider.overrideWith((ref) => fake)],
      );

      final repository = container.read(robotRepositoryProvider)
        ..connect('tcp/robot:7447');
      await repository.sendPose(PoseCommand.home);

      expect(fake.queries, hasLength(1));
      expect(fake.queries.single.key, 'px100/cmd/pose');
      expect(fake.queries.single.payload, utf8.encode('{"pose":"home"}'));
    });

    test('T8 (edge) — unimplemented formats throw at codec '
        'resolution', () async {
      SharedPreferences.setMockInitialValues({});
      final container = await makeContainer();
      final notifier = container.read(serializationFormatProvider.notifier);

      await notifier.setFormat(SerializationFormat.protobuf);
      expect(
        () => container.read(messageCodecProvider),
        throwsUnsupportedViaProvider,
      );

      await notifier.setFormat(SerializationFormat.flatbuffers);
      expect(
        () => container.read(messageCodecProvider),
        throwsUnsupportedViaProvider,
      );
    });

    test('T9 (edge) — a format flip rebuilds the repository but never '
        'the session', () async {
      SharedPreferences.setMockInitialValues({});
      // overrideWith (not overrideWithValue): a torn-down service provider
      // would construct a NEW fake, so instance identity is load-bearing.
      final container = await makeContainer(
        overrides: [
          zenohServiceProvider.overrideWith((ref) => FakeZenohService()),
        ],
      );

      final serviceBefore = container.read(zenohServiceProvider);
      container.read(robotRepositoryProvider);

      // Flip away and back WITHOUT reading the codec while on protobuf.
      final notifier = container.read(serializationFormatProvider.notifier);
      await notifier.setFormat(SerializationFormat.protobuf);
      await notifier.setFormat(SerializationFormat.json);

      // The session survived the flip…
      expect(
        identical(container.read(zenohServiceProvider), serviceBefore),
        isTrue,
      );
      // …and the repository re-resolves over the JSON codec, wire-identical.
      expect(container.read(messageCodecProvider), isA<JsonMessageCodec>());
      final fake = container.read(zenohServiceProvider) as FakeZenohService
        ..queryReply = Uint8List.fromList(utf8.encode('{"ok":true}'));
      final repository = container.read(robotRepositoryProvider)
        ..connect('tcp/robot:7447');
      await repository.sendPose(PoseCommand.home);
      expect(fake.queries.single.key, 'px100/cmd/pose');
      expect(fake.queries.single.payload, utf8.encode('{"pose":"home"}'));
    });
  });
}
