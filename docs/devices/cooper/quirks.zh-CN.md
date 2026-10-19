# cooper 怪癖（三星 Galaxy Ace GT-S5830/L/T）

> 中文译文。英文原文见 [quirks.md](quirks.md)。技术名词、代码、路径、命令与日志一律保留原文。

移植到 cooper 所需的全部内容：三星的 BML/FSR/STL 刷写栈、
内核配对、音频、触摸屏、recovery 交互，以及经过验证的
打通历史。状态、发布与链接在
[设备主页](README.zh-CN.md)；通用实战手册是
[Donut 移植笔记](../../advanced/porting-notes/donut.zh-CN.md)。覆盖
GT-S5830/L/T；基于 Broadcom 的 GT-S5830i（`cooperve`）是完全不同的
SoC，**不**在覆盖范围内。

## 平台特性

### 分区布局（三星 BML/stl，不是 MTD）
- `/dev/block/bml8` = boot（8 MB），`bml9` = recovery。`stl12/13/14` =
  system/data/cache。`BOARD_KERNEL_BASE 0x13600000`，pagesize 4096，
  `BOARD_BOOTIMAGE_PARTITION_SIZE 8388608`。
- **对 BML 的裸写不会生效**（没有擦除）并且静默失败 —— 实测验证
  （bml8 在一次「成功」的写入后仍是旧镜像）。始终用 cooper 的方式刷 boot：
  `/sbin/erase_image boot` + `/sbin/flash_image boot`
  （需要上面的 `run_program` 回移植）。**每次刷写都要验证**：回读并
  比对哈希；部分写入/损坏写入是会发生的。
- 参考板级参数在 LineageOS
  `android_device_samsung_cooper@gb-release-7.2`（BoardConfig、init.rc
  文件、keylayouts、vold.fstab、egl.cfg、预编译 zImage + fsr 模块）。

### FSR/STL 存储栈（最难的部分）
- cooper 的 NAND 需要三星专有模块：`fsr.ko`（BML）、
  `fsr_stl.ko`（STL）、`sec_param.ko`。没有它们内核只显示
  mmcblk（完全没有 bml/stl）。
- 模块集是与内核绑定的：CM 集（`2.6.35.7-perf-CL882825`）vs
  TWRP/Omni 集（`2.6.35.7-1203276`）vs 各内核（`-perf-CL882825` /
  `-androidarmv6+`）。要么匹配，要么用带 `CONFIG_MODULE_FORCE_LOAD` 的
  内核（`/proc/modules` 中显示 `(F)`）。`modinfo -F vermagic` 是准绳。
- STL 驱动在 insmod 时注册，但它的 `stl12/13/14` 磁盘（主设备号
  138，次设备号**稳定：12/13/14**）只有在用户空间主动扫描卷之后才出现
  （open + `BLKGETSIZE64` + 超级块区域读取 —— recovery 的分区扫描
  和 Gingerbread vold 就是这么做的）。Donut 从不扫描，所以 Donut 永远看不到 stl。
  我们的修法全部在 Donut init 内（`system/core/init/builtins.c`，
  钩在 `do_insmod_inner`）：fork 一个子进程去 insmod、扫描 BML 卷、
  轮询 `/proc/partitions`、mknod 节点（Donut 只在主循环里处理热插拔
  uevent，对挂载来说太晚了）、自己挂载 stl12/13/14、创建 data 目录，
  然后父进程直接执行 `class_start default`（服务记账正确；没有
  属性触发的竞态）。
- 原厂 RFS 分区**必须转成 ext4**（TWRP 擦除）—— Donut
  无法格式化它们。注意 TWRP 2.7.1 自己的擦除用的是 `mkdosfs`（vfat！）；
  要显式用 `make_ext4fs` 并用 `blkid` 确认。
- 实验前在 PC 上留一份已知可用的 `bml8` 备份。

### 内核
- CM 内核（`2.6.35.7-perf-CL882825`，在 CM 设备树里）+ CM 模块：
  可靠地启动到 adb；STL 需要上面的 init 侧打通。
- TWRP/Omni 内核（`2.6.35.7-androidarmv6+`，来自 bml9）+ TWRP 模块：
  打通路径完全相同；USB gadget 是 `android_usb`（在
  init.rc 里配置，否则没有 adb）。存储起来之后两个内核都能用；我们发布的是
  TWRP 那个 + TWRP 模块集（把 CM 集留在树内作后备）。

