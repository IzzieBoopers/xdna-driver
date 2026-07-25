# Fedora build and install

Stock **Fedora x86_64** build for AMD XDNA / `amdxdna` using the upstream
`build/build.sh` path. No external setup scripts or source overlays required.

Tested on **Fedora 44** (Coffee, kernel `7.1.4-204.fc44.x86_64`).

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
  pciutils dkms openssl-devel ncurses-devel \
  glibc-static libstdc++-static
```

Runtime (if not already present):

```bash
sudo dnf install -y xrt-base xrt-npu
```

Add your user to the `render` group and raise memlock (logout required for group):

```bash
sudo usermod -aG render "$USER"
# /etc/security/limits.d/ — memlock unlimited for NPU workloads
```

## Build

```bash
git clone --recurse-submodules https://github.com/IzzieBoopers/xdna-driver.git
cd xdna-driver
git switch fedora/compat   # or fedora/stock-fc44 after F0 freeze

git submodule update --init --recursive
cd build
./build.sh -release
```

Build time: ~5–15 minutes depending on CPU and network (firmware/VTD blobs download on first package step).

### Output artifacts

| Artifact | Path |
|----------|------|
| Plugin RPM | `build/Release/xrt_plugin.*_amdxdna.rpm` |
| `amdxdna.ko` (upstream tree) | `build/Release/drivers/accel/.../amdxdna.ko` |
| Legacy module | `build/Release/src/driver/.../amdxdna.ko` |

The RPM installs the **upstream** `amdxdna` driver via DKMS (see package postinst).

## Install

```bash
sudo dnf install -y ./build/Release/xrt_plugin.*_amdxdna.rpm
```

If `xrt-base` is missing or wrong version, install matching XRT RPMs from the same
tree/submodule build or from AMD packages for your Fedora release.

## Verify

```bash
xrt-smi examine
xrt-smi validate
lsmod | grep amdxdna
modinfo amdxdna
```

## Driver trees

This tree builds two kernel modules:

- **`drivers/accel/amdxdna/`** — primary upstream driver (`amdxdna.ko` in RPM/DKMS)
- **`src/driver/amdxdna/`** — legacy out-of-tree copy (`amdxdna_legacy.ko`)

Carbon and application work should target the **upstream** tree unless you have a
specific reason to use the legacy module.

## Branch policy

| Branch | Purpose |
|--------|---------|
| `main` | Mirror of AMD `upstream/main` |
| `fedora/compat` | Active Fedora compatibility work |
| `fedora/stock-fc44` | Frozen stock baseline after validation |

Carbon driver enhancements live in a **separate repository** (`The_Iridium_Road/carbon/`), built on top of `fedora/stock-fc44`.

## Troubleshooting

**`cmake3 is not installed`** — update to a commit that includes the Fedora cmake 4.x fix in `build/build.sh`, or use CMake ≥ 3.19 as `cmake`.

**Kernel module build fails** — ensure `kernel-devel-$(uname -r)` matches running kernel.

**NPU not visible** — check firmware (`linux-firmware` package), `render` group, and `xrt-smi` output.
