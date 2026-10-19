# Redmi K20 Pro (raphael, SM8150) BoardConfig for Android KitKat (4.4.4)
#
# Derived from devices/maple/kitkat (Sony XZ Premium, MSM8998) and adapted
# to raphael. Differences that matter:
#   - kernel is a 4.14 Lineage Image.gz (header v2 boot image), not 4.4
#   - no fbdev: /dev/graphics/fb0 does not exist, only /dev/dri
#   - binderfs is enabled, the 4.4 userspace must mount it (init.raphael.rc)
#   - retrofit dynamic partitions (system/vendor on phys system/vendor);
#     the first bringup puts /system on the unused 1 GB `cust` partition
#   - Adreno 640, Goodix GT9886 touch, WCN3990-class wifi (not in MVP)

LOCAL_PATH := $(call my-dir)

TARGET_NO_BOOTLOADER := true
TARGET_NO_RADIOIMAGE := true
TARGET_PROVIDES_INIT_RC := true

# Kernel: raw Image.gz extracted from the running Lineage boot.img
# (dumps/raphael-kk/boot-raw/kernel, 20,539,377 bytes, gzip).
# boot.img is repacked with a modern mkbootimg (header v2) outside the
# KitKat build system; KitKat's own mkbootimg only emits v0.
TARGET_PREBUILT_KERNEL := vendor/xiaomi/raphael/kernel
BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_PAGESIZE := 4096
BOARD_KERNEL_IMAGE_NAME := Image.gz

# Cmdline from the Lineage boot header (magiskboot header dump), with
# androidboot.hardware changed to raphael so init imports
# /init.raphael.rc, selinux permissive, configfs gadget on.
BOARD_KERNEL_CMDLINE := androidboot.hardware=raphael androidboot.console=ttyMSM0 androidboot.memcg=1 lpm_levels.sleep_disabled=1 msm_rtb.filter=0x237 service_locator.enable=1 swiotlb=2048 loop.max_part=7 androidboot.usbcontroller=a600000.dwc3 androidboot.fstab_suffix=raphael androidboot.init_fatal_reboot_target=recovery androidboot.selinux=permissive androidboot.configfs=true

# Physical partitions measured on the device (2026-10-17):
#   boot 128 MB, cache 256 MB (sda29), cust 1 GB (sda30), persist sda23.
# `cust` is listed in BOARD_SUPER_PARTITION_BLOCK_DEVICES but has no
# extents in the current super metadata (lpdump), so the first bringup
# borrows it for /system; /data is tmpfs.
BOARD_BOOTIMAGE_PARTITION_SIZE := 134217728
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 134217728
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 1073741824
BOARD_CACHEIMAGE_PARTITION_SIZE := 268435456
BOARD_USERDATAIMAGE_PARTITION_SIZE := 268435456
BOARD_FLASH_BLOCK_SIZE := 262144

TARGET_USERIMAGES_USE_EXT4 := true
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4

# Deliberately `raphael`, not sm8150: KitKat's hardware/qcom HALs only
# know msm8960/8974-era targets.
TARGET_BOARD_PLATFORM := raphael
TARGET_BOARD_PLATFORM_GPU := qcom-adreno640

# Guest half of glrenderd (goldfish GL libs stream to @glrenderd).
BUILD_EMULATOR_OPENGL := true

# KitKat only preopts user builds by default; without this first boot
# dexopts every jar/apk on the phone.
WITH_DEXPREOPT := true

# 32-bit KitKat userspace on an ARM64 SoC (KitKat has no arm64 support;
# the running kernel has CONFIG_COMPAT and the device ships 32-bit libs).
TARGET_ARCH := arm
TARGET_ARCH_VARIANT := armv7-a-neon
TARGET_CPU_ABI := armeabi-v7a
TARGET_CPU_ABI2 := armeabi
TARGET_CPU_VARIANT := cortex-a15
TARGET_CPU_SMP := true

TARGET_OTA_ASSERT_DEVICE := raphael
TARGET_SCREEN_DENSITY := 440

# MVP has no wifi/bt/audio/camera HALs. Keep them off so the build does
# not pull generic stubs that open missing devices.
# USE_CAMERA_STUB := true
