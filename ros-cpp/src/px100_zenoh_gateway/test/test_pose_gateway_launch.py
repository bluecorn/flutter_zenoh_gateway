# launch_testing integration test for the px100_zenoh_gateway node (Slice 3).
#
# Proves the full federation path of the queryable command-ack design:
#   raw zenoh-cpp querier (zenoh_test_querier) --[get on plain Zenoh key
#   px100/cmd/pose, JSON payload]--> gateway_node raw zenoh QUERYABLE -->
#   handle_pose_query --> (a) rclcpp publisher /px100/commands/joint_group
#   --[rmw_zenoh]--> rclpy subscriber  AND  (b) query.reply(ack JSON) back to
#   the querier, which prints the reply ack to stdout.
#
# Federation: rmw_zenohd is launched first as the Zenoh router on
# tcp/localhost:7447. Both the gateway's raw zenoh session and the C++ test
# querier (zenoh_test_querier) open client sessions that connect to that
# router, so the plain-key get/reply is relayed through the router. The ROS
# pub/sub uses the same router for rmw_zenoh discovery.
#
# Querier decision (per spec): python `zenoh` is NOT present in the
# px100-robot image, so the test drives the small C++ querier executable
# (zenoh_test_querier, Slice 2) built under BUILD_TESTING with
# zenoh_cpp_vendor, guaranteeing a version-matched Zenoh with the gateway.
#
# LOAD-BEARING INVARIANT: every gateway answer is a query.reply() ack — a
# business rejection (unknown pose / malformed JSON) is a valid JSON ack with
# "ok":false, never a query.reply_err(). Bad input must never crash the node.

import json
import os
import subprocess
import time
import unittest

import launch
import launch.actions
import launch_ros.actions
import launch_testing.actions
import launch_testing.markers

import pytest

import rclpy
from rclpy.node import Node

from ament_index_python.packages import get_package_prefix

from interbotix_xs_msgs.msg import JointGroupCommand


ZENOH_KEY = "px100/cmd/pose"
ROS_TOPIC = "/px100/commands/joint_group"


def _test_querier_path():
    # zenoh_test_querier is installed to lib/px100_zenoh_gateway/ by CMake.
    prefix = get_package_prefix("px100_zenoh_gateway")
    return os.path.join(
        prefix, "lib", "px100_zenoh_gateway", "zenoh_test_querier"
    )


@pytest.mark.launch_test
@launch_testing.markers.keep_alive
def generate_test_description():
    router = launch.actions.ExecuteProcess(
        cmd=["ros2", "run", "rmw_zenoh_cpp", "rmw_zenohd"],
        output="screen",
    )

    gateway = launch_ros.actions.Node(
        package="px100_zenoh_gateway",
        executable="gateway_node",
        name="px100_zenoh_gateway",
        output="screen",
    )

    # Let the router come up, then the node + its zenoh queryable settle.
    ready = launch.actions.TimerAction(
        period=8.0,
        actions=[launch_testing.actions.ReadyToTest()],
    )

    return launch.LaunchDescription([
        router,
        launch.actions.TimerAction(period=3.0, actions=[gateway]),
        ready,
    ]), {"gateway": gateway, "router": router}


class _Collector(Node):
    def __init__(self):
        super().__init__("test_jgc_collector")
        self.received = []
        self.create_subscription(
            JointGroupCommand, ROS_TOPIC, self._cb, 10
        )

    def _cb(self, msg):
        self.received.append(msg)


