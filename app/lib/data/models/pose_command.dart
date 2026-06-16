/// A joint-space pose command the app can send to the px100 Zenoh gateway.
///
/// Pure enum: it owns only the lowercase wire name the gateway matches on.
/// The wire payload is the `MessageCodec`'s concern and the Zenoh key the
/// repository's (`research/poc-zenoh-json-gateway.md`).
enum PoseCommand {
  home,
  sleep;

  /// The lowercase name the gateway matches on (e.g. `home`, `sleep`).
  String get wireName => name;
}