### 音频（可用，2026-10-12）
- 官方 Donut 的两条音频路径在 cooper 上都不可能工作：通用音频打开的是
  HTC-Dream 专属的 `/dev/eac`（不存在 → `initCheck` 失败 → *"Using stubbed
  audio hardware. No sound will be produced."*），而 Donut 的 `hardware/msm7k`
  音频需要专有的 HTC `libhtc_acoustic.so` 做端点发现 + audpp/audpre
  （不存在 → 同样落到 stub）。`/dev/msm_snd`、
  `/dev/msm_pcm_out`、`/dev/msm_pcm_ctl` 在 cooper 2.6.35 内核上**确实**存在
  （实测：对字符设备 `adb pull` 会以 `Invalid
  argument` 失败，而缺失节点会报 `does not exist`）；`/dev/snd/*`
  （ALSA）**不**存在（Donut 的 ueventd 从不创建它）。
- 修法，全在厂商树里：`devices/cooper/donut/libaudio/` —— Donut 的
  msm7k `AudioHardware` 去掉 acoustic 依赖。端点通过
  `/dev/msm_snd` 上的 `SND_GET_NUM_ENDPOINTS`/`SND_GET_ENDPOINT` 直接
  发现（与 CM7 cooper libaudio 用的同一条 ioctl 路径；实测发现
  20 个端点，`HANDSET=0 SPEAKER=6 BT=12 CURRENT=34`），失败时
  回落到 CM7 cooper 默认值；audpp/audpre 调音是空操作（纯
  PCM 依然能播）。`BoardConfig.mk` 不设 `BOARD_USES_GENERIC_AUDIO`，
  让 AudioFlinger 通过 `createAudioHardware()` 链接这个 `libaudio`
  （`TARGET_BOARD_PLATFORM := cooper` 把 `hardware/msm7k` 挡在
  构建之外，因此没有模块冲突）；`ueventd.gt-s5830.rc` 增加
  `0660 system audio` 条目，覆盖 `msm_snd`/`msm_pcm_out`/`msm_pcm_in`/
  `msm_pcm_ctl`（mediaserver 以 `media` + `audio` 组运行）。
- **32 字节 vs 40 字节陷阱（这一条导致过一次崩溃循环）：** Donut bionic 的
  `struct msm_audio_config` 是 32 字节，而 2.6.35 内核的是 40
  字节（`meta_field` + `bits` 在 `type` 之后，前五个字段偏移相同
  —— 对比 CM7 的 `msm_audio.h`）。把 Donut 的结构体传给
  `AUDIO_GET_CONFIG` 会让内核拷贝越过栈槽 8 字节：
  mediaserver 在 `MixerThread::threadLoop` 的
  `mOutput->write()` 调用点 SIGSEGV（故障地址 0；通过 tombstones +
  `arm-eabi-addr2line` 对 `out/.../symbols/...` 诊断）。修法是
  在每个 PCM GET/SET_CONFIG ioctl 中（输出与输入路径都用）
  改用 `cooper_msm_audio_config`（内核布局，`memset` + `type=PCM`，
  `meta_field=0`，`bits=16`）。已验证：端点 → "Routing audio to
  Speakerphone" → 音量 ioctl → 两个 mixer 线程就绪，无 tombstone，
  扬声器能听到铃声预览。

### 显示密度（160，不是 120）
- 最初发布的是 `ro.sf.lcd_density=120`（「接近 ldpi」的猜测）—— 一切都
  渲染得很小。framebuffer 对 320×480 报告 51×76 mm
  （约 159/160 dpi），其他所有 cooper ROM 也一致：CM7 的 `system.prop`
  写 120，但它的 `device_cooper.mk` 通过
  `PRODUCT_PROPERTY_OVERRIDES` 覆盖成 160，TWRP/Omni 的 `default.prop` 是 160。
  Ace 是约 165 dpi 的物理面板：**160（mdpi）才正确**。
  `devices/cooper/donut/system.prop` 现在把 `ro.sf.lcd_density`
  和 `qemu.sf.lcd_density` 都设为 160（在 `/system/build.prop` 中实测验证）。

