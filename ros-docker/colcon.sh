#!/usr/bin/env bash
# Run colcon (or any colcon verb) inside the px100-robot lyrical container,
# against the ros-cpp/ workspace bind-mounted at /work.
#
# This is the proven "option B" dev loop: source is edited on the host, build
# and test run in the container (where the ROS 2 / colcon toolchain lives).
# The host workspace is a bind mount, so host edits are live in the container;
# build/install/log land back in ros-cpp/ owned by the host user (--user).
#
# Usage:
#   ros-docker/colcon.sh build
#   ros-docker/colcon.sh test
#   ros-docker/colcon.sh test-result --all --verbose
#
# Override the image with PX100_IMAGE=... if needed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_DIR="$(cd "${SCRIPT_DIR}/../ros-cpp" && pwd)"
IMAGE="${PX100_IMAGE:-px100-robot:dev}"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

# Run as root inside the container so the interbotix overlay under /root
# (mode 700) is traversable and its setup.bash can be sourced; then chown the
# build/install/log artifacts back to the invoking host user so the
# bind-mounted workspace stays host-owned. Running as the host user directly
# cannot read the /root overlay, so interbotix_xs_msgs would not be found.
exec docker run --rm \
  -e HOME=/tmp \
  --entrypoint bash \
  -v "${WS_DIR}:/work" -w /work \
  "${IMAGE}" -c "source /opt/ros/lyrical/setup.bash \
    && source /root/interbotix_ws/install/setup.bash 2>/dev/null || true; \
    colcon $*; rc=\$?; \
    chown -R ${HOST_UID}:${HOST_GID} /work/build /work/install /work/log 2>/dev/null || true; \
    exit \$rc"
