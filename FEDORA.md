# Fedora build and install

Stock **Fedora x86_64** build for AMD XDNA / `amdxdna`. This is the canonical guide for
this fork — no external setup scripts or source overlays required.

**Upstream reference:** [amd/xdna-driver](https://github.com/amd/xdna-driver) (Ubuntu/Arch).
**This fork:** https://github.com/IzzieBoopers/xdna-driver

Tested on **Fedora 44** (kernel `7.1.4-204.fc44.x86_64`).

## Branches

| Branch | Use |
|--------|-----|
| `fedora/stock-fc44` | **Recommended** — frozen, validated stock baseline |
| `fedora/compat` | Active Fedora compatibility work before re-freeze |
| `main` | AMD upstream mirror only — never patch for Fedora here |

Tag: `fedora-stock-fc44-2026-07-25` @ commit `d55a921`.

## Prerequisites

Install build dependencies:

```bash
sudo dnf install -y \
  git gcc gcc-c++ make cmake ninja-build pkgconf-pkg-config \
  kernel-devel-$(uname -r) \
  python3 python3-devel \
  boost-devel boost-static json-glib-devel libcurl-devel libuuid-devel \
  rapidjson-devel protobuf-compiler protobuf-devel \
  libdrm-devel elfutils-devel systemd-devel systemtap-sdt-devel \
  pciutils dkms openssl-devel ncurses-devel rpm-build \
  glibc-static libstdc++-static
```

Runtime (if not already present):

```bash
sudo dnf install -y xrt-base xrt-npu linux-firmware
```

Host configuration (required for NPU access):

```bash
# Render group for /dev/accel/*
sudo usermod -aG render "$USER"

# Unlimited memlock for buffer objects
sudo mkdir -p /etc/security/limits.d
sudo tee /etc/security/limits.d/99-amdxdna.conf > /dev/null <<'EOF'
* soft memlock unlimited
* hard memlock unlimited
EOF
```

Log out and back in after group/limits changes.

Optional: install all build deps via the tree's helper (delegates to XRT's `xrtdeps.sh`):

```bash
sudo ./tools/amdxdna_deps.sh
```

## Build

```bash
git clone --recurse-submodules https://github.com/IzzieBoopers/xdna-driver.git
cd xdna-driver
git switch fedora/stock-fc44

git submodule update --init --recursive
cd build
./build.sh -release
```

Build time: ~5–15 minutes (firmware/VTD blobs download on first package step).

### Build XRT base (if needed)

If `xrt-base` is not installed or version-mismatched, build from the submodule:

```bash
cd xrt/build
./build.sh -npu -opt
sudo dnf install -y ./Release/xrt-*.rpm ./Release/xrt-npu-*.rpm
cd ../../build
./build.sh -release
```

XRT version must match the plugin — use the submodule in this tree, not an arbitrary install.

### Output artifacts

| Artifact | Path |
|----------|------|
| Plugin RPM | `build/Release/xrt_plugin.*_amdxdna.rpm` |
| Primary `amdxdna.ko` | `build/Release/drivers/accel/amdxdna/amdxdna.ko` |
| Legacy module | `build/Release/src/driver/amdxdna/amdxdna.ko` |

The RPM installs the **upstream** `amdxdna` driver via DKMS (see package postinst script).

## Install

```bash
sudo dnf install -y ./build/Release/xrt_plugin.*_amdxdna.rpm
```

DKMS rebuilds `amdxdna.ko` for your running kernel on install. Ensure
`kernel-devel-$(uname -r)` is installed first.

## Verify

```bash
xrt-smi examine
xrt-smi validate
lsmod | grep amdxdna
modinfo amdxdna
ls -l /dev/accel/
```

Expected: NPU listed in `xrt-smi examine`, `amdxdna` loaded, `/dev/accel/accel0` present.

## Driver trees

| Tree | Module | Packaged in RPM? |
|------|--------|------------------|
| `drivers/accel/amdxdna/` | `amdxdna.ko` (primary) | **Yes** (DKMS) |
| `src/driver/amdxdna/` | `amdxdna_legacy.ko` | Shipped for compatibility |

Application and downstream driver work should target the **upstream** tree.

## Packaging

This fork generates **RPM** packages only (`CPack` → `dnf install`). Arch PKGBUILDs and
VE2/Yocto build paths have been removed from this fork.

## Relationship to Carbon

Carbon driver enhancements (custom sysfs, UAPI extensions) live in a **separate repository**
(`The_Iridium_Road/carbon/`), built on top of the frozen `fedora/stock-fc44` SHA. This
fork ships stock `amdxdna` only.

## Troubleshooting

**`cmake3 is not installed`** — use a commit with the Fedora cmake 4.x fix in
`build/build.sh`, or ensure `cmake` ≥ 3.19 is on `PATH`.

**Kernel module build fails** — `kernel-devel-$(uname -r)` must match the running kernel.
Reboot into the intended kernel, then reinstall `kernel-devel` and rebuild.

**NPU not visible** — check `linux-firmware`, `render` group membership, memlock limits,
and `xrt-smi examine` output.

**Command abort / mailbox timeout after install** — firmware/driver mismatch. Re-install the
plugin RPM and reload: `sudo modprobe -r amdxdna && sudo modprobe amdxdna`.

**NPU missing after upgrading an existing plugin RPM** — RPM scriptlet ordering can leave
DKMS unregistered. Re-run DKMS install and load:

```bash
sudo /opt/xilinx/xrt/share/amdxdna/dkms_driver.sh --install
sudo modprobe amdxdna
```

**Telemetry ioctls fail with `EINVAL`** — loaded driver is older than XRT SHIM. Install
this repo's RPM rather than a stale in-tree kernel module.