### MLXProjects `android_device_mlx_test`（froyo 分支）审阅
- 同一类问题空间（旧 Android 跑新内核），但**没有音频
  方案**：它也用 `BOARD_USES_GENERIC_AUDIO`，其 TODO 写着
  "Enable sound using ALSA"（未完成）。只可作确认/参考：
  DPI 160、`TARGET_PROVIDES_INIT_RC`、mkbootimg pagesize 补丁
  （已等价于我们的 `mkbootimg-cooper`）、`lights/` + `gralloc.test`
  模式（不需要 —— Donut 忽略 `egl.cfg`，软件 `libagl`
  已经在驱动面板），以及 `vtouch`（已移植并
  做了 cooper 适配：显式 `/dev/input/event1`、type-A 组 → slot-0
  逻辑、HVGA 回落、`/dev/uinput` 自动创建、`cooper_vtouch`）。

### Recovery（TWRP 2.7.1.0 cooper）交互笔记
- TWRP 说的是 updater API **3**；Donut 的 updater 二进制只认 1/2
  （打补丁前一直报 "error executing updater binary"）。每个 zip 都需要一个
  真正的 ARM 静态 `update-binary`（Donut 会构建一个：`make updater`）。
- TWRP 自己的 Edify 与 Donut 的不同 —— 但真正运行的是*我们的*
  update-binary，所以脚本严格按 Donut 的 arity 写（见上）。
- `openrecoveryscript` 的自动执行在这里不可靠；sideload（Advanced →
  ADB Sideload → 滑动）或直接在 shell 里刷（`erase_image` /
  `flash_image`、`mount` + `unzip`、`make_ext4fs`）才是确定性的做法。
- `/tmp` 是 tmpfs（重启即消失）；主机 `/tmp` 也会被 OS 清理
  —— 把产物（备份、镜像、日志）留在项目树里。
- **手工 shell 刷写 vs 符号链接：** TWRP 的 busybox `unzip` 会把
  zip 里的符号链接条目写成微小的**文本文件**（与 Donut 的
  `package_extract_dir` 相同的 FILES_ONLY 行为）—— 包括*覆盖*在好的
  符号链接上，而且可能把 `/system/bin/toolbox` 本身留成 7 字节的文本文件。
  updater 路径不受影响（显式 `symlink()` 命令会 rm + relink）。手工刷写时：
  解压到临时目录，`cp -a` 覆盖 `/system`，然后按 updater-script
  重建全部 51 个链接（`cd /system/bin; rm -f <name>; ln -s
  toolbox|dumpstate <name>`），再修权限（目录 0755；`/system/bin/*` +
  `/system/xbin/*` 0755；`lib/`/`etc/`/`usr/`/`fonts/`/
  `media/` 下的一切 0644；`/system/xbin/su` 06755）。重启前用大小 + md5
  对照 chroot 树验证。
- **用裁剪回读验证 boot 刷写：** `bml8` 是 8 MB，但 `boot.img` 约 3 MB，
  所以整分区 md5 *永远*对不上。把
  `dd if=/dev/block/bml8 bs=<boot.img bytes> count=1` 与镜像比较。

### 设备现实（本移植已记录的局限）
- **无蜂窝网络**：MSM7227 没有 Donut RIL 库（rild 已移除）。
- **相机**：stub 换成了 `devices/cooper/donut/libcamera`
  （CooperCamera：尽力而为的 V4L2 `/dev/video0` YUYV 采集、测试图案
  兜底使 CameraService 永不崩溃、宽松的 setParameters、libjpeg 快照
  编码；`USE_CAMERA_STUB=false`）+ 移植的 `toggleshutter` +
  ueventd 的 `/dev/video0` 节点。真机验证：应用可打开、图案可预览、
  `registerBuffers`/`postBuffer` 显示路径可用（早期黑预览是一次手工
  recovery 安装后 `/system` 目录权限损坏的后果 —— 已修，见 recovery 笔记）。
  无实时 sensor 数据：S5K4ECGX 位于 MSM_CAMERA 栈上，而本内核
  关了 `CONFIG_MSM_CAMERA_V4L2`（不存在 `/dev/video*` 节点），它的专有
  `libseccamera` 栈也无法在 Donut 上链接 —— 真正的帧需要内核
  sensor 驱动项目，而不是改 HAL。
- **无 GPU 加速**：Donut 里没有 Adreno200 的 EGL（走软件 `libagl`
  路径）；预期是软件渲染 + 无硬件 overlay。
