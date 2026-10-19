# 复古 Android 移植（Retro Android Ports）

> 中文译文。英文原文见 [README.md](README.md)。技术名词、代码、路径、命令与日志一律保留原文。

> **Fork。** 本 fork 在上游之上加入 Redmi K20 Pro（`raphael`）移植：
> KitKat 4.4.4（DRM PAGE_FLIP 显示）与 Froyo 2.2，GL 栈位于
> `tools/raphael/`。见 [FORK.md](FORK.md) 与 [docs/devices/raphael/README.md](docs/devices/raphael/README.md)。

在新硬件上运行远古 Android 版本。本项目把 **Donut 1.6 到 Nougat 7.1** 的 AOSP 移植到许多从未官方运行过这些版本的设备上 —— 并把每一条踩坑得来的经验提炼成可复用的实战手册，让下一个设备比上一个更省力。

目前已验证：

- **Android 1.6 Donut**（AOSP `android-1.6_r2`，DRD35）运行在 **三星 Galaxy Ace GT-S5830**（`cooper`，2011 年，MSM7227）—— 可启动，触摸屏（含电容按键）、出厂 160 dpi 显示、扬声器音频均可用。可刷写的 CWM/TWRP zip 见 [Releases](https://github.com/pukikiko/retro-android-ports/releases)。
- **Android 4.4.4 KitKat**（AOSP `android-4.4.4_r2`，KTU84Q）运行在 **Sony Xperia XZ Premium**（`maple`，2017 年，MSM8998）—— 启动到桌面，触摸、USB adb、Adreno 540 上的硬件 GL/GLES 3.2 均可用（先是经 glrenderd chroot，后改为进程内的 [libhyb](docs/advanced/software/libhyb.zh-CN.md) 栈 —— 2026-10-18 构建，2026-10-19 刷入并在真机上验证，59.5–60.0 fps）。

Cupcake 1.5 不在范围内：`platform/manifest` 已不再带 `cupcake`/`android-1.5` 分支（`android-1.6_r1` 是最老的），所以 Donut 是仍能同步的最老版本。完整故事 —— 以及为什么一台 2011 年跑 Froyo/Gingerbread 的手机才是真正的复古目标 —— 见 [Donut 移植笔记](docs/advanced/porting-notes/donut.zh-CN.md)。

## 支持设备

| 设备 | 代号 | 移植 | 状态 |
| --- | --- | --- | --- |
| Samsung Galaxy Ace GT-S5830/L/T | `cooper` | Donut 1.6 (DRD35) | 真机可启动；桌面、触摸屏 + 电容按键、160 dpi 显示、扬声器音频。蜂窝网络不可能（MSM7227 没有 Donut RIL）；相机预览只有测试图案。[设备页](docs/devices/cooper/README.zh-CN.md) |
| Sony Xperia XZ Premium G8141/G8142 | `maple` | KitKat 4.4.4 (KTU84Q) | 启动到 UI；触摸、显示、USB adb、硬件 GL/GLES 3.2（Adreno 540 经 libhyb 进程内运行，59–60 fps，2026-10-19 验证）、亮度/休眠、模拟存储、**经音频 HAL 的播放 + 采集 + 耳机/头戴路由**（ACDB 校准来自 Android 15 的 loader，经 libhyb 进程内运行；路由由 AudioPolicyManager 的 `routing=` 驱动；2026-10-19 验证；解出的 ogg/mp3 也能放 —— TEST 52，440 Hz mp3 经 DMIC 回环读回 440.00 Hz；视频同样能放：Gallery 走软件 h264，测试图案全屏渲染 + 880 Hz 音轨回环）。WiFi 接口仍未打通：SERVREG_LOC 现在由树内 `pdserve` 提供，PDR 链（icnss）也注册上了 notifier，但 modem 根 PD 每 ~41 秒崩溃一次，wlan_pd/WLFW 来不及启动（modem 稳定性/保活未解）。[设备页](docs/devices/maple/README.zh-CN.md) |
| Sony Xperia XZ Premium G8141/G8142 | `maple` | Donut 1.6 (DRD35) | 启动到桌面；触摸（约 6.5 秒后稳定，`vtouch` v1.2.0-maple3）、点击解锁键盘锁、相机半按 → BACK / 全按 → MENU、音量键、可读的按键字符映射（Settings 可用）、竖屏方向。尚无音频/WiFi/蜂窝/相机 HAL。[设备页](docs/devices/maple/README.zh-CN.md) |
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
  [libhyb](docs/advanced/software/libhyb.zh-CN.md)（在旧 Android 进程内跑更新的 GPU 驱动，KitKat 上的 Adreno 540）、[mkbootimg-cooper](docs/advanced/software/mkbootimg-cooper.zh-CN.md)
  （打了 pagesize 补丁的 Donut mkbootimg）。

## 仓库布局

```
devices/<codename>/<release>/      device tree, drop-in for the AOSP vendor/ path
patches/<release>/                 diffs this port makes to pristine AOSP (+ files/ overlays)
docs/advanced/README.md            advanced documentation index
docs/advanced/porting-notes/       per-release playbooks (donut.md, kitkat.md)
docs/advanced/build/               per-release build guides (donut.md, kitkat.md)
docs/advanced/build-server.md      remote build-host runbook
docs/advanced/software/            project-made software (vtouch, libhyb, mkbootimg-cooper)
docs/devices/<codename>/README.md  device main page: description, status, links
docs/devices/<codename>/quirks.md  device quirks: everything needed to port to it
scripts/                           build + packaging + device-tree sync (+ dump-maple-stock.sh, patch-maple-dtb.py)
containers/<release>/              period build-container recipes (kitkat/)
tools/                             project-made tools (mkbootimg-cooper, libhyb staging/closure)
reference/                         third-party trees/images kept for board parameters
```

不入 git（已被 gitignore）：`aosp-donut/`、`aosp-kitkat/`（可重新同步的 checkout）、`out/`（可刷写 zip 产物）、`work/`、`dumps/`（打包与设备导出草稿）。

## 构建

每个版本都有自己的端到端指南；README 保持简短：

- [为 cooper 构建 Donut 1.6](docs/advanced/build/donut.zh-CN.md) —— Hardy
  i386 chroot + JDK 5 + GCC 4.2.3；产出
  `out/full_cooper-1.6.DRD35-UNOFFICIAL-FULL-<date>.zip`。
- [为 maple 构建 KitKat 4.4.4](docs/advanced/build/kitkat.zh-CN.md) ——
  Trusty + JDK 6 容器、TWRP 导出的 4.4 内核、libhyb 闭包暂存；通过
  TWRP `dd` 刷入。
- 在远端主机上完成：见[构建服务器运行手册](docs/advanced/build-server.zh-CN.md)。

## 路线图

- [x] `cooper` 上的 Donut 1.6：启动到主屏，触摸屏 +
      扬声器音频可用（2026-10-12）。发布 zip 已上线。
- [x] `maple` 上的 Donut 1.6：启动到桌面，触摸可用（启动后约 6.5 秒起稳定，
      `vtouch` v1.2.0-maple3 把 firmware-class 超时设为 1 秒）、点击解锁
      键盘锁、相机半按 -> BACK / 全按 -> MENU、Settings/按键字符映射（0644）
      已修、音量键、竖屏方向（翻盖保护套的 lid sensor 不再强制横屏）。
      设备树在 `devices/maple/donut/`；怪癖见
      `docs/devices/maple/quirks.md`（TEST 43-48）。
- [ ] 完成 cooper：USB adb shell、SD/vold、WiFi（ath6kl 打通中）、
      相机 sensor 数据（需要内核 sensor 驱动，不是改 HAL）。
- [x] `maple` 上的 KitKat 4.4.4：带触摸、显示、
      USB adb 启动到桌面（2026 年 10 月）；Adreno 540 上的硬件 GL/GLES；面板
      显示输出；XZ1/poplar 稳定性 + GL 性能集（TEST 30–35）；
      全新镜像 GL 启动 + 守护进程崩溃/重启自愈（TEST 41）；
      lights HAL；wifi feature/supplicant 装配（TEST 36）。
- [x] maple 图形，第二套设计：glrenderd（chroot + GL socket）被
      [libhyb](docs/advanced/software/libhyb.zh-CN.md) 取代 —— Adreno 驱动在
      进程内运行，`fbpresentd` 经一次 MDSS atomic commit 呈现，glrenderd 的
      工具与补丁已删除。2026-10-18 构建；2026-10-19 刷入并在
      **真机上验证**（冷启动 + md5 回读：Adreno 540 上的 EGL 1.5、
      59.5–60.0 fps、scanout fence 正常发出信号、copy 路径 A/B 干净 ——
      检查清单在 libhyb 的说明里）。
- [ ] 完成 maple：WiFi 接口（SERVREG_LOC 现由树内
      `pdserve` 提供，PDR 链注册了它的 notifier；卡在 modem 根 PD 每 ~41 秒
      崩溃一次 —— modem 稳定性/保活未解，缺的用户空间那一半是
      `cnss-daemon`/WLFW，按子系统映射见
      [Taimen daemon-chroot 评估](docs/advanced/taimen-kitkat-mapping.zh-CN.md)）、
      蜂窝、相机、GPS、microSD；已记录偶发的用户空间之前
      启动挂死。
- [x] maple 音频：**经框架的播放与采集都能工作**
      （2026-10-19）。Android 15 的 `libacdbloader` 经 libhyb 跑在 mediaserver 里，
      HAL 会声明设备的 acdb id，并在 route/`pcm_open`
      （`acdb_stream_cal`）之前加载匹配的块；yoshino 的 acdbdata
      按 `MTP` 暂存（即 `/sys/devices/soc0/hw_platform` 报告的名字），
      `pcm_write`/`pcm_read` 现在传的是字节而不是帧。AudioTrack 的 440 Hz
      音调可闻，约为 DMIC 回环频带能量的 99 %；同一音调经 AudioRecord
      （新增的 `audiorecord_test`）录回读到 440.00 Hz。HAL 会遵循
      AudioPolicyManager 的 `routing=` —— speaker 15 /
      headphones 10（RX 校准与音频流已验证）、builtin mic 4 / headset mic
      8 —— 但内核没有暴露 `h2w` 开关，所以插孔路由永远不会自己
      触发；TX 校准是刻意关闭的（loader 接受它，但 ADM 之后会拒绝每一次采集
      prepare，直到重启）；怪癖 TEST 50/TEST 51。BT SCO 已知不可用。
- [x] 把布局/脚本泛化为 `devices/<codename>/<release>/`
      （cooper/donut + maple/kitkat 共用一个同步脚本）。
- [x] `poplar`（同平台姊妹设备）上的 KitKat 4.4.4：启动到 Launcher +
      导航栏，触摸、显示、USB adb、经 glrenderd 的硬件 GL（2026 年 10 月，
      sherm 移植 —— 设备树已提交为 `devices/poplar/kitkat/`，早于 maple
      TEST 36-37）。
- [x] maple 媒体解码（TEST 52）：镜像里缺了
      `/system/etc/media_codecs.xml`，于是 `MediaCodecList` 返回空编解码器列表，
      所有压缩格式都失败（ogg/mp3 系统音、铃声、
      音乐；WAV 能放只因为 `audio/raw` 绕过了 OMX）。现在从
      `devices/maple/kitkat/media/media_codecs.xml` 发出，并已于
      2026-10-19 验证：Music 经带校准的 HAL 播放 mp3/ogg，440 Hz mp3 的 DMIC
      回环读到 440.00 Hz，UI 点击音可闻。
- [x] maple 视频解码（2026-10-19）：软件 h264/vpx/mpeg4 解码器
      随同一份 `media_codecs.xml` 到位。Gallery 的 `MovieActivity`
      播放一段 320×240 h264+AAC 片段时创建 `OMX.google.h264.decoder`，
      把测试图案全屏渲染（`MEDIA_INFO_VIDEO_RENDERING_START`，
      在既有显示路径上做 GL 合成），并把 880 Hz
      音轨以 880.00 Hz 回环放音 —— 怪癖 TEST 52。
- [ ] maple 音频残留项：内核里要一个 `h2w` 式插孔开关（
      tasha codec 只注册了 `hdmi`/`lid`/`sim_detect`），这样
      `WiredAccessoryManager` 就能自行路由耳机/头戴麦克风；还要针对
      ADM 拓扑不匹配（让 TX 校准污染采集，`copp_idx:-131`）给出
      修复或绕过方案；BT SCO 仍已知不可用
      （CHARQUIRKS）。
- [ ] 完成 poplar：把 `poplar` 加入 `scripts/sync-device-tree.sh`（树内已完成
      —— 待核实）、前移 maple TEST 36-37（wifi supplicant 服务、adsp
      启动、双节点 lights、`service_locator.enable=0`）、把 GPU 修复
      正式化进 `patches/kitkat/`，并把
      [libhyb](docs/advanced/software/libhyb.zh-CN.md) 栈移植过去（poplar 仍在构建
      已删除的 glrenderd 设计，见其 README）。
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
  补丁后的源码、参考二进制），保留用于 poplar 移植；maple 自己的 GL 路径
  此后已迁到 libhyb。
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
- `vtouch` 移植自 MLXProjects 的 Froyo 版 `vtouch` 1.2.0；`libhyb`
  移植自 [DoomGuy41/Taimen-KitKat](https://github.com/DoomGuy41/Taimen-KitKat)
  （已退役的 glrenderd 移植自
  [chardidathing/pdx203-jellybean](https://github.com/chardidathing/pdx203-jellybean)；
  其源码仍留在 git 历史中）。
