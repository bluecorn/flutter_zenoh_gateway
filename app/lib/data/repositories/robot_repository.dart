import 'package:zenoh_ros_poc/data/codecs/message_codec.dart';
import 'package:zenoh_ros_poc/data/models/ack.dart';
import 'package:zenoh_ros_poc/data/models/pose_command.dart';
import 'package:zenoh_ros_poc/data/services/zenoh_service.dart';

/// The robot command boundary the ViewModels talk to.
///
/// Plain Dart only — no `package:zenoh`. The implementation composes the
/// contract key + the injected [MessageCodec] over the bytes-only
/// [ZenohService] (the codec seam, design doc §4.1/§5).
abstract class RobotRepository {
  /// Whether the underlying transport is connected.
  bool get isConnected;

  /// Connects the transport to [endpoint] (e.g. `tcp/robot:7447`).
  void connect(String endpoint);

  /// Disconnects and releases the transport. Idempotent.
  void disconnect();

  /// Sends [pose] to the robot via the request/reply (queryable) path and
  /// completes with the gateway's business [Ack].
  ///
  /// A successful return is ALWAYS a real business ack — `ok:true` (accepted
  /// & forwarded) or a gateway reject (`ok:false` with a reason). Both
  /// transport-error forms surface as a thrown error, never as a returned
  /// `Ack`: a `query` throw (timeout / Zenoh-error / not connected) propagates,
  /// and an undecodable reply is converted to a thrown [StateError] (MODIFY-1).
  /// Throws [StateError] when not connected.
  Future<Ack> sendPose(PoseCommand pose);
}

/// [RobotRepository] composing key + codec + service: it owns the gateway
/// contract key and delegates serialization to the [MessageCodec] and
/// delivery to the [ZenohService].
class RobotRepositoryImpl implements RobotRepository {
  /// Creates a repository publishing [_codec]-encoded poses via [_service].
  RobotRepositoryImpl(this._service, this._codec);

  /// The contract key the gateway subscribes to (owned by the repository —
  /// never the service or the model). See `research/poc-zenoh-json-gateway.md`.
  static const String _poseKey = 'px100/cmd/pose';

  final ZenohService _service;
  final MessageCodec _codec;

  @override
  bool get isConnected => _service.isConnected;

  @override
  void connect(String endpoint) => _service.connect(endpoint);

  @override
  void disconnect() => _service.dispose();

  @override
  Future<Ack> sendPose(PoseCommand pose) async {
    final replyBytes = await _service.query(_poseKey, _codec.encodePose(pose));
    final ack = _codec.decodeAck(replyBytes);
    if (ack == null) {
      // MODIFY-1: an undecodable reply is a transport error, not a business
      // ack — surface it through the SAME thrown-error path as a query throw,
      // so a non-null return is always a real business Ack.
      throw StateError('Undecodable ack reply from gateway');
    }
    return ack;
  }
}
