import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zenoh/zenoh.dart';
import 'package:zenoh_ros_poc/data/codecs/message_codec.dart';
import 'package:zenoh_ros_poc/data/models/pose_command.dart';
import 'package:zenoh_ros_poc/data/repositories/robot_repository.dart';
import 'package:zenoh_ros_poc/data/services/zenoh_service.dart';

/// Real-zenoh integration for [ZenohService] (P1 Slice 6: the service is pure
/// bytes transport — `publish(keyExpr, bytes)` via `putBytes` — and the
/// repository composes key + codec on top of it).
///
/// Inverted counter-flutter two-session pattern: the in-test session LISTENS
/// as a peer on `tcp/127.0.0.1:19448` (!= the gateway's 7447) with a
/// subscriber on the contract key `px100/cmd/pose`; the [ZenohService] under
/// test connects as a CLIENT to that endpoint and publishes. The listener
/// asserts the exact payload bytes arrive.
void main() {
  const endpoint = 'tcp/127.0.0.1:19448';
  const key = 'px100/cmd/pose';

  group('ZenohService (real zenoh)', () {
    late Session listener;
    late Subscriber subscriber;
    late ZenohService service;

    setUp(() {
      // In-test LISTENER: a peer that listens on the test endpoint and
      // subscribes to the contract key.
      Zenoh.initLog('error');
      final cfg = Config()
        ..insertJson5('mode', '"peer"')
        ..insertJson5('listen/endpoints', '["$endpoint"]');
      listener = Session.open(config: cfg);
      subscriber = listener.declareSubscriber(key);
      service = ZenohService();
    });

    tearDown(() {
      // Idempotent teardown: each close/dispose is a no-op the second time.
      service.dispose();
      subscriber.close();
      listener.close();
    });

    /// Captures the next [count] samples (with timeout), waits for the TCP
    /// link to establish, runs [doPublish] (sync), and returns the received
    /// samples in arrival order. The caller must have connected already.
    Future<List<Sample>> publishAndReceive(
      void Function() doPublish, {
      int count = 1,
    }) async {
      // Allow TCP link establishment before publishing (counter-flutter does
      // the same — a bare put before the link is up is dropped).
      final received = subscriber.stream
          .take(count)
          .toList()
          .timeout(const Duration(seconds: 5));
      await Future<void>.delayed(const Duration(seconds: 1));
      doPublish();
      return received;
    }

    test(
      'T1 — bytes publish delivers exact bytes',
      () async {
        // Non-trivial bytes: interior NUL (proves no C-string truncation)
        // plus 2-, 3- and 4-byte UTF-8 sequences (proves no re-encoding).
        // HARNESS CONSTRAINT: the pinned zenoh_dart v0.18.0 subscriber shim
        // funnels received payloads through z_bytes_to_string
        // (src/zenoh_dart.c:_zd_sample_callback), so the in-test LISTENER can
        // only faithfully report UTF-8-valid bytes; the publish path under
        // test is byte-agnostic (putBytes → zd_put, no conversion).
        final bytes = Uint8List.fromList([0x00, ...utf8.encode('é→🤖'), 0x7f]);
        service.connect(endpoint);

        final samples = await publishAndReceive(
          () => service.publish(key, bytes),
        );

        expect(samples.single.keyExpr, key);
        expect(samples.single.payloadBytes, bytes);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'T2 — wire-identity: repo→codec→service queries the v0.2.0 wire',
      () async {
        // Slice 7: the pose path is now request/reply, so wire-identity is
        // proven by the request payload reaching the queryable (the gateway is
        // a queryable, no longer a subscriber). A test-peer queryable on the
        // contract key records each request payload and replies a canned ack.
        final recorded = <Uint8List?>[];
        final okAck = utf8.encode('{"ok":true}');
        final queryable = listener.declareQueryable(key)
          ..stream.listen((query) {
            recorded.add(query.payloadBytes);
            // A fresh ZBytes per reply — ZBytes is single-consume.
            query
              ..replyBytes(key, ZBytes.fromUint8List(okAck))
              ..dispose();
          });

        final repository = RobotRepositoryImpl(
          service,
          const JsonMessageCodec(),
        )..connect(endpoint);
        await Future<void>.delayed(const Duration(seconds: 1));

        // Bare contract key, byte-identical JSON request payloads —
        // indistinguishable on the wire from the shipped v0.2.0 put bytes.
        final homeAck = await repository.sendPose(PoseCommand.home);
        final sleepAck = await repository.sendPose(PoseCommand.sleep);

        expect(homeAck.ok, isTrue);
        expect(sleepAck.ok, isTrue);
        expect(recorded, hasLength(2));
        expect(recorded[0], utf8.encode('{"pose":"home"}'));
        expect(recorded[1], utf8.encode('{"pose":"sleep"}'));
        queryable.close();
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test('T3 — connect opens session', () {
      service.connect(endpoint);
      expect(service.isConnected, isTrue);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test(
      'T5 (edge) — publish before connect throws and delivers nothing',
      () async {
        // No connect(): publishing must NOT reach the listener and must signal
        // not-connected rather than silently succeed.
        var received = false;
        final sub = subscriber.stream.listen((_) => received = true);
        final bytes = Uint8List.fromList([0x01, 0x02, 0x03]);

        expect(() => service.publish(key, bytes), throwsStateError);
        expect(service.isConnected, isFalse);

        // Give any (erroneously sent) sample a chance to arrive.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(received, isFalse);
        await sub.cancel();
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'T6 (edge) — dispose() is idempotent after the narrowing',
      () {
        service.connect(endpoint);
        expect(service.isConnected, isTrue);

        service.dispose();
        expect(service.isConnected, isFalse);

        // Second call is a no-op and must not throw.
        expect(service.dispose, returnsNormally);
        expect(service.isConnected, isFalse);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  // ---------------------------------------------------------------------------
  // Slice 4: ZenohService.query — the request/reply (get) path.
  //
  // Same inverted two-session pattern as the publish group, but for the query
  // direction: the in-test session is a PEER that LISTENS on a UNIQUE port
  // (tcp/127.0.0.1:19449 — not the gateway's 7447, not the publish group's
  // 19448) and declares a QUERYABLE on the contract key. The [ZenohService]
  // under test connects as a CLIENT and issues `query()`; the test-peer
  // answerer records the request payload and `reply()`s a canned ack. The
  // service must surface the reply bytes byte-exact and throw on the
  // transport-error outcomes — never a sentinel.
  // ---------------------------------------------------------------------------
  group('ZenohService.query (real zenoh)', () {
    const queryEndpoint = 'tcp/127.0.0.1:19449';
    late Session answerer;
    late ZenohService service;

    setUp(() {
      Zenoh.initLog('error');
      final cfg = Config()
        ..insertJson5('mode', '"peer"')
        ..insertJson5('listen/endpoints', '["$queryEndpoint"]');
      answerer = Session.open(config: cfg);
      service = ZenohService();
    });

    tearDown(() {
      // Idempotent teardown: each close/dispose is a no-op the second time.
      service.dispose();
      answerer.close();
    });

    /// Declares a queryable on [key] that records the FIRST request payload it
    /// receives and replies [replyBytes] via `reply()`. Returns the
    /// [Queryable] (caller closes it) and a future of the recorded request
    /// payload.
    (Queryable, Future<Uint8List?>) startAnswerer(Uint8List replyBytes) {
      final recorded = Completer<Uint8List?>();
      final queryable = answerer.declareQueryable(key);
      queryable.stream.listen((query) {
        if (!recorded.isCompleted) recorded.complete(query.payloadBytes);
        query
          ..replyBytes(key, ZBytes.fromUint8List(replyBytes))
          ..dispose();
      });
      return (queryable, recorded.future);
    }

    /// Declares a queryable that answers with `replyErr` (a transport-level
    /// Zenoh-error reply, NOT a business reject).
    Queryable startErrorAnswerer() {
      final queryable = answerer.declareQueryable(key);
      queryable.stream.listen((query) {
        query
          ..replyErr('boom')
          ..dispose();
      });
      return queryable;
    }

    /// Connects the service and allows the TCP link + queryable declaration to
    /// propagate before the query is issued (mirrors the publish group's
    /// link-establishment delay).
    Future<void> connectAndSettle() async {
      service.connect(queryEndpoint);
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    test(
      'T1 — query returns the reply bytes byte-exact, peer recorded request',
      () async {
        final replyBytes = utf8.encode('{"ok":true}');
        final (queryable, recordedRequest) = startAnswerer(replyBytes);
        final payload = utf8.encode('{"pose":"home"}');
        await connectAndSettle();

        final result = await service.query(key, payload);

        expect(result, replyBytes);
        expect(await recordedRequest, payload);
        queryable.close();
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'T2 — query carries the request payload to the queryable',
      () async {
        final (queryable, recordedRequest) =
            startAnswerer(utf8.encode('{"ok":true}'));
        final payload =
            Uint8List.fromList([0x00, ...utf8.encode('é→🤖'), 0x7f]);
        await connectAndSettle();

        await service.query(key, payload);

        expect(await recordedRequest, payload);
        queryable.close();
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'T3 — reject-ack bytes arrive via the ok channel (no branch on ok)',
      () async {
        final rejectBytes = utf8.encode('{"ok":false,"error":"unknown_pose"}');
        final (queryable, _) = startAnswerer(rejectBytes);
        await connectAndSettle();

        final result = await service.query(key, utf8.encode('{"pose":"x"}'));

        // The service does NOT inspect the JSON `ok` field — a business
        // reject is a normal ok-channel reply, returned byte-exact.
        expect(result, rejectBytes);
        queryable.close();
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'T4 (edge) — no reply / timeout throws, never hangs, never a sentinel',
      () async {
        // No queryable answering the key → empty reply stream / timeout.
        await connectAndSettle();

        await expectLater(
          service.query(key, utf8.encode('{"pose":"home"}')),
          throwsA(isA<Object>()),
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'T5 (edge) — Zenoh-error reply throws',
      () async {
        final queryable = startErrorAnswerer();
        await connectAndSettle();

        await expectLater(
          service.query(key, utf8.encode('{"pose":"home"}')),
          throwsA(isA<Object>()),
        );
        queryable.close();
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'T6 (edge) — query before connect throws StateError and sends nothing',
      () async {
        var sawQuery = false;
        final queryable = answerer.declareQueryable(key);
        final sub = queryable.stream.listen((query) {
          sawQuery = true;
          query.dispose();
        });

        await expectLater(
          service.query(key, utf8.encode('{"pose":"home"}')),
          throwsStateError,
        );
        expect(service.isConnected, isFalse);

        // Give any (erroneously issued) query a chance to arrive.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(sawQuery, isFalse);
        await sub.cancel();
        queryable.close();
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
