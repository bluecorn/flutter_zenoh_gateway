#ifndef PX100_ZENOH_GATEWAY__JOINT_GROUP_COMMAND_BUILDER_HPP_
#define PX100_ZENOH_GATEWAY__JOINT_GROUP_COMMAND_BUILDER_HPP_

// Constructs an interbotix_xs_msgs/msg/JointGroupCommand for the `arm` group.
//
// Depends only on interbotix_xs_msgs (no Zenoh, no rclcpp, no live node) so it
// is unit-testable with gtest. Validation of the command array is the caller's
// responsibility (Slice 1's pose_to_arm_cmd guarantees only valid arrays reach
// here); the builder copies the array verbatim.

#include <vector>

#include "interbotix_xs_msgs/msg/joint_group_command.hpp"

namespace px100_zenoh_gateway {

// Builds a JointGroupCommand targeting the `arm` group with the given command.
inline interbotix_xs_msgs::msg::JointGroupCommand build_arm_command(
    const std::vector<float>& cmd) {
  interbotix_xs_msgs::msg::JointGroupCommand msg;
  msg.name = "arm";
  msg.cmd = cmd;
  return msg;
}

}  // namespace px100_zenoh_gateway

#endif  // PX100_ZENOH_GATEWAY__JOINT_GROUP_COMMAND_BUILDER_HPP_