class TestPoseGateway(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        rclpy.init()
        cls.querier_path = _test_querier_path()

    @classmethod
    def tearDownClass(cls):
        rclpy.shutdown()

    def setUp(self):
        self.node = _Collector()

    def tearDown(self):
        self.node.destroy_node()

    def _zenoh_query(self, payload, key=ZENOH_KEY):
        # Run the C++ querier as a one-shot get and capture the reply ack it
        # prints to stdout. Returns (returncode, stdout_text).
        proc = subprocess.run(
            [self.querier_path, key, payload],
            check=False,
            timeout=20,
            capture_output=True,
            text=True,
        )
        return proc.returncode, proc.stdout.strip()

    def _spin_collect(self, expect_count, timeout_s):
        deadline = time.time() + timeout_s
        while time.time() < deadline:
            rclpy.spin_once(self.node, timeout_sec=0.2)
            if len(self.node.received) >= expect_count:
                break
        return list(self.node.received)

    def test_1_home_publishes_command_and_replies_ok(self, proc_output):
        rc, ack = self._zenoh_query('{"pose":"home"}')
        self.assertEqual(rc, 0, "querier must receive a reply (exit 0)")
        ack_obj = json.loads(ack)
        self.assertTrue(ack_obj.get("ok"), f"expected ok ack, got: {ack}")
        msgs = self._spin_collect(1, 15.0)
        self.assertEqual(len(msgs), 1, "expected exactly one JointGroupCommand")
        self.assertEqual(msgs[0].name, "arm")
        self.assertEqual(len(msgs[0].cmd), 4)
        for got, want in zip(msgs[0].cmd, [0.0, 0.0, 0.0, 0.0]):
            self.assertAlmostEqual(got, want, places=5)

    def test_2_sleep_publishes_command_and_replies_ok(self, proc_output):
        rc, ack = self._zenoh_query('{"pose":"sleep"}')
        self.assertEqual(rc, 0, "querier must receive a reply (exit 0)")
        ack_obj = json.loads(ack)
        self.assertTrue(ack_obj.get("ok"), f"expected ok ack, got: {ack}")
        msgs = self._spin_collect(1, 15.0)
        self.assertEqual(len(msgs), 1, "expected exactly one JointGroupCommand")
        self.assertEqual(msgs[0].name, "arm")
        self.assertEqual(len(msgs[0].cmd), 4)
        for got, want in zip(msgs[0].cmd, [0.0, -1.88, 1.5, 0.8]):
            self.assertAlmostEqual(got, want, places=5)

    def test_3_unknown_pose_replies_reject_and_publishes_nothing(
        self, proc_output
    ):
        rc, ack = self._zenoh_query('{"pose":"banana"}')
        # A business rejection is still a delivered reply() ack (exit 0), NOT a
        # transport error reply (which the querier reports as exit != 0).
        self.assertEqual(rc, 0, "rejection must still be a reply() ack (exit 0)")
        ack_obj = json.loads(ack)
        self.assertFalse(ack_obj.get("ok"), f"expected ok:false, got: {ack}")
        self.assertEqual(ack_obj.get("error"), "unknown_pose")
        msgs = self._spin_collect(1, 6.0)
        self.assertEqual(len(msgs), 0, "unknown pose must not publish")

    def test_4_malformed_then_valid(self, proc_output):
        # Malformed JSON gets a reply() reject ack, publishes nothing, and the
        # node must survive (liveness) to serve a subsequent valid command.
        rc, ack = self._zenoh_query("not json")
        self.assertEqual(
            rc, 0, "malformed input must still be a reply() ack (exit 0)"
        )
        ack_obj = json.loads(ack)
        self.assertFalse(ack_obj.get("ok"), f"expected ok:false, got: {ack}")
        self.assertEqual(ack_obj.get("error"), "malformed")
        msgs = self._spin_collect(1, 6.0)
        self.assertEqual(len(msgs), 0, "malformed JSON must not publish")

        # Node must still be alive and serve a subsequent valid command + ack.
        rc2, ack2 = self._zenoh_query('{"pose":"home"}')
        self.assertEqual(rc2, 0, "node must survive bad input and still reply")
        ack2_obj = json.loads(ack2)
        self.assertTrue(ack2_obj.get("ok"), f"expected ok ack, got: {ack2}")
        msgs = self._spin_collect(1, 15.0)
        self.assertEqual(
            len(msgs), 1, "node must survive bad input and still serve valid"
        )
        self.assertEqual(msgs[0].name, "arm")


@launch_testing.post_shutdown_test()
class TestPoseGatewayShutdown(unittest.TestCase):

    def test_gateway_exits_cleanly(self, proc_info, gateway):
        # The node is keep_alive / killed at shutdown; assert it did not crash
        # with a nonzero code during the active phase (liveness is proven in
        # test_4). Allowable codes cover clean exit and signal teardown.
        launch_testing.asserts.assertExitCodes(
            proc_info,
            allowable_exit_codes=[0, -2, -15, -9],
            process=gateway,
        )
