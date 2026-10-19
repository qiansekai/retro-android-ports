# cooper（三星 Galaxy Ace GT-S5830）移植

> 中文译文。英文原文见 [README.md](README.md)。技术名词、代码、路径、命令与日志一律保留原文。

## donut/ —— Donut 1.6（DRD35）设备树

可直接放入 `aosp-donut/vendor/samsung/cooper/`（`lunch full_cooper-eng`）。
内容：

- `BoardConfig.mk`、`cooper.mk`、`AndroidProducts.mk`、`AndroidBoard.mk` ——
  构建配置（BML 几何 `0x13600000`/4096，平台 `cooper`，
  `USE_CAMERA_STUB=false`，`TARGET_PROVIDES_INIT_RC`）。
- `kernel`、`modules/` —— CM 内核（`2.6.35.7-perf-CL882825`）+ FSR/STL
  模块（后备）；`kernel-twrp`、`modules-twrp/` —— TWRP/Omni 内核
  （`2.6.35.7-androidarmv6+`），实际随包发布的正是这一对。
- `init.rc`、`init.gt-s5830.rc`、`ueventd.gt-s5830.rc` —— Donut init，含
  stl12/13/14 挂载、STL 卷扫描打通、ath6kl 预 insmod。
- `libaudio/` —— cooper 的 `libaudio.so`（msm7k 音频去掉 HTC acoustic 依赖；
  40 字节内核 `msm_audio_config` 修复）。扬声器音频可用。
- `libcamera/` —— CooperCamera V4L2/测试图案 HAL（`toggleshutter` 位于
  `camerashutter/`）。
- `vtouch/` —— Synaptics RMI4 type-A 多点 → 单点 uinput 代理
  （在多指触摸之前的 Donut 上驱动触摸屏）。
- `proprietary/` —— 构建所用的设备 blob。
- keymaps（`qwerty.kl`、`sec_key.kl`、`sec_jack.kl`、`sec_touchscreen.kl`、
  `cooper_vtouch.kl`）、`system.prop`（160 dpi、`keyguard.no_require_sim`）、
  `vold.fstab`、`egl.cfg`、`wpa_supplicant.conf`。

同步进 checkout：

```sh
scripts/sync-device-tree.sh cooper donut        # -> $AOSP_DIR/vendor/samsung/cooper
```

构建（在 Hardy chroot 内）：`lunch full_cooper-eng && make -j8`。
打包：`scripts/build-cooper-donut-full.py`（或 `...-skeleton.py` 生成
小体积预览 zip）。设备页与怪癖：
[`docs/devices/cooper/`](../../docs/devices/cooper/README.zh-CN.md)；构建指南：
[`docs/advanced/build/donut.md`](../../docs/advanced/build/donut.zh-CN.md)。
