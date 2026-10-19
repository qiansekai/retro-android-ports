# Sony Xperia XZ1 G8341/G8342（poplar）

> 中文译文。英文原文见 [README.md](README.md)。技术名词、代码、路径、命令与日志一律保留原文。

*图片来源：TODO —— 尚未提交 Commons 照片（缺少 `device.jpg`）。*

XZ1 是 Sony 2017 年的紧凑型旗舰，采用 Qualcomm 的 **Snapdragon 835
（MSM8998）**：Kryo（ARM64）+ Adreno 540，4 GB RAM，64 GB UFS，microSD，
5.2 英寸 1080x1920 IPS LCD（command-mode 面板，在我们的移植中密度为 430），
USB-C。它出厂搭载 **Oreo 8.0**；`poplar` 是 G8341，
`poplar_dsds` 是双卡版 G8342（另有 `poplar-kddi` SOV36）。我们的移植
使其运行 **KitKat 4.4.4** —— 与 [maple](../maple/README.zh-CN.md) 同为
yoshino/MSM8998 平台，显示与 GPU 工作正源于 maple。

## 状态

### KitKat 4.4.4 — AOSP `android-4.4.4_r2`（KTU84Q）— 启动到 UI

| 方面 | 状态 |
| --- | --- |
| 启动 | 启动到桌面 + 导航栏（`sys.boot_completed=1`），1080x1920 |
| 桌面 / UI | 可用 |
| 触摸 | 可用（Clearpad，全量程坐标，导航栏 + gpio 按键） |
| 显示 | 可用，command-mode 面板，fb0 stride 4352 B（1088 px） |
| GPU | **硬件 GL，经 [glrenderd](../../advanced/software/glrenderd.zh-CN.md)**（Adreno 540） |
| USB | adb 可用（configfs gadget） |
| 灯光 | 亮度 + 休眠经 `lights.poplar`（仅 `lcd-backlight` 节点 —— maple 此后已获得双节点；见怪癖） |
| WiFi / 音频 | 尚未 —— 本设备树早于 maple TEST 36-37（没有 supplicant 服务，没有 adsp 启动）；需要前移 |
| 蜂窝网络 / 相机 / GPS / BT | 未开始 |

细节、块映射（`sda38`/`sda65`/`sda66`/`sda53`/`sda33`）与已验证的
修复：[怪癖](quirks.zh-CN.md)。

**版本发布：** poplar 镜像在本地构建 —— 尚无公开 zip；见
[构建 KitKat](../../advanced/build/kitkat.zh-CN.md)（maple 的步骤 + 怪癖页中的
poplar 差异）。

## 文档与链接

- [**设备怪癖**](quirks.zh-CN.md) —— 硬件快照、分区布局、poplar 与 maple 的差异、init 接线、已验证的修复。
- [KitKat 4.4.4 移植笔记](../../advanced/porting-notes/kitkat.zh-CN.md) ——
  通用实战手册。
- [构建 KitKat](../../advanced/build/kitkat.zh-CN.md)。
- [设备树](../../../devices/poplar/kitkat/)（`devices/poplar/kitkat/`）
  与 [AOSP 补丁](../../../patches/kitkat/README.zh-CN.md)（`patches/kitkat/`）。
- 姊妹设备：[maple](../maple/README.zh-CN.md)。参考：[poplar GPU 修复](../../advanced/poplar-kitkat-gpu-fixes.zh-CN.md)，
  工具：[glrenderd](../../advanced/software/glrenderd.zh-CN.md)。
