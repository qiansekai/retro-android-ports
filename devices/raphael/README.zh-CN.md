# raphael（Redmi K20 Pro / Mi 9T Pro）移植

> 中文译文。英文原文见 [README.md](README.md)。技术名词、代码、路径、命令与日志一律保留原文。

## kitkat/ —— KitKat 4.4.4（KTU84Q）设备树（打通阶段）

可直接放入 `aosp-kitkat/vendor/xiaomi/raphael/`
（`lunch full_raphael-eng`）。

内容：

- `BoardConfig.mk`、`full_raphael.mk`、`AndroidProducts.mk`、
  `AndroidBoard.mk` —— 构建配置。在 4.14 ARM64 内核（`CONFIG_COMPAT`）上
  运行 32 位 `arm`/`cortex-a15` 用户空间，`TARGET_PREBUILT_KERNEL` =
  从 Lineage boot 镜像中提取的 `Image.gz`（不入 git），
  `TARGET_BOARD_PLATFORM := raphael` 以避开 KitKat 的 msm8960/8974 HAL，
  `phone-xhdpi-2048` Dalvik 堆，`WITH_DEXPREOPT`。
- `system.prop` —— 实测密度 440，1080x2340，GLES 2.0 报告，
  eng adb。
- `fstab.raphael` —— 首次打通：system 放在 `cust`（sda30，1 GB），
  cache 在 sda29，persist 在 sda23；`/data` 是 tmpfs，由
  `init.raphael.rc` 挂载（不清 userdata）。
- `init.rc`（官方 + 单条 `${ro.hardware}` import）、`init.raphael.rc`
  （binderfs 挂载，按裸节点挂载并预建目录、`setenforce 0`、
  tmpfs `/data`、configfs USB）、`init.raphael.usb.rc` + `usbudc.sh`
  （DWC3 `a600000.dwc3` adb gadget）、`ueventd.raphael.rc`。
- `hwcomposer/` —— 最小 HWC 1.1（`hwcomposer.raphael`），让 KitKat 的
  SurfaceFlinger 在没有 fbdev 时不会中止；所有层都由 GLES
  合成，`eglSwapBuffers` 把帧转给 glrenderd。
- `touchscreen.idc` —— Goodix GT9886。
- `glrenderd.sh` —— 1080x2340；presenter 后端尚未决定
  （DRM/KMS 还是内核 `vfb`）。

参考（不入 git）：LineageOS `android_device_xiaomi_raphael` +
`android_device_xiaomi_sm8150-common` 与 4.14 内核
（`android_kernel_xiaomi_sm8150`）；Adreno 640 blob 来自
`TheMuppets/proprietary_vendor_xiaomi_sm8150-common`。

同步进 checkout：

```sh
AOSP_DIR=$ROOT/aosp-kitkat scripts/sync-device-tree.sh raphael kitkat
```

构建（在 Trusty chroot 内）：`lunch full_raphael-eng && make -j$(nproc)`。
boot 镜像必须用较新的 `mkbootimg`（header v2）重打包；
KitKat 自带的 mkbootimg 只会产出 v0。
