#include <gtest/gtest.h>

#include "px100_zenoh_gateway/pose_query_handler.hpp"
#include "px100_zenoh_gateway/vendor/nlohmann/json.hpp"

TEST(PoseQueryHandlerTest, HomePayloadYieldsCommandAndOkAck) {
  const auto result =
      px100_zenoh_gateway::handle_pose_query(R"({"pose":"home"})");
  ASSERT_TRUE(result.command.has_value());
  EXPECT_EQ(result.command->name, "arm");
  ASSERT_EQ(result.command->cmd.size(), 4u);
  EXPECT_NEAR(result.command->cmd[0], 0.0f, 1e-6f);
  EXPECT_NEAR(result.command->cmd[1], 0.0f, 1e-6f);
  EXPECT_NEAR(result.command->cmd[2], 0.0f, 1e-6f);
  EXPECT_NEAR(result.command->cmd[3], 0.0f, 1e-6f);
  EXPECT_EQ(result.ack_json, R"({"ok":true})");
}

TEST(PoseQueryHandlerTest, SleepPayloadYieldsCommandAndOkAck) {
  const auto result =
      px100_zenoh_gateway::handle_pose_query(R"({"pose":"sleep"})");
  ASSERT_TRUE(result.command.has_value());
  EXPECT_EQ(result.command->name, "arm");
  ASSERT_EQ(result.command->cmd.size(), 4u);
  EXPECT_NEAR(result.command->cmd[0], 0.0f, 1e-6f);
  EXPECT_NEAR(result.command->cmd[1], -1.88f, 1e-6f);
  EXPECT_NEAR(result.command->cmd[2], 1.5f, 1e-6f);
  EXPECT_NEAR(result.command->cmd[3], 0.8f, 1e-6f);
  EXPECT_EQ(result.ack_json, R"({"ok":true})");
}

TEST(PoseQueryHandlerTest, UnknownPoseYieldsNoCommandAndUnknownPoseReject) {
  const auto result =
      px100_zenoh_gateway::handle_pose_query(R"({"pose":"banana"})");
  EXPECT_FALSE(result.command.has_value());

  const auto ack = nlohmann::json::parse(result.ack_json);
  EXPECT_EQ(ack.at("ok").get<bool>(), false);
  EXPECT_EQ(ack.at("error").get<std::string>(), "unknown_pose");
  // detail names the offending pose
  EXPECT_NE(ack.at("detail").get<std::string>().find("banana"),
            std::string::npos);
}

TEST(PoseQueryHandlerTest, MalformedJsonYieldsNoCommandAndMalformedReject) {
  EXPECT_NO_THROW({
    const auto result = px100_zenoh_gateway::handle_pose_query("not json");
    EXPECT_FALSE(result.command.has_value());

    const auto ack = nlohmann::json::parse(result.ack_json);
    EXPECT_EQ(ack.at("ok").get<bool>(), false);
    EXPECT_EQ(ack.at("error").get<std::string>(), "malformed");
  });
}

TEST(PoseQueryHandlerTest, MissingPoseFieldMapsToMalformed) {
  const auto result = px100_zenoh_gateway::handle_pose_query("{}");
  EXPECT_FALSE(result.command.has_value());

  const auto ack = nlohmann::json::parse(result.ack_json);
  EXPECT_EQ(ack.at("ok").get<bool>(), false);
  EXPECT_EQ(ack.at("error").get<std::string>(), "malformed");
}

TEST(PoseQueryHandlerTest, NonStringPoseFieldMapsToMalformed) {
  const auto result = px100_zenoh_gateway::handle_pose_query(R"({"pose":5})");
  EXPECT_FALSE(result.command.has_value());

  const auto ack = nlohmann::json::parse(result.ack_json);
  EXPECT_EQ(ack.at("ok").get<bool>(), false);
  EXPECT_EQ(ack.at("error").get<std::string>(), "malformed");
}

TEST(PoseQueryHandlerTest, OkAckParsesToExactlyOkTrue) {
  const auto result =
      px100_zenoh_gateway::handle_pose_query(R"({"pose":"home"})");
  const auto ack = nlohmann::json::parse(result.ack_json);
  EXPECT_TRUE(ack.is_object());
  EXPECT_EQ(ack.size(), 1u);  // only the "ok" key, no error/detail
  EXPECT_EQ(ack.at("ok").get<bool>(), true);
}
