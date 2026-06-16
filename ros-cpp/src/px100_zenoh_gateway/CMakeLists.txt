cmake_minimum_required(VERSION 3.10)
project(px100_zenoh_gateway)

find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(interbotix_xs_msgs REQUIRED)
find_package(zenoh_cpp_vendor REQUIRED)
find_package(zenohcxx REQUIRED)

add_executable(gateway_node src/gateway_node.cpp)
target_include_directories(gateway_node PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(gateway_node rclcpp::rclcpp ${interbotix_xs_msgs_TARGETS} zenohcxx::zenohc)

install(TARGETS gateway_node DESTINATION lib/${PROJECT_NAME})

if(BUILD_TESTING)
  find_package(ament_cmake_gtest REQUIRED)
  ament_add_gtest(smoke_test test/smoke_test.cpp)
  target_include_directories(smoke_test PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)

  ament_add_gtest(pose_map_test test/pose_map_test.cpp)
  target_include_directories(pose_map_test PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)

  ament_add_gtest(command_parser_test test/command_parser_test.cpp)
  target_include_directories(command_parser_test PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)

  ament_add_gtest(joint_group_command_builder_test test/joint_group_command_builder_test.cpp)
  target_include_directories(joint_group_command_builder_test PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_link_libraries(joint_group_command_builder_test ${interbotix_xs_msgs_TARGETS})

  ament_add_gtest(pose_query_handler_test test/pose_query_handler_test.cpp)
  target_include_directories(pose_query_handler_test PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_link_libraries(pose_query_handler_test ${interbotix_xs_msgs_TARGETS})

  # Raw zenoh-cpp querier used by the launch_testing integration test to drive
  # the gateway over the plain Zenoh key via a get/reply (version-matched via
  # zenoh_cpp_vendor; python `zenoh` is not in the image).
  add_executable(zenoh_test_querier test/zenoh_test_querier.cpp)
  target_link_libraries(zenoh_test_querier zenohcxx::zenohc)
  install(TARGETS zenoh_test_querier DESTINATION lib/${PROJECT_NAME})

  find_package(launch_testing_ament_cmake REQUIRED)
  add_launch_test(test/test_pose_gateway_launch.py TIMEOUT 120)
endif()

ament_package()
