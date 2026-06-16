/// The gateway's reply to a pose command, mirroring its ack contract shape.
///
/// Pure Dart value type: no zenoh, no JSON. The `MessageCodec` (Slice 6)
/// constructs it from a decoded reply; the repository and ViewModel
/// (Slices 7–8) read its fields to map the command outcome.
class Ack {
  /// Creates an ack. [ok] true means the gateway accepted and forwarded the
  /// command; on a reject, [error] carries the reason and [detail] optional
  /// context.
  const Ack({required this.ok, this.error, this.detail});

  /// Whether the gateway accepted and forwarded the command.
  final bool ok;

  /// The reject reason when [ok] is false (e.g. `unknown_pose`), else null.
  final String? error;

  /// Optional context for a reject (e.g. the offending value), else null.
  final String? detail;
}
