# maple（Sony Xperia XZ Premium G8141/G8142）移植

> 中文译文。英文原文见 [README.md](README.md)。技术名词、代码、路径、命令与日志一律保留原文。

## kitkat/ —— KitKat 4.4.4（KTU84Q）设备树（可启动 —— 2026 年 10 月）

可直接放入 `aosp-kitkat/vendor/sony/maple/`（`lunch full_maple-eng`）。

内容：

- `BoardConfig.mk`、`full_maple.mk`、`AndroidProducts.mk`、`AndroidBoard.mk` ——
  构建配置（GPT/ext4 布局，boot base `0x00000000`/4096，
  `TARGET_PREBUILT_KERNEL`（TWRP 导出的 blob，不入 git），
  `TARGET_BOARD_PLATFORM := maple` 以避开 KitKat 的 msm8960/8974 HAL，
  `phone-xhdpi-2048` Dalvik 堆继承，`WITH_DEXPREOPT`）。
- `system.prop` —— 实测密度 410，wifi/model/brand，GLES 2.0 报告。
- `fstab.maple` —— GPT/ext4（system→sde46，cache→sda5，userdata→sda15，
  persist→sda4；by-name 位于 `/dev/block/platform/soc/by-name/`，这正是
  KitKat 的 ueventd 实际创建的）。
- `init.rc`（官方 + 单条 `${ro.hardware}` import）、`init.maple.rc`
  （按裸节点做 GPT 挂载并预建目录、setenforce 0、configfs
  USB gadget 兜底）、`init.maple.usb.rc` + `usbudc.sh`（DWC3 adb
  gadget 打通）、`ueventd.maple.rc`（节点属主）。
- `glrenderd.sh`、`clearpad.idc`、`gpio-keys.kl`、overlay（模拟
  存储列表、导航栏、密度）—— 哪些能用（启动、触摸、显示、adb、经 glrenderd 的
  硬件 GL）与哪些仍未解（音频/WiFi/RIL/相机）见 `docs/devices/maple/quirks.md`。

参考（不入 git，与 cooper blob 同一策略）：Sony
`android_device_sony_maple`（`ten` 分支）+ `yoshino-common`
`BoardConfigPlatform.mk`（msm8998，base 0/pagesize 4096，boot 64 MB），
内核 `sony/msm8998`（4.4，`Image.gz-dtb`）。

同步进 checkout：

```sh
scripts/sync-device-tree.sh maple kitkat  # -> $AOSP_DIR/vendor/sony/maple
# or: AOSP_DIR=$ROOT/aosp-kitkat scripts/sync-device-tree.sh maple kitkat
```

构建（填好后，在 KitKat 容器/chroot 内）：
`lunch full_maple-eng && make -j$(nproc)`。
设备页、状态与打通日志：
[`docs/devices/maple/`](../../docs/devices/maple/README.zh-CN.md)；构建指南：
[`docs/advanced/build/kitkat.md`](../../docs/advanced/build/kitkat.zh-CN.md)；
KitKat 实战手册：
[`docs/advanced/porting-notes/kitkat.md`](../../docs/advanced/porting-notes/kitkat.zh-CN.md)。

### 为什么 `TARGET_BOARD_PLATFORM` 仍未定

cooper 用 `TARGET_BOARD_PLATFORM := cooper` 把 Donut 那个 Dream 时代的
`hardware/msm7k` HAL 挡在构建之外。maple 对 KitKat 的
`hardware/qcom/*`（msm8960/msm8974 时代）vs msm8998 需要同样的决定：
在 QCOM HAL 路径被证明可用之前**不要**设 `msm8998` —— 骨架设成 `maple`，
并在每个 HAL 移植完成前使用通用 audio/camera/gps。见
`BoardConfig.mk` 注释。