- **WiFi（AR6003）**：试过两套栈。(1) 老旧 `ar6000.ko`（CM7 构建，
  vermagic `-perf-CL882825`）：能强加载到随包发布的 `-androidarmv6+`
  内核上，但在切换 WiFi 时 PANIC（实测，无 last_kmsg）—— 用它时就让
  WiFi 保持关闭；留在树内只为可能的 CM 内核启动。
  (2) 主线 ath6kl + cfg80211/compat（OmniROM 构建，vermagic
  `-androidarmv6+` = 精确匹配）：insmod 干净，探测到 SDIO 卡并
  请求 `ath6k/AR6003/hw2.0/bdata.*`（已在 recovery 里用 dmesg 证明）；
  固件放在 `/system/etc/firmware`（= `/etc/firmware`，正是 Donut
  init 中 `devices.c` 的固件加载器查找处 —— recovery 没有固件
  helper，所以那一半只能在 Donut 启动时验证）。依赖在 `init.rc` 中
  预 insmod；WifiService 加载 ath6kl（BoardConfig 里的 `WIFI_DRIVER_*`）；
  supplicant 通过 cfg80211 的 wext 兼容层保持 `-Dwext`。BT（BCM）、
  FM、GPS：需要尚未集成的专有模块/库。
- **电源键**：在 keymaps 里修好 —— `sec_key.kl`/`sec_jack.kl`/`qwerty.kl`
  把扫描码 107+116 映射为 `ENDCALL WAKE_DROPPED`（Donut 的
  PhoneWindowManager 只对 ENDCALL 做休眠/唤醒/对话框；POWER 在 1.6 上是死
  代码）。真机验证：短按休眠，熄屏时按下唤醒。（107 是电源扫描码的
  现场证据：`sec_key` 的 KEY 位图解码出来正好是 102/107/114/115，
  且 EventHub 加载的是 `sec_key.kl`。）
- **HOME 键 / provisioning**：中心键（102 → HOME）能正常到达
  WindowManager，但从不回主屏 —— 在
  `launchHomeFromHotKey` 里被静默吞掉。根因：这个无 GMS 的移植从不对设备做 provisioning
  （树内唯一会写 `Settings.Secure device_provisioned` 的是 SetupWizard，
  而它不在树里），于是 `KeyguardViewMediator.
  isInputRestricted()` 永远为真，每次按 HOME 都被路由到
  永远不会完成的解锁验证（现场追踪：
  `isShowing=false inputRestricted=true`）。修法全为永久修复：
  `devices/cooper/donut/system.prop` 设 `keyguard.no_require_sim=true`
  （与 CM 对齐），并且 `DatabaseHelper.loadSecureSettings` 在全新数据库上
  播种 `DEVICE_PROVISIONED=1`（`INSERT OR IGNORE`，升级时安全；
  见 `patches/donut/frameworks-base.patch`）。真机验证：HOME 回主屏，
  锁屏行为正常。通过临时的 `interceptKeyTq`/`launchHome` Log.d 诊断，
  之后已回退（树内不留追踪代码）。
- **SD 卡**：待上面的 vold 加固；暂时不带 SD 启动。
- 实用建议：让电池真正有电（PC USB 在负载下喂不上；低压启动会产生
  幻影故障），并且绝不要在低于约 50% 时刷 boot。

## 状态（构建 + 打通历史）
功能矩阵：见[设备主页](README.zh-CN.md)。`aosp-donut/`
（Donut r2 + `devices/cooper/donut` 设备移植，含 cooper libaudio +
160 dpi）在 `/srv/donut-hardy`（Hardy chroot）里构建 `full_cooper-eng`；
`scripts/build-cooper-donut-full.py` 打包
`out/full_cooper-*-FULL-*.zip`（CWM/TWRP 可刷，BML 感知）。
**里程碑 2026-10-12：真机完整启动到 Donut 主屏，
触摸屏 + 电容按键可用**，显示走软件渲染、处于原厂 160 dpi，扬声器音频可用
（能听到铃声预览）。仍未完成：USB 上的
adb shell、SD/vold、蜂窝、WiFi/BT/GPS、相机 HAL —— 见下。

## 是什么让它启动起来（后半部分）

