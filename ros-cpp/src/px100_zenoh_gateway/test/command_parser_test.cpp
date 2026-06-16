#include <gtest/gtest.h>

#include <optional>
#include <string>

#include "px100_zenoh_gateway/command_parser.hpp"

TEST(CommandParserTest, WellFormedHomeYieldsPoseName) {
  const auto pose = px100_zenoh_gateway::parse_pose_name(R"({"pose":"home"})");
  ASSERT_TRUE(pose.has_value());
  EXPECT_EQ(*pose, "home");
}

TEST(CommandParserTest, SleepCommandYieldsItsName) {
  const auto pose = px100_zenoh_gateway::parse_pose_name(R"({"pose":"sleep"})");
  ASSERT_TRUE(pose.has_value());
  EXPECT_EQ(*pose, "sleep");
}

TEST(CommandParserTest, ExtraFieldsAreIgnored) {
  const auto pose =
      px100_zenoh_gateway::parse_pose_name(R"({"pose":"home","extra":42})");
  ASSERT_TRUE(pose.has_value());
  EXPECT_EQ(*pose, "home");
}

TEST(CommandParserTest, MissingPoseFieldReturnsNullopt) {
  EXPECT_FALSE(px100_zenoh_gateway::parse_pose_name("{}").has_value());
}

TEST(CommandParserTest, MalformedJsonReturnsNulloptNoThrow) {
  EXPECT_NO_THROW({
    const auto pose = px100_zenoh_gateway::parse_pose_name("not json");
    EXPECT_FALSE(pose.has_value());
  });
}

TEST(CommandParserTest, NonStringPoseReturnsNullopt) {
  EXPECT_FALSE(
      px100_zenoh_gateway::parse_pose_name(R"({"pose":123})").has_value());
}

TEST(CommandParserTest, EmptyInputReturnsNullopt) {
  EXPECT_FALSE(px100_zenoh_gateway::parse_pose_name("").has_value());
}
