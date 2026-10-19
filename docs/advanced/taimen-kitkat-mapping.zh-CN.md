# Taimen-KitKat 对照（Pixel 2 XL 移植 → maple KitKat）

> 中文译文。英文原文见 [taimen-kitkat-mapping.md](taimen-kitkat-mapping.md)。技术名词、代码、路径、命令与日志一律保留原文。

参考笔记：[DoomGuy41/Taimen-KitKat](https://github.com/DoomGuy41/Taimen-KitKat)
（Pixel 2 XL / `taimen`，MSM8998，KitKat 4.4.4 跑在官方原厂 Android 11
内核 + `/system/v11` 里一套 64 位 Android 11 closure 之上）如何对映到
maple/KitKat。阅读并移植于 2026-10-18。图形核心 —— 进程内 Adreno 540 驱动的
libhyb、QTI gralloc1 之上的 KitKat gralloc、64 位 `fbpresentd` ——
已针对 maple 的 LineageOS 22.1 closure 完成移植与重写：
[libhyb](software/libhyb.zh-CN.md)，构建证据见
[maple 怪癖](../devices/maple/quirks.zh-CN.md) TEST 49。本页是
*其余一切*的处置：他们的补丁集（已采用、已跳过、
已排队）以及他们的设备树实现 ——
[Android 11 daemon chroot 与 HAL 桥接层](#daemon-chroot-与-hal-桥接层已评估未移植)，
下文评估其对 maple 的适用性。通用教训：
[KitKat 移植笔记](porting-notes/kitkat.zh-CN.md)。
返回 [advanced 索引](README.zh-CN.md)。

## 已采用（`patches/kitkat/`）

| Taimen 补丁 | 我们的 | 理由 |
| --- | --- | --- |
| `system/core/0003-liblog-fall-back-to-dev-kmsg` | `system-core-liblog-kmsg-fallback.patch` | 4.4 内核没有 `CONFIG_LOGGER`；缺了它，树里每个 `ALOG*`（以及 libhyb 载入的库里那些，它们把 `liblog.so` 解析到 KitKat 的版本）全是隐形的 |
| `system/core/0004-liblog-terminate-dev-kmsg-records` | `system-core-liblog-kmsg-terminator.patch` | 内核拼接记录时不带结尾的 `\n` |
| `system/core/0007-fs_mgr-clear-the-ext4-project-quota-feature` | `system-core-fsmgr-ext4-project-quota.patch` | LineageOS 的 mke2fs 在 slot B 上会设 `RO_COMPAT_PROJECT`；4.4 内核拒绝挂载 `/data` |
| `system/core/0008-elapsedRealtime-on-CLOCK_BOOTTIME` | `system-core-elapsedrealtime-boottime.patch` | 没有 `/dev/alarm`；顺带修好了被截断的 1 KiB 内核 cmdline 读取（maple 的更长） |
| `dalvik/0001` + `art/0001`（不用 `/dev/alarm` 的时间、capset） | `dalvik-zygote-capset-v3.patch`（+ `frameworks-base-time-without-dev-alarm.patch`） | `capset` ABI v3，好让 `system_server` 为 timerfd alarm 保住 `CAP_WAKE_ALARM`/`CAP_BLOCK_SUSPEND`；这里只有 Dalvik 那一半生效（KitKat 的默认运行时） |
| `frameworks/base/0001-SystemUI-canvas-wallpaper` | `frameworks-base-systemui-wallpaper-canvas-fallback.patch` | 我们在 glrenderd 打通期间已独立收敛到同一方案；当 EGL 没有 ES2 config 时它仍是安全网 |
| `frameworks/base/0002-SystemServer-config.disable_atlas` | `frameworks-base-disable-atlas.patch` | 资源图集的那个 Lollipop 期总开关，它假定有 GPU，建不出来时会搞死 `system_server` |
| `frameworks/base/0003-hwui-cap-the-reported-GL-version-at-2.0` | `frameworks-base-hwui-gles2-cap.patch` | 驱动对外宣称 ES 3.2；KitKat 的 hwui 只在 ES2 行为下被测过 |
| `frameworks/base/0004-Time-and-alarms-without-dev-alarm` | `frameworks-base-time-without-dev-alarm.patch` | `AlarmManagerService` 建在 `*_ALARM` timerfd + `settimeofday` 之上 |
| `packages/apps/Settings/0001-kernel-version-for-a-kernel-built-with-clang` | `packages-apps-settings-kernel-version.patch` | `/proc/version` 里是 clang 构建的内核；官方原厂那个只认 GCC 的正则显示 "Unknown" |
| `hardware/libhardware/0001-gralloc-framebuffer-stride` | `hardware-libhardware-gralloc-fb-stride.patch` | 这一条我们也独立有（mdss 把 1080 补齐到 1088） |
| `frameworks/native/0001`（binder 那一半） | `bionic-binder-uapi-64bit.patch` + `frameworks-native-binder-64bit.patch` | 他们把本仓库记为其出处 |
| `frameworks/native/0002-EGL-use-the-hardware-driver` | *无补丁* | 它删掉的正是 `frameworks/native/0001` 为他们 glrenderd 时期加进去的东西；终点就是官方原厂 KitKat 的 `checkGlesEmulationStatus`（删掉我们的 glrenderd EGL 补丁就是这次移植的全部） |

## 已跳过及其原因

| Taimen 补丁 | 为什么不在这里 |
| --- | --- |
| `art/0001`（第二份拷贝） | maple 跑 Dalvik；capset/时间修复的 ART 孪生是死代码 |
| `system/core/0005-0006 fs_config ... chroot` | chroot 设计已经不存在了（对 maple 的 libhyb 也并不需要：`/system/a15` 下没有任何东西被执行，`fbpresentd` 只是一个静态二进制） |
| `build/0001-definitions.mk sort (make 3.82)` | 我们的容器钉在 **Make 3.81**，也就是该发行版有文档记录的版本要求 —— 没有理由为一个更新的宿主 make 去改构建系统 |
| `build/0002-signed-release-keys` | 我们构建 `full_maple-eng` 并手工刷机；没有发布签名流水线 |
| `external/chromium_org WebKit (idl_serializer, rule_bison)` | 针对 Bison 3 / Perl 5.36 的宿主工具修复；Trusty 容器里的工具就是那个年代的，不打补丁也编得过 |
| `frameworks/av HEVC` + `frameworks/native OMX HEVC` | 媒体特性；maple 还没有可用的视频栈（不在范围内） |
| `hardware/ril`（4 个补丁：AT+GSN、radio 关闭时无 SIM、持久化 SIM 状态） | maple 上蜂窝没启动；等启动时这些是*候选*，但其背后的 modem 行为必须在 yoshino 固件上重新验证，不能假定 |
| `system/core/0001-0002 (servicemanager/ueventd/healthd not critical)` | 在起不来的树上做打通时的权宜；maple 的启动已经过了那个点，而把核心服务标成非关键会掩盖真实故障 |
| `frameworks/base/0005 bootanimation trim.txt + background colour` | 只有配 Lollipop+ 的开机动画才用得上；maple 发的是 KitKat 的 `bootanimation.zip`（哪天要发一套现代版再采用） |
| `hardware/libhardware_legacy/0001 vibrator LED fallback` | 需要在设备上确认 maple 的 4.4 内核暴露的是哪个接口（`/sys/class/timed_output` 还是 `/sys/class/leds/vibrator`）；已排队，未验证 |
| `hardware/libhardware_legacy/0002 wifi_load_driver waits for wlan0` | 与 maple 的失败模式吻合（WLFW 握手从不跑，所以没有 `wlan0`），但干等 30 秒只是把它藏起来；等 modem/wifi 链路真正起来再采用（见怪癖） |

## 有意做成不同

- **Closure 版本。** Taimen 从
  `/system/a11` 载入一套 32 位 Android 11 closure（`hyb/linker.c: s_root`）；maple 从
  `/system/a15` 载入 **LineageOS 22.1（Android 15）** —— 同一套设计，依赖集更宽、
  flat-log/apex 布局不同。Taimen 的移植也是更宽的形态：
  除 libhyb 之外它还跑一套 64 位 Android 11 chroot（`/system/v11`）
  供 modem/GNSS/传感器守护进程使用，maple 还没跑 —— 见
  [下文](#daemon-chroot-与-hal-桥接层已评估未移植) ——
  所以这里只移植了进程内那一半。
- **`rtc-restore` 是 C 二进制，不是 busybox 脚本。** Taimen 的
  `rtc-restore.sh` 读 `/sys/class/rtc/rtc0/since_epoch` 再加上
  `system_server` 存下的偏移，然后调 `busybox date -s @N`；maple 的 ramdisk
  没有 busybox，所以 `devices/maple/kitkat/rtc-restore/` 用 C 里的 `settimeofday`
  干同样的活（并写出与 frameworks 补丁相同的
  `/data/system/time/rtc_offset` 文件）。
- **`TARGET_BOARD_PLATFORM`/`TARGET_SYSTEM_PROP`/`egl.cfg` 布局**都跟随
  maple 树（`gralloc.maple`、`BOARD_EGL_CFG := vendor/sony/maple/egl.cfg`），
  而 MDSS 结构体取自 **maple 转储的内核头文件**，
  不是 Taimen 的。两边都开了 `hwui`（`USE_OPENGL_RENDERER := true`）；
  Taimen 额外设了 `TARGET_DISABLE_TRIPLE_BUFFERING := true`，
  maple 没设（候选调优项，需要实测）。

## daemon chroot 与 HAL 桥接层（已评估，未移植）

他们第二套设备树实现是一套 64 位 Android 11 chroot，
`/system/v11`，跑高通的各个守护进程（modem、wifi、传感器、
GNSS、NFC），每个 KitKat HAL 配一个小的桥接层。它是代码而不是补丁，
所以不在上面的表里；2026-10-18 基于我们自己的
转储为 maple 做了评估（静态证据 —— 没有 maple 设备在手）。

### 设计如何运作

- **chroot 的根就是一个目录，当作目录来发。**
  `scripts/extract-blobs.sh` 从工厂镜像里填 `vendor/google/taimen/v11/root`
  （64 位 bionic + `linker64`、`/vendor/bin` 里的守护进程
  及其 `/vendor/lib64` closure，约 160 个文件），再由
  `taimen_v11_chroot` 模块用 `LOCAL_POST_INSTALL_CMD := rm -rf $(TARGET_OUT)/v11 && cp -a .../v11 $(TARGET_OUT)/v11` 发出。关键就在
  `cp -a`：它能带上空目录和*绝对*符号链接（`rfs/` 里全是），
  而这些 `PRODUCT_COPY_FILES` 做不到。
- **`native/hwchroot.c`**（2 KB，静态）负责进入：`unshare(CLONE_NEWNS)`
  + 把 `/` 设为 private，把 `/dev`、`/proc`、`/sys` 整个 bind 进
  根里，`chroot`，用干净的环境 `execve`（`HOME=/`、
  `LD_LIBRARY_PATH=/vendor/lib/egl:/vendor/lib:/system/lib:/vendor/lib64/egl:/vendor/lib64:/system/lib64`），
  并且*不*传 KitKat 的 `ANDROID_PROPERTY_WORKSPACE`。KitKat 的
  `toolbox` 没有 `chroot`，它的 `mount` 不会 bind mount，所以才要这个
  小工具。里面没有 binder 节点：chroot 里没有 HIDL。
- **那些守护进程**：`rmt_storage`（modem EFS）、`tftp_server`（把
  modem 分区供给 PIL）、`pd-mapper`（SERVREG_LOC）、`cnss-daemon`
  （WLAN/WLFW）、`irsc_util`（从 `/vendor/etc/sec_config` 读取 IPC-router
  安全规则 —— *没有它们，非 root 的 QMI 客户端会挂死*）。
- **启动顺序**（`v11.sh`，由 KitKat init 拉起）：从
  `/sys/class/block/*/uevent`（`PARTNAME=`）合成
  `/dev/block/bootdevice/by-name/*` 链接 → 挂上 vfat 的 modem
  分区，把它 bind 到 `/firmware` → 从 `version.cfg` 设置 `gsm.version.baseband` →
  bind `/persist` 和 `/data/v11data` → `irsc_util` →
  等 rmt/tftp → *仅在 modem 启动期间*指向 `firmware_class.path` →
  打开并持有 `/dev/subsys_modem` → insmod `wlan.ko` → 等
  `wlan0` → `exec sleep inf`（保住那个 modem fd）。
- **`pm_shim.c`** 发一个替代的 `libperipheral_client.so`，它
  一律回答「online」：`cnss-daemon` 会经 vndbinder 向 pm-service 问
  电源状态，而 KitKat 上根本没有 vndbinder。
- **`logdw.c`**（32 位静态）bind `/dev/socket/logdw`，只把
  *警告与错误* 拷到 `/dev/kmsg` —— Android 8+ 的 liblog 会写那里，
  否则 `tftp_server` 会把内核缓冲刷爆。
- **桥接层是 HAL 库，不是 HIDL 服务。** 每个桥接层跑在
  chroot 里，在进程内 `dlopen` vendor 的 HAL *库*，再经一个抽象
  `AF_UNIX` `SOCK_STREAM` 套接字把它重新发布成一个小号的 KitKat HAL；
  协议是手写的定宽字段
  （32 位与 64 位进程里布局一致），每个桥接层一个头文件
  （`sensorbridge.h`、`gnssbridge.h`、`nfcbridge.h`）。版本差异
  在桥接层里翻译，因为那里两边都看得见：NFC 是 NCI 2.0→1.0，
  相机是 HAL3 3.5→3.0。
- **用 NDK r21e 在树外构建**（`scripts/build-native.sh`）：
  64 位静态小工具、对着 chroot 的 bionic 构建的 64 位守护进程/桥接层、
  32 位静态的 `logdw`，再加上给 init 脚本用的 `busybox-static`（armhf）。

### maple 这一侧：现有什么、移植会复用哪些

maple 是同一 SoC 家族（msm8998；cherokee WCN3990 wifi/BT、PN553
NFC），而我们为 libhyb 已经解开的那份转储 —— **LineageOS 22.1 自带的
maple vendor 镜像** —— 里那些守护进程就是 64 位 aarch64 ELF，
`interpreter /system/bin/linker64`（针对 Android 28/30 的 bionic 构建）：
`cnss-daemon`、`pd-mapper`、`rmt_storage`、`tftp_server`、`irsc_util`、
`sensors.qti`、`loc_launcher`、`lowi-server`、`hci_qcomm_init`，外加下面这些
HAL 库（2026-10-18 对着转储核对过）。

| 子系统 | 他们那部分 | maple 现状 | 移植需要什么 |
| --- | --- | --- | --- |
| SERVREG_LOC | chroot 里的 `pd-mapper` | **`pdserve`**，树内 32 位、经 `AF_MSM_IPC` 实现 SERVREG_LOC（TEST 40） | 无需 —— 保留 `pdserve`；`pd-mapper` 已被取代 |
| Modem 固件交给 PIL | `tftp_server` + 指向 modem 分区的 `firmware_class.path` | 固件由 `maple-fw/{modem,adsp,wlan}` 暂存进 `/vendor/firmware`；`modem-hold.sh` 持有 `/dev/subsys_modem`（TEST 38/39） | 无需 —— 而且 `tftp_server` 直接链 `libqrtr.so`，所以它留在外面；走暂存这条路 |
| Modem EFS | `rmt_storage` + 那四个 by-name 节点 | 无；modem 的根 PD 每约 41 秒崩一次（TEST 36） | 在实时 GPT 上确认 `fsg`/`fsc`/`modemst1`/`modemst2`，创建 `/dev/block/bootdevice/by-name` 链接（我们的在 `platform/soc` 下），再从 chroot 里跑 `rmt_storage`。对崩溃循环的一个候选解释 —— 待验证 |
| IPC-router 安全 | `irsc_util` + `/vendor/etc/sec_config` | 目前只有 root QMI 客户端（`pdserve`） | 在任何非 root 守护进程之前装好规则；`sec_config` 随 maple 的 vendor 一起发 |
| WLAN | `cnss-daemon` + pm shim + 等 `wlan.ko` | `CONFIG_QCA_CLD_WLAN=y`（内建）+ `icnss`；BDF/校准已暂存；supplicant 服务就位；**没有 `wlan0`** —— WLFW 握手从不跑 | 从 chroot 跑 `cnss-daemon`（WLFW 的 QMI 客户端）+ pm shim + logdw；modem 必须保持起来（WLFW 是 modem 服务）。maple wifi 的明确下一步 |
| 传感器 | SLPI 启动 + `sensors.qcom` + `sensorbridge` | SLPI 在 DTB 里（`pil_slpi_region@94300000`）；vendor 里有 `sensors@1.0-service` + impl + `sensors.qti`（`libsensor1`） | 启动 SLPI（`/sys/kernel/boot_slpi/boot`），在桥接层里 dlopen `lib64/hw/android.hardware.sensors@1.0-impl.so` —— 同样的套路，Android 15 的库 |
| GNSS | `gnssbridge`：经 `libqmi_cci` 的裸 QMI LOC | 无；卡在 modem 稳定性上 | 同样的桥接层形态；maple 的 vendor 里有 `gnss@2.1-service-qti`、`vendor.qti.gnss@4.0-impl.so`、`libgnss.so` |
| NFC | `nfcbridge` + `nfc_nci_nxp.so` | 内核 `nxp,pn553` + `qcom,nq-nci`（`CONFIG_NFC_PN553_DEVICES=y`）；vendor 里有**同一个** `nfc_nci_nxp.so` | 图形之后保真度最高的移植：同一颗控制器、同样的 HAL 文件名；要取它的 `-rdynamic` 符号覆盖和 NCI 2.0→1.0 翻译 |
| 蓝牙 | 为 WCN3990 定制的 `libbt-vendor`：波特率脉冲上电、EDL 固件下载、3.2→3 Mbps 改写、关掉 IBS | 无；`crbtfw*.tlv`/`crnv*.bin`（cherokee）已暂存在服务器上；内核 DT 里有 `qca,bt-vdd-*` 供电；vendor 里有 `hci_qcomm_init` + `libbtnv.so` | 针对 maple 的 UART/GPIO 和固件名移植 `btinit.c` —— 同一颗芯片家族 |
| 音频 PD | 不属于他们的 chroot（那边音频本来就能用） | **播放 + 采集可用**（2026-10-19，TEST 50/51）：Android 15 的 ACDB loader 经 **libhyb** 在 mediaserver 里运行，把 yoshino 的校准推进 `/dev/msm_audio_cal`；不需要 `adsprpcd` —— q6 驱动缺的只是 cal 块。HAL 遵循 AudioPolicyManager 的 `routing=`（扬声器 15 / 耳机 10，内置麦克风 4 / 耳麦麦克风 8），但内核没有自动插孔检测用的 `h2w` 开关，且 TX 校准被禁用（loader 收下了，之后 ADM 直到重启都拒绝每一次采集 prepare） | 从 maple 的 vendor 经 `/dev/adsprpc-smd` 跑 `adsprpcd` 是 vendor 的路子，与本设计无关 |
| 相机 / 视频 | `camera.taimen`（HAL3 3.5→3.0）、`libstagefrighthw` + HEVC | 无；索尼的相机 provider，不同的传感器 | 只借套路 —— HAL 层不可迁移（见实战笔记） |
| 开机打标 / 温控 | `bootmark`（A/B 重试计数器）、`thermal-compat.sh`（PVC 温区） | 单 slot，没有 Pixel Visual Core | 不适用 |

### 对早前 maple 结论的更正

2026-10-16 的一则笔记（[maple 怪癖](../devices/maple/quirks.zh-CN.md) TEST 36）
从 QRTR 缺失推得「没有任何现代 QMI userspace（pd-mapper、
cnss-daemon、rmt_storage、tftp_server）能跑在这个内核上，管你 chroot 不
chroot」，并认为 chroot 被挡住是因为「哪儿都找不到 `linker64`」。
内核那一半成立 —— 确实没有 `CONFIG_QRTR` —— 但
userspace 那一半说得太满，而且当时的检查看错了
地方：

- **`libqmi_cci` 是双传输的。** 对 maple 的 Lineage 22.1
  vendor `libqmi_cci.so` 跑 `strings`，能看到 `qcci_ipc_router_ops` *和*
  `qcci_qrtr_ops`，并带一次运行时探测（"QRTR NOT SUPPORTED" / "QRTR
  SUPPORTED"）；`cnss-daemon`、`pd-mapper` 和 `sensors.qti` 都链它，
  而 `rmt_storage` 链的是服务端的 `libqmi_csi.so`，那个也是
  双的（`qcsi_ipc_router_ops` + `qcsi_qrtr_ops`）。在没有 QRTR 的内核上，
  客户端应当回退到遗留的
  IPC-router 传输 —— 也就是 `pdserve` 已经在用的 `AF_MSM_IPC` 路径
  （TEST 40）。要在设备上验证。
- **`linker64` 就在转储里。** 早前的检查看的是手机上的实时
  挂载点（那里 apex 是分开的）；Lineage 系统镜像
  里有一个真的 `system/bin/bootstrap/linker64`（2,188,552 B，aarch64
  ELF），而 `tools/libhyb/extract-lineage.sh` 已经为 32 位 closure
  做了 runtime apex 的 de-apex —— 64 位那一侧就是同一个循环
  再加上 `lib64`。
- **任何直接链 `libqrtr.so` 的东西**仍然不行 ——
  `tftp_server`（NEEDED `libqrtr.so`，已验证）、`qrtr-ns`、
  `qrtr-cfg`、`qrtr-lookup`；兜底能力在
  `libqmi_cci`/`libqmi_csi` 里，不在内核里。
- 只有设备能回答的：遗留路径能否完成
  WLFW 握手并把 `wlan0` 拉起来。

### 值得带过来的实战笔记

- **传感器。** KitKat 在启用传感器之前会先 flush 它，而
  高通的 HAL 拒绝 flush 一个未激活的传感器 —— KitKat 侧的
  HAL 自己合成「flush complete」。每个 KitKat 类型只暴露一个传感器
  （优先非 wake-up），步数来自 IMU 的硬件计步器，
  并且桥接层重启时 KitKat HAL 会重放自己的状态。
- **GPS。** QMI LOC 的状态字段没法用 —— 只要 SNR 有效就把该卫星
  算作已跟踪。XTRA 来自 KitKat 的
  `GpsLocationProvider`（经 `gps.conf`），按 1 KiB 分片注入；
  QMI 服务对象的那些值取自 `libloc_api_v02.so`（maple 的
  vendor 里有自己的一份）。
- **NFC。** NXP 的库会经 HIDL 找安全元件，那会永远
  等 `hwservicemanager`；桥接层导出自己的
  `getRawServiceInternal`（`-rdynamic`），以压过 libhidlbase 的那个。
  `CORE_RESET`/`CORE_INIT` 做 2.0→1.0 翻译，并由
  `libnfc-brcm.conf` 关掉安全元件和 P2P 监听。
- **相机，如果这里真的起来了。** 他们那份 HAL3 3.5→3.0 的记录是
  值得不要重新发现的版本差异知识：metadata 按
  tag *名字* 匹配（11 删掉了两个 section）、静态限制从
  `availableStreamConfigurations` 重建、vendor tag 经
  `set_camera_metadata_vendor_ops`、部分设置合并进
  HAL 的模板、session 参数是必需的、结果合并后按
  快门之后每帧投递一份、成对的 `camera3_stream_t`。
  maple 的相机 provider 是索尼的 —— 翻译可迁移，HAL
  不可迁移。
- **值得抄的 eng-only 调试工具：** `kmsglog.sh` 把上一次启动的
  kmsg 留在 `/data/log/kmsg.prev.txt`（能挺过崩溃）；
  `blackbox.sh` 每 2 秒把 ps/mounts/dmesg 转储到
  `system_a` 内 2 GiB 的裸偏移处，转储前先做 `PARTNAME=` 校验，
  校验不过就拒绝写入。
- **仅 A/B 适用，与 maple 无关：** `bootmark` + 重试计数器、
  `skip_initramfs`→`want_initramfs` 内核改名、slot 联动。
