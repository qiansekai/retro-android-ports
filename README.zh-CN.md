# 复古 Android 移植（Retro Android Ports）

> 中文译文。英文原文见 [README.md](README.md)。技术名词、代码、路径、命令与日志一律保留原文。

在新硬件上运行远古 Android 版本。本项目把 **Donut 1.6 到 Nougat 7.1** 的 AOSP 移植到许多从未官方运行过这些版本的设备上 —— 并把每一条踩坑得来的经验提炼成可复用的实战手册，让下一个设备比上一个更省力。

目前已验证：

- **Android 1.6 Donut**（AOSP `android-1.6_r2`，DRD35）运行在 **三星 Galaxy Ace GT-S5830**（`cooper`，2011 年，MSM7227）—— 可启动，触摸屏（含电容按键）、出厂 160 dpi 显示、扬声器音频均可用。可刷写的 CWM/TWRP zip 见 [Releases](https://github.com/pukikiko/retro-android-ports/releases)。
- **Android 4.4.4 KitKat**（AOSP `android-4.4.4_r2`，KTU84Q）运行在 **Sony Xperia XZ Premium**（`maple`，2017 年，MSM8998）—— 启动到桌面，触摸、USB adb、Adreno 540 上的硬件 GL/GLES 3.2 均可用（经 [glrenderd](docs/advanced/software/glrenderd.zh-CN.md)）。

Cupcake 1.5 不在范围内：`platform/manifest` 已不再带 `cupcake`/`android-1.5` 分支（`android-1.6_r1` 是最老的），所以 Donut 是仍能同步的最老版本。完整故事 —— 以及为什么一台 2011 年跑 Froyo/Gingerbread 的手机才是真正的复古目标 —— 见 [Donut 移植笔记](docs/advanced/porting-notes/donut.zh-CN.md)。

## 支持设备

| 设备 | 代号 | 移植 | 状态 |
| --- | --- | --- | --- |
| Samsung Galaxy Ace GT-S5830/L/T | `cooper` | Donut 1.6 (DRD35) | 真机可启动；桌面、触摸屏 + 电容按键、160 dpi 显示、扬声器音频。蜂窝网络不可能（MSM7227 没有 Donut RIL）；相机预览只有测试图案。[设备页](docs/devices/cooper/README.zh-CN.md) |
| Sony Xperia XZ Premium G8141/G8142 | `maple` | KitKat 4.4.4 (KTU84Q) | 启动到 UI；触摸、显示、USB adb、硬件 GL/GLES 3.2（Adreno 540）、亮度/休眠、模拟存储、**音频播放（tasha 声卡）**。WiFi 接口仍未打通：SERVREG_LOC 现在由树内 `pdserve` 提供，PDR 链（icnss）也注册上了 notifier，但 modem 根 PD 每 ~41 秒崩溃一次，wlan_pd/WLFW 来不及启动（modem 稳定性/保活未解）。[设备页](docs/devices/maple/README.zh-CN.md) |
| Sony Xperia XZ1 G8341/G8342 | `poplar` | KitKat 4.4.4 (KTU84Q) | 启动到 UI（Launcher + 导航栏、触摸、显示、USB adb、经 glrenderd 的硬件 GL）。与 maple 同为 yoshino/MSM8998 平台；设备树早于 maple TEST 36-37。[设备页](docs/devices/poplar/README.zh-CN.md) |

每台设备都有一个主页（描述、逐版本状态、链接）和一个**怪癖**页（移植到该设备所需的全部信息 —— 分区布局、已验证的修复、未解缺口）：[cooper](docs/devices/cooper/quirks.zh-CN.md)、[maple](docs/devices/maple/quirks.zh-CN.md)、[poplar](docs/devices/poplar/quirks.zh-CN.md)。

发布 zip：[GitHub Releases](https://github.com/pukikiko/retro-android-ports/releases)
（cooper 的产物命名为 `full_cooper-*`；maple 镜像在本地构建 —— 见 [KitKat 构建指南](docs/advanced/build/kitkat.zh-CN.md)）。

## 进阶文档

[进阶文档索引](docs/advanced/README.zh-CN.md) 汇总了设备页之外的一切：

- **逐版本移植笔记** —— [Donut 1.6](docs/advanced/porting-notes/donut.zh-CN.md)、
  [KitKat 4.4.4](docs/advanced/porting-notes/kitkat.zh-CN.md)：工具链、构建系统的意外之处、
  init/Edify/ABI 差异与实战教训。
- **逐版本构建指南** —— [cooper 的 Donut](docs/advanced/build/donut.zh-CN.md)、
  [maple 的 KitKat](docs/advanced/build/kitkat.zh-CN.md)，外加
  [构建服务器运行手册](docs/advanced/build-server.zh-CN.md)。
- **自研软件** —— [vtouch](docs/advanced/software/vtouch.zh-CN.md)
  （为多指触摸之前的 Android 做「多指 → 单指」代理）、
  [glrenderd](docs/advanced/software/glrenderd.zh-CN.md)（在旧 Android 的 chroot 里跑更新的 GPU 驱动）、[mkbootimg-cooper](docs/advanced/software/mkbootimg-cooper.zh-CN.md)
  （打了 pagesize 补丁的 Donut mkbootimg）。

## 仓库布局

```
devices/<codename>/<release>/      device tree, drop-in for the AOSP vendor/ path
patches/<release>/                 diffs this port makes to pristine AOSP (+ files/ overlays)
docs/advanced/README.md            advanced documentation index
docs/advanced/porting-notes/       per-release playbooks (donut.md, kitkat.md)
docs/advanced/build/               per-release build guides (donut.md, kitkat.md)
docs/advanced/build-server.md      remote build-host runbook
docs/advanced/software/            project-made software (vtouch, glrenderd, mkbootimg-cooper)
docs/devices/<codename>/README.md  device main page: description, status, links
docs/devices/<codename>/quirks.md  device quirks: everything needed to port to it
scripts/                           build + packaging + device-tree sync (+ dump-maple-stock.sh, patch-maple-dtb.py)
containers/<release>/              period build-container recipes (kitkat/)
tools/                             project-made tools (mkbootimg-cooper, glrenderd sources)
reference/                         third-party trees/images kept for board parameters
```

不入 git（已被 gitignore）：`aosp-donut/`、`aosp-kitkat/`（可重新同步的 checkout）、`out/`（可刷写 zip 产物）、`work/`、`dumps/`（打包与设备导出草稿）。

## 构建

每个版本都有自己的端到端指南；README 保持简短：

- [为 cooper 构建 Donut 1.6](docs/advanced/build/donut.zh-CN.md) —— Hardy
  i386 chroot + JDK 5 + GCC 4.2.3；产出
  `out/full_cooper-1.6.DRD35-UNOFFICIAL-FULL-<date>.zip`。
- [为 maple 构建 KitKat 4.4.4](docs/advanced/build/kitkat.zh-CN.md) ——
  Trusty + JDK 6 容器、TWRP 导出的 4.4 内核、glrenderd；通过
  TWRP `dd` 刷入。
- 在远端主机上完成：见[构建服务器运行手册](docs/advanced/build-server.zh-CN.md)。

## 路线图

- [x] `cooper` 上的 Donut 1.6：启动到主屏，触摸屏 +
      扬声器音频可用（2026-10-12）。发布 zip 已上线。
- [ ] 完成 cooper：USB adb shell、SD/vold、WiFi（ath6kl 打通中）、
      相机 sensor 数据（需要内核 sensor 驱动，不是改 HAL）。
- [x] `maple` 上的 KitKat 4.4.4：带触摸、显示、
      USB adb 启动到桌面（2026 年 10 月）；Adreno 540 上的硬件 GL/GLES；面板
      显示输出；XZ1/poplar 稳定性 + GL 性能集（TEST 30–35）；
      全新镜像 GL 启动 + 守护进程崩溃/重启自愈（TEST 41）；
      lights HAL；wifi feature/supplicant 装配（TEST 36）。
- [ ] 完成 maple：WiFi 接口（SERVREG_LOC 现由树内
      `pdserve` 提供，PDR 链注册了它的 notifier；卡在 modem 根 PD 每 ~41 秒
      崩溃一次 —— modem 稳定性/保活未解）、
      蜂窝、相机、GPS、microSD；已记录偶发的用户空间之前
      启动挂死。
- [x] maple 音频：在 msm8998-tasha 声卡上可播放（音频 HAL
      `stop_threshold = INT_MAX`），卡顿打磨延后。
- [x] 把布局/脚本泛化为 `devices/<codename>/<release>/`
      （cooper/donut + maple/kitkat 共用一个同步脚本）。
- [x] `poplar`（同平台姊妹设备）上的 KitKat 4.4.4：启动到 Launcher +
      导航栏，触摸、显示、USB adb、经 glrenderd 的硬件 GL（2026 年 10 月，
      sherm 移植 —— 设备树已提交为 `devices/poplar/kitkat/`，早于 maple
      TEST 36-37）。
- [ ] 完成 poplar：把 `poplar` 加入 `scripts/sync-device-tree.sh`（树内已完成
      —— 待核实）、前移 maple TEST 36-37（wifi supplicant 服务、adsp
      启动、双节点 lights、`service_locator.enable=0`）、把 GPU 修复
      正式化进 `patches/kitkat/`。
- [x] `raphael`（Redmi K20 Pro）上的 Froyo 2.2：启动到 Launcher，全屏
      1080x2340（fbdev `yres` 已补丁为 `yres_virtual`）、USB CDC-ACM 串口
      shell + 带触摸控制的 `fbstreem`/`fbscreen` 实时镜像、由
      StatusBarService 注入的全局导航栏（返回/主页/最近）、
      已安装通讯录与浏览器。手机侧触摸只是部分可靠：goodix 固件
      在滑动中途偶发上报 `touch_num=0`，而 Froyo 的 protocol-A 解析器
      把它当成抬手。完整日志见
      `dumps/froyo-raphael/STATUS.md`（2026 年 10 月）。
- [ ] `raphael` 上的 Gingerbread 2.3：仅做了可行性验证 —— 通过 debootstrap 的
      64 位 Lucid chroot 与 AOSP 2.3.7_r1 的 `repo init` 都能跑通；
      源码同步、构建环境与设备树尚未开始。2026-10-18 暂停。
- [ ] 在新硬件上跑其它版本 —— 下一个是 Eclair（Gingerbread 到
      Nougat 已列入计划；Cupcake 不可能，源码已失）。

设备页及其怪癖日志承载全部细节与证据：
[cooper](docs/devices/cooper/README.zh-CN.md)、
[maple](docs/devices/maple/README.zh-CN.md)、
[poplar](docs/devices/poplar/README.zh-CN.md)。

## 许可与致谢

- AOSP 代码为 Apache 2.0；此处的 patches/overlay 属衍生物，沿用同一
  条款。
- `reference/android_device_samsung_cooper` —— LineageOS/CM
  （`gb-release-7.2`），Apache 2.0，保留用于抄板级参数。
- `reference/poplar-kitkat-gpu-fixes-2026-10-16.zip` —— 来自姊妹 XZ1
  （`poplar`）移植的完整 KitKat GPU/显示修复包（完整说明、
  补丁后的源码、参考二进制），保留用于 maple 的 glrenderd 工作。
- 厂商二进制（三星内核/模块/固件、Broadcom Atheros wifi
  固件；poplar 包内的参考二进制）保留以维持移植可构建，仍受其
  厂商原始许可约束 —— 它们**不**在以上 Apache 2.0 条款
  覆盖范围内。
- `android_device_sony_maple`（sony-msm8998，`ten`）+ `yoshino-common`
  （`BoardConfigPlatform.mk`，msm8998）—— 仅作参考，Apache 2.0；板级
  参数已提炼进 `devices/maple/kitkat/`，未提交 blob。
- `android_device_sony_poplar`（sony-msm8998，`ten`）—— 同上，已提炼进
  `devices/poplar/kitkat/`（sherm 移植）。
- 设备页上的设备照片来自 Wikimedia Commons，采用 CC BY-SA 许可（每页均注明出处）。
- `vtouch` 移植自 MLXProjects 的 Froyo 版 `vtouch` 1.2.0；`glrenderd`
  移植自 [chardidathing/pdx203-jellybean](https://github.com/chardidathing/pdx203-jellybean)。
