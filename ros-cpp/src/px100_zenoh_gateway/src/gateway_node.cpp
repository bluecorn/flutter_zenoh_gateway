// PincherX-100 Zenoh-JSON gateway node.
//
// One process, two Zenoh-facing roles:
//   - App side: a raw zenoh-cpp client session declares a QUERYABLE on the
//     plain Zenoh key "px100/cmd/pose" (JSON pose commands from the Flutter
//     app arrive as Zenoh `get` requests, and the gateway replies an ack).
//   - ROS side: an rclcpp publisher (RMW = rmw_zenoh_cpp) emits
//     interbotix_xs_msgs/msg/JointGroupCommand on /px100/commands/joint_group.
//
// On each query, the request payload string is fed to handle_pose_query
// (Slice 1), which returns BOTH an optional JointGroupCommand AND a JSON ack
// string. If a command is present it is published on the ROS topic; the ack is
// ALWAYS sent back via query.reply(). A business rejection (malformed JSON,
// missing field, or unknown pose) yields no publish and an ack with
// "ok":false — but it is still a valid reply() ack, NEVER a reply_err().
// Bad input never crashes the node.
//
// Both the raw Zenoh session here and the rmw_zenoh ROS pub/sub federate
// through the running rmw_zenohd router (tcp/localhost:7447): this session
// connects to it as a Zenoh client, so plain-key queries from other Zenoh
// clients (e.g. the Flutter app) are relayed in.

#include <memory>
#include <string>

#include "rclcpp/rclcpp.hpp"

#include "interbotix_xs_msgs/msg/joint_group_command.hpp"
#include "px100_zenoh_gateway/pose_query_handler.hpp"

#include "zenoh.hxx"

namespace {

constexpr char kZenohCmdKey[] = "px100/cmd/pose";
constexpr char kRosTopic[] = "/px100/commands/joint_group";

}  // namespace

int main(int argc, char** argv) {
  rclcpp::init(argc, argv);

  auto node = std::make_shared<rclcpp::Node>("px100_zenoh_gateway");
  auto publisher =
      node->create_publisher<interbotix_xs_msgs::msg::JointGroupCommand>(
          kRosTopic, rclcpp::QoS(10));

  // Raw zenoh-cpp client session that connects to the running rmw_zenohd
  // router, so it sees plain-key queries relayed from other Zenoh clients.
  zenoh::ZResult err = Z_OK;
  zenoh::Config config = zenoh::Config::create_default(&err);
  if (err != Z_OK) {
    RCLCPP_FATAL(node->get_logger(), "failed to create Zenoh config");
    rclcpp::shutdown();
    return 1;
  }
  config.insert_json5("mode", "\"client\"", &err);
  config.insert_json5("connect/endpoints", "[\"tcp/localhost:7447\"]", &err);

  auto session = zenoh::Session::open(std::move(config), {}, &err);
  if (err != Z_OK) {
    RCLCPP_FATAL(node->get_logger(), "failed to open Zenoh session");
    rclcpp::shutdown();
    return 1;
  }

  const zenoh::KeyExpr cmd_key(kZenohCmdKey);

  // The queryable handler: read the request payload, decide via
  // handle_pose_query, publish on a command, and ALWAYS reply the ack.
  auto on_query = [node, publisher, cmd_key](const zenoh::Query& query) {
    std::string payload;
    if (const auto p = query.get_payload(); p.has_value()) {
      payload = p->get().as_string();
    }

    const auto result = px100_zenoh_gateway::handle_pose_query(payload);
    if (result.command.has_value()) {
      publisher->publish(*result.command);
      RCLCPP_INFO(node->get_logger(),
                  "published JointGroupCommand for payload: '%s'",
                  payload.c_str());
    } else {
      RCLCPP_WARN(node->get_logger(),
                  "rejected Zenoh pose payload (no publish): '%s'",
                  payload.c_str());
    }

    // Always reply the ack — ok or business rejection. Never reply_err():
    // a rejection is a valid JSON ack with "ok":false, not a transport error.
    zenoh::ZResult reply_result = Z_OK;
    query.reply(cmd_key, zenoh::Bytes(result.ack_json),
                zenoh::Query::ReplyOptions::create_default(), &reply_result);
    if (reply_result != Z_OK) {
      RCLCPP_WARN(node->get_logger(), "failed to reply to pose query");
    }
  };

  auto queryable = session.declare_queryable(
      cmd_key, on_query, zenoh::closures::none,
      zenoh::Session::QueryableOptions::create_default(), &err);
  if (err != Z_OK) {
    RCLCPP_FATAL(node->get_logger(), "failed to declare Zenoh queryable");
    rclcpp::shutdown();
    return 1;
  }

  RCLCPP_INFO(node->get_logger(),
              "px100_zenoh_gateway up: Zenoh queryable '%s' -> ROS topic '%s'",
              kZenohCmdKey, kRosTopic);

  rclcpp::spin(node);
  rclcpp::shutdown();
  return 0;
}
