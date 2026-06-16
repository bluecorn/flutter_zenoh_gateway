#ifndef PX100_ZENOH_GATEWAY__COMMAND_PARSER_HPP_
#define PX100_ZENOH_GATEWAY__COMMAND_PARSER_HPP_

// Pure JSON command parsing for the PincherX-100 gateway.
//
// Extracts the "pose" string field from a JSON command payload. Deliberately
// ROS/Zenoh-free: depends only on the vendored nlohmann/json single header and
// the standard library, so it compiles and unit-tests with GoogleTest alone.
// Mapping the pose name to joint arrays is a separate concern (see pose_map.hpp).

#include <optional>
#include <string>

#include "px100_zenoh_gateway/vendor/nlohmann/json.hpp"

namespace px100_zenoh_gateway {

// Parses a JSON command string and returns the value of its "pose" string
// field, or std::nullopt on any failure (malformed JSON, missing field, or a
// non-string "pose"). Never throws: parse errors are contained internally via
// non-throwing parsing.
inline std::optional<std::string> parse_pose_name(const std::string& json) {
  const auto parsed =
      nlohmann::json::parse(json, /*cb=*/nullptr, /*allow_exceptions=*/false);
  if (parsed.is_discarded()) {
    return std::nullopt;
  }
  const auto it = parsed.find("pose");
  if (it == parsed.end() || !it->is_string()) {
    return std::nullopt;
  }
  return it->get<std::string>();
}

}  // namespace px100_zenoh_gateway

#endif  // PX100_ZENOH_GATEWAY__COMMAND_PARSER_HPP_