- **Zygote 崩溃循环**：`ZygoteInit.preloadClasses` 对专有的
  `com.google.common.*`/`com.google.masf.*` 条目抛出
  `IllegalStateException: Missing class(es) for preloading` —— 但只在
  `persist.service.adb.enable=1` 时（也就是每个 eng 构建！）。观察到
  61 次重启，load ~5，dex 零进展。修法：从
  `frameworks/base/preloaded-classes` 里剥掉这些条目（保留了两个可解析的
  protobuf 条目）。通过 tombstones 诊断（`/data/tombstones/tombstone_*` 用 adb sync
  拉取正常）+ `/dev/log/main` 拉取（logger 可用；用
  `strings` 解析）。
- **vold 崩溃循环**：外来 uevent 上 SIGSEGV（NULL devpath），10 个
  tombstones，外加 SD 卡上 `EEXIST` mknod 重试风暴，把一颗核占满并
  刷爆 logcat（469 KB）。当前修法：服务移除（SD 卡暂时不用）；正确的修法是
  之后加 NULL 防护 + 把 EEXIST 当成功。
- **rild 崩溃循环**（无专有 RIL 库）无限唤醒 get_macaddrs：
  把服务注释掉。
- **首次启动要 10–20 分钟**（800 MHz，32 个 APK 的 dexopt；盯
  `/data/dalvik-cache` 增长 + `packages.xml` 出现）。别把它当成
  挂死；但要查 `loadavg`（持续约 5 = 在干活，空闲 = 卡住）。
- **显示**：SurfaceFlinger 在进程内运行（不需要独立服务）；
  Donut 的 EGL 回落到软件 `libagl.so`（存在），因为 `libhgl.so
  ` 不存在 —— 不需要动 `egl.cfg`（Donut 忽略它）。通过
  `/dev/graphics/fb0` 拉取验证（双缓冲 320x480x4；全零 = 还没有东西在
  绘制，成千上万种颜色 = UI 活着）。
- **adb shell 卡住但 sync 可用**：Donut adbd 基于 pty 的 shell
  （`/dev/ptmx` + grantpt）在这里很脆弱；改成拆分管道
  （这个时代的 bionic **没有 `socketpair()`** —— 用两个 `pipe()` 并
  教会 poll 循环处理拆分后的 fd）。Shell 仍在调查中；
  期间用 `adb pull`（`/proc/*`、`/dev/log/*`、
  `/data/dalvik-cache`、tombstones）+ 设备上的 Terminal 应用诊断。

## 触摸屏（可用）
- 面板是 I2C 上的 Synaptics RMI4（`SYNAPTICS_I2C_RMI4=y`，探测正常：
  `max_x: 320, max_y: 480`，irq 模式）。但它**上报的是 protocol type-A
  （SYN_MT_REPORT 分组，X/Y/pressure/width），却声明没有任何 MT 轴**
  （`ABS=650000`：只有 HAT 位）—— 于是 Donut 把它归类为仅键盘，
  而 Donut（多指触摸之前）会丢弃每一个触摸事件。通过点击期间拉取
  `/dev/input/event1` 并解码 MT_POSITION_X/Y（53/54）验证。
-   修法，**零框架改动**：移植 MLXProjects 的 Froyo `vtouch`
  MT→ST uinput 代理（`devices/cooper/donut/vtouch/`，静态 ramdisk
  二进制 + `service vtouch /sbin/vtouch /dev/input/event1`）。cooper
  适配：显式路径强制 MT 模式（自动探测看不到这些
  能力位），type-A 分组 → slot-0 提交逻辑，HVGA 回落（驱动上报
  max 320/480），`/dev/uinput` 自动创建（c 10 223；内核有
  `CONFIG_INPUT_UINPUT=y` 但没有节点），设备重命名为 `cooper_vtouch`。
  EventHub 通过 inotify 以 `classes=0x5`（键盘 + 触摸屏）接收它。
- Keymaps：`VIRTUAL` 标志在 Donut 上不存在，且会**中止整个
  `.kl` 文件** → 在 `sec_touchscreen.kl` 里换成 `WAKE`；新增
  `cooper_vtouch.kl` 映射 MENU/BACK/HOME/SEARCH（BTN_TOUCH 不需要条目：
  Donut 按扫描码消费它，而且它不是合法的 Donut keycode 名）。
  缺 `.kcm.bin` 无碍（会回落；只影响文本输入）。
- 通过 `adb pull /dev/.vtouch.log` + 主日志缓冲里 EventHub 的 `New device`
  行诊断。
