# 三星 Galaxy Ace GT-S5830/L/T（`cooper`）

> 中文译文。英文原文见 [README.md](README.md)。技术名词、代码、路径、命令与日志一律保留原文。

![Samsung Galaxy Ace](device.jpg)

*图片来源：[Freddy2001](https://commons.wikimedia.org/wiki/File:Samsung_Galaxy_Ace.png)，CC BY-SA 3.0，via Wikimedia Commons。*

Galaxy Ace 是 2011 年的中端机型，采用 Qualcomm 的 **MSM7227**
（ARMv6，800 MHz），278 MB RAM，3.5 英寸 **320×480 HVGA** 面板
（约 165 ppi），Adreno 200，5 MP 相机，microSD 以及三星专有的
FSR/STL NAND 栈。它出厂搭载 Froyo，并升级到 Gingerbread ——
这使它成为 **Donut 1.6** 的真正复古目标，一个比硬件还老的系统。
GT-S5830/L/T 是不同射频频段的变体；基于 Broadcom 的
**GT-S5830i（`cooperve`）是另一套 SoC，不受支持**。

## 状态

### Donut 1.6 — AOSP `android-1.6_r2`（DRD35）— 可启动

| 方面 | 状态 |
| --- | --- |
| 启动 | 完整系统启动到 Donut 主屏（首次启动 10–20 分钟，期间对 32 个 APK 做 dexopt） |
| 桌面 / UI | 可用 |
| 触摸屏 | 可用，含经 [vtouch](../../advanced/software/vtouch.zh-CN.md) 的电容 MENU/HOME/BACK/SEARCH |
| 显示 | 可用，处于实测的原厂密度 **160 dpi**，软件渲染（`libagl`） |
| 音频 | 扬声器可用（cooper msm7k HAL，不依赖 HTC acoustic） |
| 按键 | HOME 与电源/休眠/唤醒可用，经 cooper keymaps + provisioning 修复 |
| 存储 | 内部的 system/data/cache 位于 FSR/STL ext4；SD 卡尚未可用（vold 已禁用） |
| USB | `adb pull`/`push`（sync）可用；交互式 `adb shell` 仍然脆弱 |
| 相机 | 应用可打开，测试图案预览；**无实时 sensor 数据**（需要内核驱动工作） |
| WiFi | 进行中 —— ath6kl 能探测到 SDIO 卡，固件路径尚未在 Donut 启动中验证 |
| 蜂窝网络 | **不可能**：MSM7227 没有 Donut RIL 库 |
| GPU | 无 —— Donut 没有 Adreno 200 的 EGL 路径；仅软件渲染 |
| BT / FM / GPS | 未开始（专有模块/库尚未集成） |

每一条结论的证据与日期：[怪癖](quirks.zh-CN.md)。

**版本发布：** 可刷写的 CWM/TWRP zip 发布在
[GitHub Releases](https://github.com/pukikiko/retro-android-ports/releases)
—— 找 `full_cooper-1.6.DRD35-UNOFFICIAL-FULL-*.zip`。

## 文档与链接

- [**设备怪癖**](quirks.zh-CN.md) —— 分区布局、FSR/STL、内核、音频、
  显示密度、recovery 交互、打通历史。
- [Donut 1.6 移植笔记](../../advanced/porting-notes/donut.zh-CN.md) —— 本次
  移植产出的通用实战手册。
- [为 cooper 构建 Donut](../../advanced/build/donut.zh-CN.md)。
- [设备树](../../../devices/cooper/donut/)（`devices/cooper/donut/`）与
  [AOSP 补丁](../../../patches/donut/README.zh-CN.md)（`patches/donut/`）。
- 此处用到的工具：[vtouch](../../advanced/software/vtouch.zh-CN.md)、
  [mkbootimg-cooper](../../advanced/software/mkbootimg-cooper.zh-CN.md)。
