# flutter_zenoh_gateway

A **Flutter app that controls a Trossen Interbotix PincherX-100 arm over
[Zenoh](https://zenoh.io) via a thin robot-side gateway.** The app is a *dumb*
client — it exchanges **plain JSON over Zenoh** with a small C++ ROS node
(**`px100_zenoh_gateway`**) that owns all the ROS/Zenoh wire semantics and
relays commands to the proven Interbotix `xs_sdk` node.

This is the **gateway** demo — the proven, fail-safe path. Its sibling,
**`flutter_zenoh_direct`**, takes the opposite approach: a smart client that
speaks the ROS 2 wire format directly with no gateway node. The two are
deliberately different philosophies, not a runtime toggle.

## What it does

- **Two buttons** → command the arm to its **home** and **sleep** poses.
- The app `query`s the Zenoh key `px100/cmd/pose` with `{"pose":"home"}` /
  `{"pose":"sleep"}`; the gateway **replies** with a structured ack
  (`ok` / `unknown_pose` / `malformed`), so the app shows **✓ delivered**,
  **✗ rejected**, or an **error**.

The app never touches the ROS wire format — the gateway is the single
translation point (JSON ⇄ `interbotix_xs_msgs` CDR, Zenoh ⇄ ROS).

## Repository layout

```
flutter_zenoh_gateway/
├── app/                 the Flutter app (MVVM + Riverpod, JSON-over-Zenoh)
├── zenoh_dart/          the zenoh-dart binding (git submodule, pinned v0.19.0)
├── ros-cpp/             colcon workspace — the px100_zenoh_gateway C++ node
├── ros-docker/          colcon.sh build loop + sim/hardware composes
├── LICENSE              Apache-2.0
└── README.md            you are here
```

## Prerequisites

- **Flutter** (stable) with Linux desktop enabled.
- **Docker** + the **`px100-robot`** image. Pull and retag the published copy,
  or override with `PX100_IMAGE`:
  ```
  docker pull ghcr.io/hugo-bluecorn/px100-robot:latest
  docker tag  ghcr.io/hugo-bluecorn/px100-robot:latest px100-robot:dev
  ```
- A **graphical session** (`DISPLAY`) for the app window and rviz.
- Clone with submodules so the `zenoh_dart` binding is present:
  ```
  git clone --recurse-submodules <this repo>
  # or, after a plain clone:
  git submodule update --init --recursive
  ```

## Build the gateway

The composes bind-mount `ros-cpp/` into the container and run the gateway from
its `install/`, so build it once (and after any change). The build runs **inside
the container** via the dev-loop wrapper:

```
bash ros-docker/colcon.sh build
bash ros-docker/colcon.sh test        # optional
```

## Run it — simulator (no hardware)

```
xhost +local:
docker compose -f ros-docker/compose.sim-rviz-hostnet.yaml up
# in another terminal:
cd app && flutter run -d linux
```

In the app, connect to **`tcp/127.0.0.1:7447`** and tap **Home** / **Sleep**.
The sim arm moves, rviz mirrors it, and the app shows the gateway's ack. Tear
down with:

```
docker compose -f ros-docker/compose.sim-rviz-hostnet.yaml down
```

## Run it — real arm (hardware)

The hardware path needs the physical PincherX-100, its 12V PSU, and the U2D2
adapter enumerated as `/dev/ttyDXL`. On a **fresh plug**, the U2D2 bus needs a
one-time **cold-start warmup** before the stack will publish joint states. The
warmup script and full hardware procedure live in the sibling stack repo,
**[`bluecorn/pincherx-100-docker-lyrical`](https://github.com/hugo-bluecorn/pincherx-100-docker-lyrical)**
(`scripts/arm-warmup.sh`, expect `5/5` motors).

```
# 1. warm the U2D2 bus (from a checkout of the sibling stack repo)
./scripts/arm-warmup.sh        # expect 5/5 motors
# 2. let the container reach your X server
xhost +local:
# 3. bring up the real-arm stack + rviz + gateway (host networking)
docker compose -f ros-docker/compose.hardware-rviz-hostnet.yaml up
# 4. another terminal:
cd app && flutter run -d linux
```

Connect to **`tcp/127.0.0.1:7447`**, tap **Sleep** then **Home** — the real arm
moves and rviz mirrors it. Park the arm folded (tap **Sleep**) before tearing
down.

> **Networking note.** The steps above use the **host-net** compose
> (`compose.hardware-rviz-hostnet.yaml`), which is the most robust: `rmw_zenohd`
> binds the host's `:7447` directly, so the app connects with no docker-bridge in
> the path. A bridge variant with a published port
> (`compose.hardware-rviz.yaml`, connect `tcp/localhost:7447`) also exists, but on
> some host networks the host cannot forward into docker bridge networks and the
> app's connection will fail — prefer the `-hostnet` variant there (it mirrors the
> sim compose's host-net default).

## The JSON-over-Zenoh contract

| Action | Zenoh key | App → gateway | Gateway → `xs_sdk` |
|---|---|---|---|
| Home | `px100/cmd/pose` (query) | `{"pose":"home"}` | `JointGroupCommand{name:"arm",cmd:[0,0,0,0]}` |
| Sleep | `px100/cmd/pose` (query) | `{"pose":"sleep"}` | `JointGroupCommand{name:"arm",cmd:[0,-1.88,1.5,0.8]}` |

The gateway replies to each query with a structured JSON ack. Unknown poses and
malformed JSON publish nothing, return an error ack, and never crash the node.

## License

Apache-2.0 — see [LICENSE](LICENSE). © 2026 Bluecorn. A proof-of-concept, not a
commercial product.
