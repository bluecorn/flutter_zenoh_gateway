#include <gtest/gtest.h>

#include <string>

#include "px100_zenoh_gateway/version.hpp"

// Walking-skeleton smoke test: proves the colcon + ament_cmake_gtest loop runs
// against this package. Version-agnostic on purpose (asserts "set", not a
// specific value) so release version bumps don't break it.
TEST(SmokeTest, VersionIsSet) {
  EXPECT_FALSE(std::string(px100_zenoh_gateway::version()).empty());
}
