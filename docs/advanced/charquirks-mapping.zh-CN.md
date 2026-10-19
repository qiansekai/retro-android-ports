# CHARQUIRKS 对照（姊妹移植：4.2-on-pdx203 → maple KitKat）

> 中文译文。英文原文见 [charquirks-mapping.md](charquirks-mapping.md)。技术名词、代码、路径、命令与日志一律保留原文。

参考笔记：一份姊妹移植的 `CHARQUIRKS.md`（Android 4.2.2 跑在 Xperia 1 II、SD865、内核
4.19；该文档为私有，不在本仓库）如何对映到 maple/KitKat。阅读于 2026-10-14。下文是：我们
独立收敛到了什么（反过来印证了我们的路子）、哪些内容适用于我们当时的卡点、以及排给后续阶段
的事项。当前状态见 [maple 怪癖](../devices/maple/quirks.zh-CN.md)；通用教训见
[KitKat 移植笔记](porting-notes/kitkat.zh-CN.md)。返回 [advanced 索引](README.zh-CN.md)。

## 独立收敛到的结论（印证了我们的做法）

- **Binder 64 位协议打在 userspace，而不是内核里**（`Parcel`、`IPCThreadState`、
  servicemanager 的 `binder.c`/`binder.h`、bionic 的 `linux/binder.h` 都换成 64 位布局）。
  我们是从第一性原理出发、通过 ioctl 编号不匹配（0xc0186201 vs 0xc0286201）推出来的；
  他们的文档直接点明了这一点。修复形态相同。
  - 可套用的额外细节：**「每个 64 位 union 的上半部分要清零，那里的垃圾会让查找崩掉。」**
    2026-10-14 审计过：我们栈上构建的结构体（`binder_call` 的 writebuf、`binder_send_reply`
    的 data、`flatten_binder` 的 obj）每个字段都有赋值；布局里没有填充（`binder_txn` 64、
    `flat_binder_object` 24、`binder_write_read` 48）。没问题，无需动作。
- **「没有 super」布局**：maple（2017 年，没有动态分区）与他们的「no super」一节完全对得
  上 —— 纯 GPT 分区，直接从 init.rc 挂载，bootloader 的 fastboot 裸写。我们的裸节点挂载 +
  dd 刷写就是文档里验证可用的路径。不需要 lpmount/dm。
- **首启清空 userdata**（加密 f2fs 旧 Android 读不了）。我们手工做了等价操作
  （mke2fs sda15）。相同。
- **ueventd 的 by-name 链接早期并不存在** —— 我们按原始 sde/sda 节点挂载，并配合
  `wait_for_coldboot_done`。结论相同。
- **SurfaceFlinger 不带 hwcomposer，走 framebuffer hal / 软件渲染。** 我们的 libagl 路径
  与之相符；他们的 glrenderd（GPU）是更晚、更大的项目，我们做 UI 时**不需要**。
- **`ro.opengles.version=131072`** —— 我们的 system.prop 里已经有了。
- **Java/JDK：Oracle JDK 6 没了，把 OpenJDK 检查 patch 掉** —— 与我们的
  `build-jdk-openjdk6.patch` 相同。
- **PRODUCT_COPY_FILES 做不了符号链接；build.prop 不会重新生成** —— 记下来，留给打包阶段。

## 适用于我们当前的卡点（黑屏、load 6+、dalvik 15）

- **固件加载卡顿的特征**：「一次加载没命中会落到 ueventd 的用户态 helper，每个文件卡 ~60 s，
  那个延迟就是线索。」我们那次卡 11 分钟再放行的模式（test18 观察：23:15 安静、23:16 开始
  爬升）符合「多个 ~60 s 卡顿被串行解开」的样子。maple 上的候选：venus/video 固件
  （开机时 mediaserver/OMX 的探测）、adsp、slpi、tzapps。动作：wchan 观察器（test20）若
  存在会看到（syfs request_firmware 线程处于 D 状态）；一旦确认，要么把固件 blob 一起发出去，
  要么把请求打成桩。
- **审计积压导致的 D 状态风暴**：已排除（SELinux 设成 permissive 也没变化）。他们的文档同样
  没提；这个猜测丢弃。
