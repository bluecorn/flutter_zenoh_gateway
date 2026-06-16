import 'dart:convert';
import 'dart:typed_data';

import 'package:zenoh_ros_poc/data/models/ack.dart';
import 'package:zenoh_ros_poc/data/models/pose_command.dart';

/// The serialization seam between the repository and the transport.
///
/// Implementations turn domain commands into the wire bytes the px100
/// gateway expects and decode the gateway's replies back into domain types.
/// JSON ships first; Protobuf and FlatBuffers codecs plug into the same
/// interface at P2/P3 (`research/poc-serialization-codecs.md` §4.1). Named
/// `MessageCodec` — never bare `Codec`, which collides with `dart:convert`.
//
// The seam grows as the contract grows: encodeJog (M2) and decodeState (M3)
// are designed-but-unimplemented members alongside encodePose/decodeAck.
abstract class MessageCodec {
  /// Encodes [pose] into the wire payload bytes for the pose-command key.
  Uint8List encodePose(PoseCommand pose);

  /// Decodes the gateway's ack reply [bytes] into an [Ack].
  ///
  /// Total and defensive: NEVER throws. Returns a non-null [Ack] only for a
  /// parseable `{"ok":<bool>,…}` reply (a real business ack — `ok:true` or a
  /// gateway reject with `ok:false`); returns `null` for undecodable,
  /// malformed, empty, or missing-`ok` bytes — the transport-error signal.
  Ack? decodeAck(Uint8List bytes);
}

/// The JSON wire format: exactly the UTF-8 bytes of `{"pose":"<wireName>"}`,
/// byte-identical to the shipped v0.2.0 payload.
class JsonMessageCodec implements MessageCodec {
  /// Creates the JSON codec; stateless, so `const` instances are shared.
  const JsonMessageCodec();

  @override
  Uint8List encodePose(PoseCommand pose) =>
      utf8.encode(jsonEncode({'pose': pose.wireName}));

  @override
  Ack? decodeAck(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) return null;
      final ok = decoded['ok'];
      if (ok is! bool) return null;
      final error = decoded['error'];
      final detail = decoded['detail'];
      return Ack(
        ok: ok,
        error: error is String ? error : null,
        detail: detail is String ? detail : null,
      );
    } on Object {
      return null;
    }
  }
}
