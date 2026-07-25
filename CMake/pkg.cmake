# SPDX-License-Identifier: Apache-2.0
# Copyright (C) 2023-2026, Advanced Micro Devices, Inc. All rights reserved.

execute_process(
  COMMAND awk -F= "$1==\"ID\" {print $2}" /etc/os-release
  COMMAND tr -d "\""
  OUTPUT_VARIABLE XDNA_CPACK_LINUX_FLAVOR
  OUTPUT_STRIP_TRAILING_WHITESPACE
  )

if ("${XDNA_CPACK_LINUX_FLAVOR}" MATCHES "^(ubuntu)")
  execute_process(
    COMMAND dpkg --print-architecture
    OUTPUT_VARIABLE XDNA_CPACK_ARCH
    OUTPUT_STRIP_TRAILING_WHITESPACE
    )
else("${XDNA_CPACK_LINUX_FLAVOR}" MATCHES "^(ubuntu)")
  execute_process(
    COMMAND uname -m
    OUTPUT_VARIABLE XDNA_CPACK_ARCH
    OUTPUT_STRIP_TRAILING_WHITESPACE
    )
endif("${XDNA_CPACK_LINUX_FLAVOR}" MATCHES "^(ubuntu)")

execute_process(
  COMMAND awk -F= "$1==\"VERSION_ID\" {print $2}" /etc/os-release
  COMMAND tr -d "\""
  OUTPUT_VARIABLE XDNA_CPACK_LINUX_VERSION
  OUTPUT_STRIP_TRAILING_WHITESPACE
  )
execute_process(
  COMMAND bash -c "source /etc/os-release && echo \"\$ID \$ID_LIKE\""
  OUTPUT_VARIABLE XDNA_CPACK_LINUX_PKG_FLAVOR
  OUTPUT_STRIP_TRAILING_WHITESPACE
  )
execute_process(
  COMMAND echo ${XRT_VERSION_STRING}
  COMMAND awk -F. "{print $1}"
  OUTPUT_VARIABLE CPACK_PACKAGE_VERSION_MAJOR
  OUTPUT_STRIP_TRAILING_WHITESPACE
  )
execute_process(
  COMMAND echo ${XRT_VERSION_STRING}
  COMMAND awk -F. "{print $2}"
  OUTPUT_VARIABLE CPACK_PACKAGE_VERSION_MINOR
  OUTPUT_STRIP_TRAILING_WHITESPACE
  )

set(XRT_PLUGIN_VERSION_STRING
  ${CPACK_PACKAGE_VERSION_MAJOR}.${CPACK_PACKAGE_VERSION_MINOR}.${XRT_PLUGIN_VERSION_PATCH})
set(CPACK_SET_DESTDIR ON)
set(CPACK_COMPONENTS_ALL ${XDNA_COMPONENT})
set(CPACK_PACKAGE_VENDOR "AMD Inc")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "XDNA driver plugin for Xilinx RunTime")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/xrt/LICENSE")
set(CPACK_PACKAGE_CONTACT "max.zhen@amd.com")
set(CPACK_PACKAGE_NAME "xrt_plugin")
set(CPACK_PACKAGE_FILE_NAME
  "${CPACK_PACKAGE_NAME}.${XRT_PLUGIN_VERSION_STRING}_${XDNA_CPACK_LINUX_VERSION}-${XDNA_CPACK_ARCH}")
math(EXPR next_minor "${CPACK_PACKAGE_VERSION_MINOR} + 1")
set(XDNA_CPACK_XRT_BASE_VERSION ${CPACK_PACKAGE_VERSION_MAJOR}.${CPACK_PACKAGE_VERSION_MINOR})
set(XDNA_CPACK_XRT_BASE_NEXT_VERSION ${CPACK_PACKAGE_VERSION_MAJOR}.${next_minor})

# VTD archives are fetched by build/build.sh from the "Repo: VTD" section of
# tools/WHENCE (see tools/sync_from_whence.py vtd).
set(VTD_ARCHIVES_DIR "${CMAKE_CURRENT_BINARY_DIR}/../amdxdna_bins/vtd_archives")
message(STATUS "Using VTD archives from ${VTD_ARCHIVES_DIR}")

install(DIRECTORY ${VTD_ARCHIVES_DIR}/
  DESTINATION ${XDNA_PKG_DATA_DIR}/bins
  COMPONENT ${XDNA_COMPONENT}
  FILES_MATCHING
  PATTERN "*.a"
  )

if(NOT SKIP_KMOD)

# Install both the versioned firmware files (e.g. 1.8_npu.sbin.2.5.0.172) and
# the stable npu.dev.sbin / cert.dev.sbin symlinks that point at them, so the
# installed file name still reveals the firmware version. The tree is built
# from the drm-firmware WHENCE manifest by tools/sync_from_whence.py firmware.
install(DIRECTORY ${AMDXDNA_BINS_DIR}/firmware/
  DESTINATION ${XDNA_PKG_FW_DIR}
  COMPONENT ${XDNA_COMPONENT}
  FILES_MATCHING
  PATTERN "*.sbin*"
  PATTERN "download_raw" EXCLUDE
  )

if(XDNA_DRV_INT_SRC_DIR AND XDNA_DRV_INT_NAME)
  set(INT_RMMOD "rmmod ${XDNA_DRV_INT_NAME} > /dev/null 2>&1")
  set(INT_DBG_INSMOD "modprobe ${XDNA_DRV_INT_NAME} dyndbg=+pf")
  set(INT_INSMOD "modprobe ${XDNA_DRV_INT_NAME}")
endif()

configure_file(
  ${CMAKE_CURRENT_SOURCE_DIR}/CMake/config/postinst.in
  ${CMAKE_CURRENT_BINARY_DIR}/package/postinst
  @ONLY
  )
configure_file(
  ${CMAKE_CURRENT_SOURCE_DIR}/CMake/config/prerm.in
  ${CMAKE_CURRENT_BINARY_DIR}/package/prerm
  @ONLY
  )

endif(NOT SKIP_KMOD)

if("${XDNA_CPACK_LINUX_PKG_FLAVOR}" MATCHES "fedora|rhel|centos|rocky|almalinux|mariner")
  set(CPACK_GENERATOR "RPM")
  set(CPACK_RPM_COMPONENT_INSTALL ON)
  set(CPACK_RPM_PACKAGE_REQUIRES "xrt-base >= ${XDNA_CPACK_XRT_BASE_VERSION}, xrt-base < ${XDNA_CPACK_XRT_BASE_NEXT_VERSION}")
  if(NOT SKIP_KMOD)
    set(CPACK_RPM_POST_INSTALL_SCRIPT_FILE "${CMAKE_CURRENT_BINARY_DIR}/package/postinst")
    set(CPACK_RPM_PRE_UNINSTALL_SCRIPT_FILE "${CMAKE_CURRENT_BINARY_DIR}/package/prerm")
  endif()
else()
  message(FATAL_ERROR "This fork builds RPM packages for Fedora/RHEL-family systems only. "
    "Detected: ${XDNA_CPACK_LINUX_PKG_FLAVOR}. "
    "For Ubuntu/Debian or Arch, use https://github.com/amd/xdna-driver upstream.")
endif()

include(CPack)
