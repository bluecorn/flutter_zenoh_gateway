// Minimal raw zenoh-cpp querier used only by the launch_testing integration
// test (Slice 3). It opens a client Zenoh session that connects to the running
// rmw_zenohd router on tcp/localhost:7447, sends a z_get on a plain Zenoh key
// carrying the JSON pose payload, reads the FIRST reply, prints the reply
// payload to stdout and exits 0. On no-reply / timeout it exits non-zero and
// never hangs (the get carries a bounded timeout). Built only under
// BUILD_TESTING and linked against the same zenoh_cpp_vendor target as the
// gateway, so the Zenoh versions match.
//
// Usage: zenoh_test_querier <key> <json-payload>
//   defaults: key = "px100/cmd/pose", payload = {"pose":"home"}

#include <iostream>
#include <string>
#include <variant>

#include "zenoh.hxx"

int main(int argc, char** argv) {
  const std::string key = (argc > 1) ? argv[1] : "px100/cmd/pose";
  const std::string payload = (argc > 2) ? argv[2] : "{\"pose\":\"home\"}";

  // Connect as a client to the rmw_zenohd router so the get is relayed to the
  // gateway's (likewise client-connected) raw queryable session.
  zenoh::ZResult err = Z_OK;
  zenoh::Config config = zenoh::Config::create_default(&err);
  if (err != Z_OK) {
    std::cerr << "zenoh_test_querier: failed to create config\n";
    return 1;
  }
  config.insert_json5("mode", "\"client\"", &err);
  config.insert_json5("connect/endpoints", "[\"tcp/localhost:7447\"]", &err);

  auto session = zenoh::Session::open(std::move(config), {}, &err);
  if (err != Z_OK) {
    std::cerr << "zenoh_test_querier: failed to open session\n";
    return 1;
  }

  // Bounded timeout so the querier never hangs when no queryable answers: the
  // FIFO channel disconnects once the query completes (first/all replies) or
  // the timeout elapses.
  zenoh::Session::GetOptions options = zenoh::Session::GetOptions::create_default();
  options.payload = zenoh::Bytes(payload);
  options.timeout_ms = 3000;

  auto replies = session.get(zenoh::KeyExpr(key), "", zenoh::channels::FifoChannel(16),
                             std::move(options), &err);
  if (err != Z_OK) {
    std::cerr << "zenoh_test_querier: get failed\n";
    return 1;
  }

  // Read the FIRST reply (blocks until a reply arrives or the channel
  // disconnects on timeout).
  auto res = replies.recv();
  if (!std::holds_alternative<zenoh::Reply>(res)) {
    std::cerr << "zenoh_test_querier: no reply within timeout\n";
    return 1;
  }

  const zenoh::Reply& reply = std::get<zenoh::Reply>(res);
  if (!reply.is_ok()) {
    std::cerr << "zenoh_test_querier: error reply: "
              << reply.get_err().get_payload().as_string() << "\n";
    return 1;
  }

  std::cout << reply.get_ok().get_payload().as_string() << std::endl;
  return 0;
}
