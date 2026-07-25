# AMD XDNA™ Driver for Fedora Linux

**Fedora x86_64 fork** of the [AMD xdna-driver](https://github.com/amd/xdna-driver) tree.
This repository builds the `amdxdna` kernel module, XRT SHIM libraries, and an installable
**RPM** plugin package for Fedora using the upstream `build/build.sh` path.

> **Not Ubuntu or Arch.** For Debian/Ubuntu `.deb` or Arch `PKGBUILD` workflows, use
> [amd/xdna-driver](https://github.com/amd/xdna-driver) upstream. This fork targets
> **Fedora and RHEL-family** systems only.

**Full build/install guide:** [FEDORA.md](FEDORA.md)

| Branch | Purpose |
|--------|---------|
| `fedora/stock-fc44` | Frozen stock baseline (recommended for builds) |
| `fedora/compat` | Active Fedora compatibility fixes |
| `main` | AMD upstream mirror — do not patch here |
| `carbon/base-2026-07-25` | Frozen AMD reference pin |

Fork: https://github.com/IzzieBoopers/xdna-driver

---

## Table of Contents

- [Introduction](#introduction)
- [System Requirements](#system-requirements)
- [Quick Start](#quick-start)
- [Driver Trees](#driver-trees)
- [Test](#test)
- [Q&A](#qa)
- [Upstream and Branches](#upstream-and-branches)
- [Contributor Guidelines](#contributor-guidelines)

## Introduction

This repository supports XRT on AMD XDNA / NPU devices on **Fedora Linux**. With XRT base
packages and the plugin RPM installed, applications can use the NPU through the standard
XRT runtime (`/opt/xilinx/xrt`).

The release build produces:

- `xrt_plugin.*_amdxdna.rpm` — SHIM libraries, firmware, and DKMS driver sources
- `amdxdna.ko` — primary upstream kernel module (packaged via DKMS in the RPM)

## System Requirements

**Hardware**

- NPU host: AMD Ryzen AI (or other supported XDNA device)
- Build machine: x86_64 (any modern CPU; AMD recommended)

**Software**

- **Fedora** x86_64 (tested on Fedora 44; RHEL-family RPM path also supported)
- **Linux kernel** ≥ 6.10 with `CONFIG_DRM_ACCEL` and `CONFIG_AMD_IOMMU`
- **XRT base** — `xrt-base` and `xrt-npu` RPMs matching the XRT submodule in this tree
- **Build tools** — see [FEDORA.md](FEDORA.md) for the full `dnf install` list

Fedora 44+ ships a suitable kernel in the default repos. Ensure
`kernel-devel-$(uname -r)` matches your running kernel before building the module.

## Quick Start

```bash
git clone --recurse-submodules https://github.com/IzzieBoopers/xdna-driver.git
cd xdna-driver
git switch fedora/stock-fc44

git submodule update --init --recursive
cd build
./build.sh -release

sudo dnf install -y ./Release/xrt_plugin.*_amdxdna.rpm
```

Install matching XRT base RPMs first if needed (build from the `xrt/` submodule or use
packages already on your system — versions must align). See [FEDORA.md](FEDORA.md).

**Runtime setup** (group membership, memlock limits): also in [FEDORA.md](FEDORA.md).

## Driver Trees

This repository contains **two** independent driver source trees:

| Path | Role |
|------|------|
| `drivers/accel/amdxdna/` | **Primary** upstream (staging) driver — built into the RPM/DKMS as `amdxdna.ko` |
| `src/driver/amdxdna/` | Legacy out-of-tree copy — built as `amdxdna_legacy.ko` for compatibility |

`./build.sh -release` builds **both** modules. The RPM installs the upstream tree via DKMS.
See `./build.sh -h` for flags that swap which module ships as primary `amdxdna.ko`.

The RPM also ships:

- `.so` libraries under `/opt/xilinx/xrt/lib64`
- NPU firmware under `/usr/lib/firmware/amdnpu/`
- DKMS scripts to build and load the kernel module on install

## Test

```bash
source /opt/xilinx/xrt/setup.sh   # if not already in your environment
xrt-smi examine
xrt-smi validate
lsmod | grep amdxdna
modinfo amdxdna
```

## Q&A

### Q: I want to debug my application — how do I build with `-g`?

Run `./build.sh -debug` (or plain `./build.sh`) to produce a debug RPM alongside the
release build.

### Q: I'm developing `amdxdna.ko`. How do I enable `XDNA_DBG()` print?

`XDNA_DBG()` uses Linux `CONFIG_DYNAMIC_DEBUG`. See the
[kernel dynamic debug howto](https://www.kernel.org/doc/html/latest/admin-guide/dynamic-debug-howto.html).

```bash
sudo modprobe amdxdna dyndbg=+pf
```

### Q: `dnf install` of the plugin RPM failed. What next?

Build a debug RPM (`./build.sh -debug`), retry install, and capture the full `dnf`/`rpm`
output. DKMS build failures usually mean `kernel-devel-$(uname -r)` is missing or mismatched.

### Q: Can I use the NPU to accelerate ML training?

The NPU is designed for **inference**, not training.

### Q: How do I allocate huge buffer objects?

There is no BO size limit from XRT itself; Linux ulimits can block large allocations.
Check and raise memlock:

```bash
ulimit -l    # kbytes

sudo mkdir -p /etc/security/limits.d
sudo tee /etc/security/limits.d/99-amdxdna.conf > /dev/null <<'EOF'
* soft memlock unlimited
* hard memlock unlimited
EOF
# Log out and back in, then re-check: ulimit -l
```

### Q: `xrt-smi` sees the NPU but commands abort or the mailbox times out?

Usually a **firmware/driver version mismatch**. Re-install the plugin RPM so firmware under
`/usr/lib/firmware/amdnpu/` matches the loaded `amdxdna.ko`, then reload the driver.

### Q: Telemetry or array queries return `EOPNOTSUPP` / `EINVAL`?

Your XRT/plugin may be newer than an older in-tree `amdxdna`. Install the driver from this
repo's RPM (upstream staging `amdxdna.ko`) rather than a stale distro kernel module.

## Upstream and Branches

```text
amd/xdna-driver (upstream)
        │
fork main ─────────────── AMD mirror (sync only)
        │
carbon/base-2026-07-25 ── frozen AMD pin
        │
fedora/compat ─────────── Fedora fixes
        │
fedora/stock-fc44 ─────── frozen Fedora stock (build from here)
```

Carbon kernel enhancements live in a **separate repository** (`The_Iridium_Road/carbon/`),
not in this fork. This tree ships **stock** `amdxdna` only.

To sync with AMD upstream `main`:

```bash
git switch main
git fetch upstream
git reset --hard upstream/main
git submodule update --init --recursive
```

Merge AMD changes into `fedora/compat` deliberately when rebasing Fedora fixes.

## Contributor Guidelines

1. Read [FEDORA.md](FEDORA.md) and [System Requirements](#system-requirements)
2. Put Fedora-only changes on `fedora/compat` (then freeze to `fedora/stock-fc44` when validated)
3. Do **not** commit Fedora patches to `main` (AMD mirror) or frozen stock branches
4. Run Linux `checkpatch.pl` before commit — see [Checkpatch](#checkpatch)

### Checkpatch

```bash
cp tools/pre-commit .git/hooks/
```

`git commit` rejects commits until checkpatch passes.

```bash
./tools/codingsty_check.sh <DIR>
```
