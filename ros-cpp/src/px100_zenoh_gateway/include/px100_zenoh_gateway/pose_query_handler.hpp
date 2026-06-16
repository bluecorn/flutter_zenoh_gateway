#ifndef PX100_ZENOH_GATEWAY__POSE_QUERY_HANDLER_HPP_
#define PX100_ZENOH_GATEWAY__POSE_QUERY_HANDLER_HPP_

// End-to-end, I/O-free pose-query decision function for the PincherX-100
// gateway's queryable path.
//
// It composes parse_pose_name (command_parser.hpp) -> pose_to_arm_cmd
// (pose_map.hpp), and returns BOTH the optional JointGroupCommand to publish
// AND a structured ack to reply over the Zenoh queryable. It distinguishes
// the two rejection causes the spec requires:
//   - "malformed":     bad JSON OR a missing/non-string "pose" field
//                      (parse_pose_name cannot separate these; both collapse).
//   - "unknown_pose":  a well-formed pose name that is not in the pose map.
// On success the ack JSON is exactly {"ok":true} (no error/detail keys).
//
// No Zenoh and no live node: this is the seam the Zenoh queryable callback
// (Slice 3) calls. It returns a JointGroupCommand (an interbotix_xs_msgs type)
// but performs no I/O, so it unit-tests with GoogleTest alone.

#include <optional>
#include <string>

#include "interbotix_xs_msgs/msg/joint_group_command.hpp"
#include "px100_zenoh_gateway/command_parser.hpp"
#include "px100_zenoh_gateway/joint_group_command_builder.hpp"
#include "px100_zenoh_gateway/pose_map.hpp"
#include "px100_zenoh_gateway/vendor/nlohmann/json.hpp"

namespace px100_zenoh_gateway {

// The outcome of handling a pose query: an optional command to publish (absent
// on any rejection) and the JSON ack string to reply over the queryable.
struct PoseQueryResult {
  std::optional<interbotix_xs_msgs::msg::JointGroupCommand> command;
  std::string ack_json;
};

// Decides what to publish and what to reply for the given JSON pose payload.
// Never throws. The error-code set is exactly {"unknown_pose", "malformed"}.
inline PoseQueryResult handle_pose_query(const std::string& json) {
  const auto name = parse_pose_name(json);
  if (!name.has_value()) {
    // Bad JSON or a missing/non-string "pose" field — indistinguishable here.
    return PoseQueryResult{std::nullopt,
                           R"({"ok":false,"error":"malformed"})"};
  }

  const auto cmd = pose_to_arm_cmd(*name);
  if (!cmd.has_value()) {
    nlohmann::json ack;
    ack["ok"] = false;
    ack["error"] = "unknown_pose";
    ack["detail"] = "unknown pose: " + *name;
    return PoseQueryResult{std::nullopt, ack.dump()};
  }

  return PoseQueryResult{build_arm_command(*cmd), R"({"ok":true})"};
}

}  // namespace px100_zenoh_gateway

#endif  // PX100_ZENOH_GATEWAY__POSE_QUERY_HANDLER_HPP_
