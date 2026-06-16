#include <gtest/gtest.h>

#include <optional>
#include <string>
#include <vector>

#include "px100_zenoh_gateway/pose_map.hpp"

namespace {

// cmd is float32[]; compare with a tolerance rather than exact equality.
void ExpectCmdNear(const std::vector<float>& got,
                   const std::vector<float>& want) {
  ASSERT_EQ(got.size(), want.size());
  for (size_t i = 0; i < want.size(); ++i) {
    EXPECT_NEAR(got[i], want[i], 1e-6f) << "mismatch at index " << i;
  }
}

}  // namespace

TEST(PoseMapTest, HomeMapsToHomeJointArray) {
  const auto cmd = px100_zenoh_gateway::pose_to_arm_cmd("home");
  ASSERT_TRUE(cmd.has_value());
  EXPECT_EQ(cmd->size(), 4u);
  ExpectCmdNear(*cmd, {0.0f, 0.0f, 0.0f, 0.0f});
}

TEST(PoseMapTest, SleepMapsToSleepJointArray) {
  const auto cmd = px100_zenoh_gateway::pose_to_arm_cmd("sleep");
  ASSERT_TRUE(cmd.has_value());
  EXPECT_EQ(cmd->size(), 4u);
  ExpectCmdNear(*cmd, {0.0f, -1.88f, 1.5f, 0.8f});
}

TEST(PoseMapTest, UnknownPoseReturnsNullopt) {
  EXPECT_FALSE(px100_zenoh_gateway::pose_to_arm_cmd("banana").has_value());
}

TEST(PoseMapTest, EmptyStringReturnsNullopt) {
  EXPECT_FALSE(px100_zenoh_gateway::pose_to_arm_cmd("").has_value());
}

TEST(PoseMapTest, UppercaseIsRejectedCaseSensitive) {
  EXPECT_FALSE(px100_zenoh_gateway::pose_to_arm_cmd("Home").has_value());
}
