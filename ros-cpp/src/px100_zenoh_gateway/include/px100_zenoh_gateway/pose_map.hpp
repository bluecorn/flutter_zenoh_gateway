#ifndef PX100_ZENOH_GATEWAY__POSE_MAP_HPP_
#define PX100_ZENOH_GATEWAY__POSE_MAP_HPP_

// Pure pose-name -> arm joint-array mapping for the PincherX-100.
//
// Deliberately ROS/Zenoh/JSON-free: depends only on the standard library so it
// compiles and unit-tests with GoogleTest alone. The joint arrays target the
// `arm` group of interbotix_xs_msgs/msg/JointGroupCommand (cmd is float32[]).

#include <optional>
#include <string>
#include <vector>

namespace px100_zenoh_gateway {

// Maps a pose name to the 4-element arm joint command, or std::nullopt if the
// name is not a known pose. Matching is exact and case-sensitive (v1).
inline std::optional<std::vector<float>> pose_to_arm_cmd(
    const std::string& name) {
  if (name == "home") {
    return std::vector<float>{0.0f, 0.0f, 0.0f, 0.0f};
  }
  if (name == "sleep") {
    return std::vector<float>{0.0f, -1.88f, 1.5f, 0.8f};
  }
  return std::nullopt;
}

}  // namespace px100_zenoh_gateway

#endif  // PX100_ZENOH_GATEWAY__POSE_MAP_HPP_
