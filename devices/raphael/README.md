# raphael (Redmi K20 Pro / Mi 9T Pro) ports

## kitkat/ — KitKat 4.4.4 (KTU84Q) device tree (bringup)

Drop-in target for `aosp-kitkat/vendor/xiaomi/raphael/`
(`lunch full_raphael-eng`).

Contents:

- `BoardConfig.mk`, `full_raphael.mk`, `AndroidProducts.mk`,
  `AndroidBoard.mk` — build config. 32-bit `arm`/`cortex-a15` userspace on
  a 4.14 ARM64 kernel (`CONFIG_COMPAT`), `TARGET_PREBUILT_KERNEL` =
  `Image.gz` extracted from the Lineage boot image (out of git),
  `TARGET_BOARD_PLATFORM := raphael` to dodge KitKat's msm8960/8974 HALs,
  `phone-xhdpi-2048` Dalvik heap, `WITH_DEXPREOPT`.
- `system.prop` — measured density 440, 1080x2340, GLES 2.0 report,
  eng adb.
- `fstab.raphael` — first bringup: system on `cust` (sda30, 1 GB),
  cache on sda29, persist on sda23; `/data` is tmpfs and mounted by
  `init.raphael.rc` (no userdata wipe).
- `init.rc` (stock + single `${ro.hardware}` import), `init.raphael.rc`
  (binderfs mount, raw-node mounts with pre-created dirs, `setenforce 0`,
  tmpfs `/data`, configfs USB), `init.raphael.usb.rc` + `usbudc.sh`
  (DWC3 `a600000.dwc3` adb gadget), `ueventd.raphael.rc`.
- `hwcomposer/` — minimal HWC 1.1 (`hwcomposer.raphael`) so KitKat's
  SurfaceFlinger does not abort without fbdev; all layers are GLES
  composed and `eglSwapBuffers` forwards frames to glrenderd.
- `touchscreen.idc` — Goodix GT9886.
- `glrenderd.sh` — 1080x2340; presenter backend still to be decided
  (DRM/KMS vs a kernel `vfb`).

Reference (not in git): LineageOS `android_device_xiaomi_raphael` +
`android_device_xiaomi_sm8150-common` and the 4.14 kernel
(`android_kernel_xiaomi_sm8150`); Adreno 640 blobs from
`TheMuppets/proprietary_vendor_xiaomi_sm8150-common`.

Sync into a checkout:

```sh
AOSP_DIR=$ROOT/aosp-kitkat scripts/sync-device-tree.sh raphael kitkat
```

Build inside the Trusty chroot: `lunch full_raphael-eng && make -j$(nproc)`.
The boot image must be repacked with a modern `mkbootimg` (header v2);
KitKat's own mkbootimg only emits v0.