- **`on fs`/`wait` 5 秒放弃（4.2）**：KitKat 的 `do_wait` 接受可选超时 —— 需要更长等待时看
  `system/core/init/builtins.c`。目前由 `wait_for_coldboot_done` 覆盖。除非挂载回退，否则
  不动。

## 排期：adb 打通（紧接着 UI）

- 4.4 内核上 USB 只有 configfs 一条路；`android_usb` 的写入会静默失败。需要从 init 起一个
  configfs gadget + functionfs 的 adb function（`init.maple.usb.rc`），照他们的
  `init.pdx203.usb.rc` 仿写。
- 把 gadget 强制到 HIGH 速度（4.x 的 adbd 没有 superspeed 描述符），并用 USB-2 线。
- 断开时 adbd 会关掉 ep0 并去绑 UDC（旧 adbd 没有 ffs 握手）→ 用重绑循环盯着空的 UDC。
- `adb shell` 需要能用的 `/dev/pts`。
- Eng 构建（`ro.secure=0`、`ro.adb.secure=0`）→ root adb，无鉴权。
- 在 cmdline 上加 `printk.devkmsg=on`，让非 root 脚本也能写 kmsg（这本可以让我们的 init
  标记可见；和 USB cmdline 的活儿一起加）。

## 排期：存储阶段

- `class late_start` 只能经由 mount_all→nonencrypted 触发。我们放弃了 mount_all（改成直接
  挂载）。等存储落地时：在 `class main` 里跑 sdcard daemon，用模拟存储布局
  （`/data/media` → fuse → `/storage`），`storage_list.xml` overlay
  （`android:emulated="true"` + `android:primary="true"`），
  `PRODUCT_CHARACTERISTICS := nosdcard`，`/cache` 用 tmpfs。（没有已知卷时 MountService
  会 NPE —— 若 dexopt 之后启动再次卡住，这是第 2 号嫌疑。）
- KitKat 的 fs_mgr **能**做 /data（fstab + `mount_all` 能把 late_start 带回来）；UI 打通
  之前保持直接挂载，之后再回头处理。

## 排期：UI/打磨阶段

- 4 GB RAM 上 `ActivityManager.isHighEndGfx()` 为 true → 会启用需要 hwui 的效果。在软件
  渲染期间 patch 成 false。
- `ro.config.low_ram=false`、`dalvik.vm.heapsize=256m`、
  `dalvik.vm.heapgrowthlimit=128m`。
- 必须有 `media_profiles.xml`（缺了相机应用会抛异常）。
- 属性名：某些前缀只有系统应用能设；把自定义设置改名到允许的前缀里。
- `media_codecs.xml`（软件 codec）不给的话 MediaPlayer 什么都放不出来；`libsrec_jni` 要进
  PRODUCT_PACKAGES，否则录音机崩。

## 排期：内核重建项目（需要单独立项）

- **Logger 驱动**（`drivers/staging/android/logger.c`、`CONFIG_ANDROID_LOGGER` + 32 位
  compat 入口头）：KitKat 的 liblog 需要 `/dev/log/*`（logd 是 5.0 才有的）。没有它我们
  就是瞎子（logcat 退出、ALOG 丢弃、ALOGE 引发 errno 副作用）。能恢复真正的日志。
- **Alarm 驱动**（`alarm-dev.c`、`CONFIG_ANDROID_ALARM_DEV`）：KitKat 的 AlarmManager 需要
  `/dev/alarm`（timerfd 是 5.0+）。没有它就无法从设置里设置时间，闹钟也只在清醒时触发。
- 保留 `CONFIG_COMPAT`（Sony 内核里已有），binderfs 关掉（`/dev/binder` 必须以 misc
  注册），只留一个 `binder` 设备（`CONFIG_ANDROID_BINDER_DEVICES="binder"` —— 不要
  hwbinder/vndbinder，否则 chroot 里的 blob 会卡在 waitForHwServiceManager）。
- 他们的树是 Sony 开源 + clang 的 techpack；我们的会从 whatawurst msm8998 树起步。在预编译
  内核上把 UI 跑起来之前，**不要**开工。

