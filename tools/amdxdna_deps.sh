#! /bin/bash -

# SPDX-License-Identifier: Apache-2.0
# Copyright (C) 2024-2025, Advanced Micro Devices, Inc.
#
# Fedora/RHEL dependency bootstrap for this fork.
# Ubuntu/Arch: use amd/xdna-driver upstream instead.

SCRIPT_DIR=$(readlink -f $(dirname ${BASH_SOURCE[0]}))

if [ -x "$(command -v dnf)" ]; then
    dnf install -y jq
elif [ -x "$(command -v yum)" ]; then
    yum install -y jq
else
    echo "This fork targets Fedora/RHEL. Install jq manually, or use amd/xdna-driver upstream." >&2
    exit 1
fi

$SCRIPT_DIR/../xrt/src/runtime_src/tools/scripts/xrtdeps.sh
