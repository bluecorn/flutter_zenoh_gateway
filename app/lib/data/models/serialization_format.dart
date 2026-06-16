/// The wire serialization format the app encodes commands with.
///
/// JSON is the only implemented format at P1; Protobuf and FlatBuffers are
/// explicit placeholders whose codecs ship at P2/P3
/// (`research/poc-serialization-codecs.md` §4). No display label here — that
/// arrives at P2 with the format selector UI.
enum SerializationFormat {
  /// Plain JSON — the shipped v0.2.0 wire format.
  json('json'),

  /// Protocol Buffers (P2 — codec not yet implemented).
  protobuf('proto'),

  /// FlatBuffers (P3 — codec not yet implemented).
  flatbuffers('fb');

  const SerializationFormat(this.wireName);

  /// The short stable name persisted as the preference string and, at P2,
  /// used as the Zenoh key segment.
  final String wireName;
}
