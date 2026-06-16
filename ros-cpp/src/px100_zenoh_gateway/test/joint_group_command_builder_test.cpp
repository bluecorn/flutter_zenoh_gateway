#include <gtest/gtest.h>

#include <vector>

#include "px100_zenoh_gateway/joint_group_command_builder.hpp"

TEST(JointGroupCommandBuilderTest, SetsArmGroupName) {
  const auto msg = px100_zenoh_gateway::build_arm_command({0.0f, 0.0f, 0.0f, 0.0f});
  EXPECT_EQ(msg.name, "arm");
}

TEST(JointGroupCommandBuilderTest, CopiesCommandArrayVerbatim) {
  const std::vector<float> cmd{0.0f, -1.88f, 1.5f, 0.8f};
  const auto msg = px100_zenoh_gateway::build_arm_command(cmd);
  ASSERT_EQ(msg.cmd.size(), 4u);
  EXPECT_NEAR(msg.cmd[0], 0.0f, 1e-6f);
  EXPECT_NEAR(msg.cmd[1], -1.88f, 1e-6f);
  EXPECT_NEAR(msg.cmd[2], 1.5f, 1e-6f);
  EXPECT_NEAR(msg.cmd[3], 0.8f, 1e-6f);
}

TEST(JointGroupCommandBuilderTest, EmptyArrayProducesEmptyCmd) {
  const auto msg = px100_zenoh_gateway::build_arm_command({});
  EXPECT_EQ(msg.name, "arm");
  EXPECT_TRUE(msg.cmd.empty());
}
