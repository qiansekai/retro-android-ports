# poplar（Sony Xperia XZ1 G8341/G8342/G8343）移植

> 中文译文。英文原文见 [README.md](README.md)。技术名词、代码、路径、命令与日志一律保留原文。

## kitkat/ —— KitKat 4.4.4（KTU84Q）设备树（可启动 + 硬件 GL —— 2026 年 10 月）

可直接放入 `aosp-kitkat/vendor/sony/poplar/`（`lunch full_poplar-eng`）。
与 [`maple`](../maple/README.zh-CN.md) 同平台（yoshino/MSM8998）—— poplar 正是
maple 那套设备树所派生自的树，所以两者几乎一模一样是刻意的。

内容：

- `BoardConfig.mk`、`full_poplar.mk`、`AndroidProducts.mk`、`AndroidBoard.mk` —— 构建
  配置（GPT/ext4 布局，boot base `0x00000000`/4096，`TARGET_PREBUILT_KERNEL`
  （导出的 blob，不入 git），`TARGET_BOARD_PLATFORM := poplar` 以避开 KitKat 的
  msm8960/8974 HAL，`phone-xhdpi-2048` Dalvik 堆继承，`WITH_DEXPREOPT`）。
- `system.prop` —— 实测密度 430，wifi/model/brand，GLES 2.0 报告。
- `fstab.poplar` —— 按裸节点的 GPT/ext4（system→sda65，userdata→sda66，cache→sda53，
  persist→sda33；by-name 链接位于 `/dev/block/platform/soc/by-name/`，
  这正是 KitKat 的 ueventd 创建的）。挂载本身在
  `init.poplar.rc` 里，不在此文件。
- `init.rc`（官方 + 单条 `${ro.hardware}` import）、`init.poplar.rc`（按
  裸节点做 GPT 挂载并预建目录、`setenforce 0`、启动渲染器、displaytune +
  启动日志服务）、`init.poplar.usb.rc` + `usbudc.sh`（DWC3 adb gadget —— 拆成
  每步一个 action，因为一条失败的 init 命令会静默中止它所在的整个 action）、
  `ueventd.poplar.rc`。
- `lights/` —— `lights.poplar` HAL。没有 lights 模块，框架永远不会
  熄屏，亮度也不起作用（无 lights HAL = 无休眠也无唤醒）。
  **maple 此后已获得双节点（`lcd-backlight` + `wled`）变体 —— 同步前先看
  `docs/devices/poplar/quirks.md` 的差异说明。**
- `displaytune.sh` —— 启动时一次性修正显示，取代旧的 keepawake
  变通做法（后者会让「熄屏」立刻又亮起）。
- `glrenderd.sh`、`clearpad.idc`、`gpio-keys.kl`、`autowinch.sh`、`dump-boot-log.sh`、
  overlay（模拟存储列表、导航栏、密度）。

参考（不入 git，与 cooper blob 同一策略）：Sony
`android_device_sony_poplar`（`ten` 分支）+ `yoshino-common`
`BoardConfigPlatform.mk`（msm8998，base 0/pagesize 4096，boot 64 MB），内核
`sony/msm8998`（4.4，`Image.gz-dtb`）。

同步进 checkout：

```sh
scripts/sync-device-tree.sh poplar kitkat  # -> $AOSP_DIR/vendor/sony/poplar
```

构建（在 KitKat 容器/chroot 内）：`lunch full_poplar-eng && make -j$(nproc)`。
设备历史、规格与阻塞项：
[`docs/devices/poplar/`](../../docs/devices/poplar/README.zh-CN.md)。
KitKat 实战手册：[`docs/advanced/porting-notes/kitkat.md`](../../docs/advanced/porting-notes/kitkat.zh-CN.md)；
GPU 修复：[`docs/advanced/poplar-kitkat-gpu-fixes.md`](../../docs/advanced/poplar-kitkat-gpu-fixes.zh-CN.md)。

### poplar vs maple

设备树形状相同。不同之处：

| | poplar | maple |
| --- | --- | --- |
| 面板 | 5.2 英寸 1080x1920 command-mode，原生 | 5.5 英寸 3840x2160 4K HDR，按 1080p 渲染 |
| boot / system | `sda38` / `sda65` | `sde35` / `sde46` |
| userdata / cache / persist | `sda66` / `sda53` / `sda33` | `sda15` / `sda5` / `sda4` |
| 密度 | 430 | 410 |
| 额外内容 | `lights/`、`displaytune.sh` | 双节点 `lights/`、无 `displaytune.sh`（方向见怪癖） |

poplar 的 `usbudc.sh` 还会（重新）构建 gadget，而不只是绑定 UDC；它的
`init.*.usb.rc` 把 gadget 打通拆成独立的 action。在某一台设备上的修复
是另一台的候选修复 —— 通过回读验证。
