# 高级文档

> 中文译文。英文原文见 [README.md](README.md)。技术名词、代码、路径、命令与日志一律保留原文。

设备主页之外的一切：按版本划分的移植笔记与构建指南、构建服务器运行手册，
以及本项目为了让老 Android 跑在新硬件上而编写的软件。

刚接触？从[主 README](../../README.zh-CN.md)开始。设备主页（描述、各版本状态）
与怪癖页位于 [`docs/devices/`](../devices/)。

## 按 Android 版本划分的移植笔记

某个版本的通用实战手册：源码与工具链、构建系统上的意外、init/Edify/ABI
差异，以及在该时代各设备间可通用的实战教训。

| 版本 | AOSP 分支 | 笔记 | 已移植到 |
| --- | --- | --- | --- |
| Donut 1.6 | `android-1.6_r2` (DRD35) | [porting-notes/donut.zh-CN.md](porting-notes/donut.zh-CN.md) | [cooper](../devices/cooper/README.zh-CN.md), [maple](../devices/maple/README.zh-CN.md) |
| KitKat 4.4.4 | `android-4.4.4_r2` (KTU84Q) | [porting-notes/kitkat.zh-CN.md](porting-notes/kitkat.zh-CN.md) | [maple](../devices/maple/README.zh-CN.md), [poplar](../devices/poplar/README.zh-CN.md) |

计划中的实战手册（尚未撰写 —— 它们随各版本的首个移植一并落地）：Eclair、Froyo、
Gingerbread、Ice Cream Sandwich、Jelly Bean（4.1–4.3）、
Lollipop、Marshmallow、Nougat。

## 按 Android 版本划分的构建指南

从干净的 AOSP 检出到可刷入镜像的分步流程：

- [为 cooper/maple 构建 Donut 1.6](build/donut.zh-CN.md) —— Hardy i386 chroot、
  JDK 5、GCC 4.2.3、cooper BML 打包；maple 沿用同一套配方，只是改用 4096 页的 boot.img
  重打包、ext4 system.img 打包脚本，以及 maple 设备树（`devices/maple/donut/`）。
- [为 maple 构建 KitKat 4.4.4](build/kitkat.zh-CN.md) —— Trusty/JDK 6
  容器、预编译 4.4 kernel、libhyb closure 暂存、simg2img/TWRP 刷入
  （poplar 较早的基于 glrenderd 的镜像：块映射/面板差异见
  [poplar 怪癖](../devices/poplar/quirks.zh-CN.md)）。
- [构建服务器运行手册](build-server.zh-CN.md) —— 在远程宿主上构建时的布局、
  坑点与刷入流程。

## 项目软件

- [vtouch](software/vtouch.zh-CN.md) —— 多点触控到单点触控的输入代理；
  让多点触控面板在支持多点触控之前的版本（Donut 1.6）上可用。
- [libhyb](software/libhyb.zh-CN.md) —— 在 KitKat 进程内运行较新的 GPU 驱动
  （Adreno 540、Lineage 22.1 closure），由 64 位的 `fbpresentd` 通过 MDSS atomic
  commit 呈现。它取代了 glrenderd 的 chroot/socket 方案（`tools/glrenderd/` 的源码已进
  git 历史）。自 2026-10-19 起，同一个 loader 还承载了面向 `audio.primary.maple` 的
  Android 15 **ACDB 音频校准 loader**（扬声器播放已在真机验证）。
- [mkbootimg-cooper](software/mkbootimg-cooper.zh-CN.md) —— 打了 pagesize
  补丁的 Donut `mkbootimg`，可打包 cooper 的 boot.img。

## 参考笔记

- [charquirks-mapping.md](charquirks-mapping.zh-CN.md) —— 姊妹移植的
  4.2-on-pdx203 笔记如何映射到 maple/KitKat（哪些是各自独立
  收敛的、哪些直接适用、哪些还在队列中）。
- [taimen-kitkat-mapping.md](taimen-kitkat-mapping.zh-CN.md) —— Pixel 2 XL 的
  KitKat 移植（DoomGuy41/Taimen-KitKat）如何映射到我们这边：libhyb 图形核心、
  他们的每一份补丁（已采用的、或带理由跳过的），以及对他们那套面向 maple 的
  64 位 daemon chroot + HAL 桥（modem/wifi/sensors/GNSS/NFC/BT）的评估。
- [poplar-kitkat-gpu-fixes.md](poplar-kitkat-gpu-fixes.zh-CN.md) —— 姊妹机 XZ1
  （`poplar`）GPU/显示修复参考（在 poplar 上开发，由 maple 采用）；在 maple 侧
  已被 [libhyb](software/libhyb.zh-CN.md) 取代 —— poplar 仍跑着较早的 glrenderd
  方案（见其 README）。
