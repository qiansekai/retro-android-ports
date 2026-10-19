# Sony Xperia XZ Premium G8141/G8142（`maple`）

> 中文译文。英文原文见 [README.md](README.md)。技术名词、代码、路径、命令与日志一律保留原文。

![Sony Xperia XZ Premium](device.jpg)

*图片来源：[Deoma12](https://commons.wikimedia.org/wiki/File:Xperia_XZ_Premium.png)，CC BY-SA 4.0，via Wikimedia Commons。*

XZ Premium 是 Sony 2017 年的旗舰，采用 Qualcomm 的 **Snapdragon 835
（MSM8998）**：4×2.45 + 4×1.9 GHz Kryo（ARM64）+ Adreno 540，4 GB RAM，
64 GB UFS，microSD，5.5 英寸 3840×2160 HDR 面板（日常使用按 1080p /
密度 410 渲染），USB-C。它出厂搭载 **Nougat 7.1.1**；
`maple` 是单卡版 G8141，`maple_dsds` 是双卡版 G8142。我们的移植
使其运行 **KitKat 4.4.4**（一个 32 位、2013 年的用户空间），以及晚近的
**Donut 1.6**（AOSP `android-1.6_r2`，DRD35）。

## 状态

### KitKat 4.4.4 — AOSP `android-4.4.4_r2`（KTU84Q）— 启动到 UI

| 方面 | 状态 |
| --- | --- |
| 启动 | 启动到桌面（`sys.boot_completed=1`，75 个 binder 服务），所有分区已挂载 |
| 桌面 / UI | 可用；持续动画 59.5–60.0 fps（libhyb，2026-10-19 实测 —— 软件绘制的 glrenderd 时代约为 26–35 fps） |
| 触摸 | 可用（Clearpad，全量程坐标，导航栏 + gpio 按键） |
| 显示 | 可用，1080×1920；`gralloc.maple` 是唯一的 fb0 翻转者（`fbpresentd` 原子提交 —— release fence 确认 DMA0 扫描输出 —— 另带 copy + `FBIOPUT_VSCREENINFO` 回退，2026-10-19 A/B 验证） |
| GPU | **Adreno 540 上的硬件 GL/GLES 3.2**，经 [libhyb](../../advanced/software/libhyb.zh-CN.md) —— 驱动在进程内运行（它取代了 glrenderd chroot；2026-10-18 构建，2026-10-19 真机验证：EGL 1.5、`Adreno (TM) 540`、UI 经 hwui 用 GL 绘制） |
| USB | adb 可用（configfs gadget，`18d1:4ee7`） |
| 灯光 | 亮度 + 休眠经移植的 lights HAL（两个 backlight 节点） |
| 存储 | 模拟内部存储可用（`/sdcard`）；microSD 仍未测试 |
| WiFi | feature + supplicant 服务已就位；驱动能加载但**没有 wlan0** —— locator（SERVREG_LOC）现由树内 `pdserve` 提供，PDR 链（icnss）也注册了它的 notifier，但 modem 根 PD 每约 41 秒崩溃一次，wlan_pd/WLFW 来不及启动；modem 稳定性（keepalive/rild）是未解的阻塞项。Taimen 的 64 位守护进程 chroot（`cnss-daemon`/WLFW）是参考路径 —— [对照](../../advanced/taimen-kitkat-mapping.zh-CN.md) |
| 音频 | **框架播放 + 采集可用，耳机/头戴路由已接通**（2026-10-19 验证：`AudioTrack` 的提示音可闻 —— 440 Hz 占 DMIC 回环采集频带能量的约 99 % —— 同一提示音经 `AudioRecord` 录回读数为 440.00 Hz；`dmesg` 显示每次流启动时都设置了校准）。ACDB 校准由 Android 15 的 `libacdbloader` 经 [libhyb](../../advanced/software/libhyb.zh-CN.md) 在 mediaserver 内推送；`/dev/msm_audio_cal` 以 `0660 media audio` 打开。HAL 遵循 AudioPolicyManager 的 `routing=`（speaker 15 / headphones 10，builtin mic 4 / headset mic 8），但内核没有暴露 `h2w` 开关，所以插孔路由不会自行触发，且 TX 校准已禁用（它会破坏 ADM 采集路径，只能靠重启恢复）—— [怪癖 TEST 50](quirks.zh-CN.md)/[TEST 51](quirks.zh-CN.md)，BT SCO 已知失效 |
| 蜂窝网络 | 本移植没有 RIL 库 —— 不可用 |
| 媒体播放 | **解码后的音频与视频播放可用**（2026-10-19 验证）：ogg/mp3 经 Music 的 AudioPreview 打开 HAL（`route out 0x2 -> speaker (acdb 15)`，拓扑 `112fc`），对 440 Hz mp3 做 DMIC 回环读数为 **440.00 Hz**；UI 点击音也能播。视频同理 —— Gallery 的 `MovieActivity` 播一段 320×240 h264+AAC 片段时创建 `OMX.google.h264.decoder`，全屏渲染测试图样，并把它的 880 Hz 音轨以 880.00 Hz 回录。这一切都需要 `media/media_codecs.xml`：镜像里没有 `/system/etc/media_codecs.xml`，于是 `MediaCodecList` 不返回任何 codec，`OMXCodec::Create` 静默失败（`SoundPool: onLoadSoundEffects(), Error -22`，`MediaPlayer: error (1, -2147483648)`）；WAV 能用只是因为 `audio/raw` 绕过了 OMX —— [怪癖 TEST 52](quirks.zh-CN.md) |
| 相机 / GPS / BT / 指纹 | 未开始（专有 HAL） |

### Donut 1.6 — AOSP `android-1.6_r2`（DRD35）— 启动到 UI

| 方面 | 状态 |
| --- | --- |
| 启动 | 启动到桌面（`sys.boot_completed=1`）；开机约 6.5 秒后触摸可用 |
| 桌面 / UI | 可用；竖屏方向（翻盖保护套的 lid 传感器不再强制横屏） |
| 触摸 | 可用（Clearpad，全量程坐标 0..2159 / 0..3839，vtouch 代理） |
| Keyguard | 点击解锁（「Tap to unlock.」）；相机键全按 → MENU |
| 相机键 | 半按 → BACK，全按 → MENU（WAKE_DROPPED）；音量键可用 |
| 显示 | 可用，1080×1920 软件 SurfaceFlinger（本移植没有 glrenderd） |
| 设置 | 打开不崩溃（键字符映射已修成 0644 模式） |
| USB | adb 可用（configfs gadget，`18d1:4ee7`） |
| 电源键 | 由内核的 `powerkey_handle` 处理（仅在 USB 未插入时锁屏）；见怪癖 TEST 47 |
| 音频 / WiFi / 蜂窝网络 / 相机 HAL | 未开始（专有 HAL；Donut 时代） |

已知的设备怪癖：偶发的**用户空间之前启动挂死**（卡在 Sony 开机画面，
**完全无 USB** —— 重新刷机前先用一次 TWRP 往返恢复）；keyguard 窗口把熄屏
限制在约 10 秒（官方 KitKat 行为，电源键可唤醒）；本移植里 `screencap`
返回固定图像（改为 dump fb0）。细节见 [怪癖](quirks.zh-CN.md)。

**版本发布：** maple 镜像在本地构建 —— 尚无公开 zip；见
[为 maple 构建 KitKat](../../advanced/build/kitkat.zh-CN.md)。cooper 的 zip
位于 [GitHub Releases](https://github.com/pukikiko/retro-android-ports/releases)。

## 文档与链接

- [**设备怪癖**](quirks.zh-CN.md) —— 硬件快照、分区布局、完整的
  TEST 1–49 打通日志、阻塞清单与已验证的修复。
- [KitKat 4.4.4 移植笔记](../../advanced/porting-notes/kitkat.zh-CN.md) ——
  本次移植产出的通用实战手册。
- [Donut 1.6 移植笔记](../../advanced/porting-notes/donut.zh-CN.md) ——
  通用实战手册（触摸握手、无 MENU 键的 keyguard、固件加载回退、键字符映射）。
- [为 maple 构建 KitKat](../../advanced/build/kitkat.zh-CN.md)。
- [为 maple 构建 Donut](../../advanced/build/donut.zh-CN.md) —— chroot 配方、
  补丁顺序、打包与刷机。
- [设备树（KitKat）](../../../devices/maple/kitkat/)
  （`devices/maple/kitkat/`）与 [补丁](../../../patches/kitkat/README.zh-CN.md)
  （`patches/kitkat/`）。
- [设备树（Donut）](../../../devices/maple/donut/)
  （`devices/maple/donut/`）与 [补丁](../../../patches/donut/README.zh-CN.md)
  （`patches/donut/`）。
- 此处用到的工具：[libhyb](../../advanced/software/libhyb.zh-CN.md)（KitKat：
  Adreno 540 驱动进程内运行 + `fbpresentd`；暂存工具在
  `tools/libhyb/`）、[vtouch](../../advanced/software/vtouch.zh-CN.md)。