## 排期：射频（要晚得多）

- 子系统默认值（SYSTEM restart / modem PANIC）必须先设成 RELATED/NOP，否则 dsp 或 modem
  一崩就把整机 panic。→ TEST 36 里 adsp/slpi 已做完（`init.maple.rc` 在 post-fs-data 时
  往 subsys4/5 写 RELATED；2026-10-16 实机读回 7 个全是 SYSTEM）。Modem 刻意不动（在这里
  根本起不来；没有崩溃来源）。
- Modem 的 errfatal ~40s 模式已知；预期要打一仗。GPS 卡在 modem 上。
- cmdline 上 `service_locator.enable=0`（用 =1 时他们的声卡花了 ~5 min 才注册）。→ TEST 36
  已完成（BoardConfig 从 1 翻成 0；待验证项：重刷后 tavil 声卡能否被探测到）。
- WiFi：他们的 4.2 用 wpa_supplicant_8 + nl80211 + lib_driver_cmd_qcwcn，且
  `BOARD_WLAN_DEVICE` **不设**（qcwcn 会打开 p2p；他们跑的是裸 `wpa_supplicant` +
  `wifi.interface=wlan0`）。Maple 保留 qcwcn（KitKat 的 driver_nl80211 链接时**必须**要
  那个私有库 —— 静态链接，所以设备上没有 .so），并同时定义两个 supplicant 服务，由框架选；
  `wifi.direct.xml` 仍然不发（同样的姿态）。Maple 的 wifi 芯片是 WCN3990/cherokee，经内置
  的 qca_cld3（**不是** BCM43xx —— 已按 `/proc/config.gz` + BT tlv 名字纠正），新 ini 里
  `gIPAConfig=0`（ipa_smmu_wlan 无法在运行时分配它的 iommu domain）。驱动能加载
  （v5.1.1.77V，/dev/wlan chr 229,0）但没有 wlan0/phy —— WLFW/QMI 握手很可能被 modem
  把着。TEST 36 有完整清单。
- TEST 37 的结论（maple 验证过，约束后续所有射频工作）：SKIP_QMI 无论有没有布置 BDF 都在
  启动时 panic（已回退）；QRTR 在内核里**根本不存在**（kallsyms 0 命中，只有老的
  IPC_ROUTER），所以**没有** QRTR userspace（cnss-daemon、pd-mapper、rmt_storage、
  tftp_server —— 64 位 chroot 的想法死得更透：连 `linker64` 都没有）。剩下的 wifi 路径
  要么 modem 启动，要么内核回移 QRTR。音频剩下的路径同样必须避开 QRTR：
  adsprpcd-over-SMD（`/dev/adsprpc-smd` 存在）或走 HAL 内 ACDB 经 `/dev/msm_audio_cal`
  （`maple-fw/acdbdata` 已暂存）。
- 音频：为这次移植写的 tinyalsa `audio.primary.maple`（TEST 36；扬声器 = `speaker` +
  深缓冲 MM1/pcm0，麦克风 = `handset-mic`/dmic1 + MM1/pcm0，DEC7 104，不用 acdb，探测前
  静默安全）配 `mixer_paths_tasha.xml`、`audio_policy.conf`、`libsrec_jni`。先修声卡侧：
  从全部 4 个 DTB 里剥掉 `qcom,wcn-btfm`（对应他们的 `qcom,wcn-bt = <0>`），下一步布置
  adsp 固件（modem 的 `image/adsp.*` 已实机清点；blob 和内核一样不进 git）。

## 排期：调试卫生（现在就该做）

- `run-on-device.sh` 模式（把二进制推到 `/data/local/tmp`，跑起来，读日志文件）用来免重刷
  测试各个部件 —— adb 一通就采用；在那之前我们的 init-service + 文件模式就是等价物。
- kmsg 写入保持最少（console_lock 会卡死 panic）；我们的标记已经去掉了。
- 设 `TARGET_NO_KERNEL := true`，让构建永远不去自己生成 boot.img —— **现在就采用**
  （我们手工打包 boot.img，少一个意外）。
