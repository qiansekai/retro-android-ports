# maple 怪癖（Sony Xperia XZ Premium G8141/G8142）

> 中文译文。英文原文见 [quirks.md](quirks.md)。技术名词、代码、路径、命令与日志一律保留原文。

移植到 maple 所需的一切：硬件快照、分区布局、
kernel、阻塞清单，以及带已验证修复的完整
TEST 1–37 打通日志。状态、版本与链接见
[设备主页](README.zh-CN.md)；通用 KitKat 实战手册是
[KitKat 移植笔记](../../advanced/porting-notes/kitkat.zh-CN.md)，另有
[Donut 实战手册](../../advanced/porting-notes/donut.zh-CN.md) +
[cooper 怪癖](../cooper/quirks.zh-CN.md) 作为方法参照。

当前状态：**2026-10-15 已启动（BOOTED）** —— 4.4 kernel 上跑完整 KitKat 用户空间：
`sys.boot_completed=1`、75 个 binder 服务、Launcher 在
1080x1920 下合成、触摸可用、USB adb（`18d1:4ee7`）。**硬件加速
GL/GLES 已于 2026-10-15 验证**（Adreno 540 经 glrenderd，GLES 3.2）。
[`devices/maple/kitkat/`](../../../devices/maple/kitkat/) 下的设备树是带
注释、经启动验证的。剩余缺口（尚无
蜂窝/音频/相机/WiFi —— 与 cooper 早期相同的已记录限制姿态）
在文末跟踪；下面的阻塞 1–4 均已解决。

## 已确认设备状态（2026-10-13，机主报告）

- 变体：单卡（G8141）。设备树默认值（`PRODUCT_MODEL := G8141`、
  `TARGET_OTA_ASSERT_DEVICE` 首项含 G8141）已匹配。
- TA 分区已备份（DRM 密钥安全）。
- 当前运行 LineageOS（bootloader 已解锁，可用 TWRP 时代的刷机流程）。
  官方原厂（stock）转储应从运行中的 LineageOS/TWRP 经
  `scripts/dump-maple-stock.sh` 取得 —— 对分区、by-name 节点、
  framebuffer 与 density 事实仍然有效。

## 原厂转储结果（`dumps/maple-stock-20261013-213045/`）

运行 **LineageOS 20（Android 13，非官方，构建于 2024-11-17）**，
kernel `4.4.302-whatawurst+` aarch64，8× Kryo（4×0x801 + 4×0x800），平台
`msm8998`，`ro.product.device=maple`，`ro.product.board=G8141`。

- **密度：实测 410**（`ro.sf.lcd_density=410`；dumpsys Built-in
  Screen 1080×1920 @ 约 403 dpi 物理）。4K 面板在
  常规使用下渲染 1080p —— `system.prop` 现在钉住 410（此前是 480 的猜测）。
- **Framebuffer：1080×1920 @ 60 Hz，HDR10**（HdrCapabilities type 2）。
  KitKat 软件渲染打通瞄准的是这个模式，不是 4K。
- **块映射已确认**：`/dev/block/bootdevice/by-name/*`，其中
  system→sde46、userdata→sda15、cache→sda5、boot→sde35、recovery→sde36 ——
  与 `fstab.maple` 一致（路径此前已按 TWRP recovery
  fstab 修正；实测转储吻合）。
- **存在 32 位兼容**：`ro.product.cpu.abilist32=armeabi-v7a,armeabi`
  —— 运行中的用户空间带 32 位库，这对
  阻塞 1（此 kernel 上的 32 位 KitKat 用户空间）是（弱）正面信号。
- 输入：event0–event9 + mice（`system:input`，0660 类节点）。
- 缺口（脚本 bug：`run()` 把回显写进了文件；此后已修 —— 需补上
  `adb root` 步骤重跑）：`/proc/cmdline`、`/proc/partitions`、
  `/default.prop`、fb0 sysfs 节点全部返回空。

## 硬件快照（G8141 单卡 / G8142 双卡）

- SoC：Qualcomm Snapdragon 835 MSM8998（10 nm，4×2.45 GHz + 4×1.9 GHz
  Kryo 280，ARM64）+ Adreno 540。4 GB LPDDR4X、64 GB UFS、microSDXC ≤256 GB。
- 显示：5.5" IPS LCD，3840×2160 4K HDR（HDR10，801 ppi，Gorilla Glass 5）。
  Sony 常规渲染 1080p；仅 HDR 视频/相册用 4K。密度 TBD
  （参考值 `TARGET_SCREEN_DENSITY := 400`；骨架 `system.prop` 用 480
  作为待验证起点 —— 参见 cooper 的 120-vs-160 教训）。
- 原厂 OS：Nougat 7.1.1 → Oreo → Pie 9。参考设备树瞄准 10/11
  （Lineage 17.1/18.1）配 4.4 kernel（`Image.gz-dtb`）。
- 电池 3230 mAh，IP65/68，USB-C，指纹（非美版），NFC，BT 5.0，
  WiFi a/b/g/n/ac，19 MP 后摄（960 fps 慢动作）+ 13 MP 前摄。
- 代号：`maple`（单卡 G8141）/ `maple_dsds`（双卡 G8142）。
  平台：`yoshino`。bootloader 可解锁；有 TWRP + Lineage。

## 平台特性

### 分区布局（GPT/ext4，不是 BML/stl）

- boot/recovery 各 64 MB（`BOARD_BOOTIMAGE_PARTITION_SIZE 67108864`），
  system 约 5 GB、cache 约 380 MB、userdata 约 22 GB。`BOARD_FLASH_BLOCK_SIZE
  131072`（= pagesize 4096 × 32……实际是 ×64 = 262144？参考资料写
  131072 —— 需再核；按参考资料值保留，标 TODO）。
- `BOARD_KERNEL_BASE 0x00000000`，pagesize 4096，`Image.gz-dtb`。
  可直接 fastboot 刷（`fastboot flash boot boot.img`）；不像 cooper 那样要
  `erase_image` / `flash_image` 的 BML 套路。**每次刷写仍要**回读
  验证（cooper 的规矩同样适用）。
- 参考板级参数：`sony-msm8998/android_device_sony_maple`（`ten`）
  + `yoshino-common/BoardConfigPlatform.mk`（msm8998，4.4 kernel，
  `TARGET_KERNEL_CONFIG lineage-msm8998-yoshino-maple_dsds_defconfig`）。

### Kernel

- Sony 出货的 msm8998 kernel 是 **4.4** —— 比 KitKat 时代的
  3.4/3.10 kernel 新了十年。在 4.4 kernel 上跑 KitKat bionic + init，与
  在 2.6.35 上跑 Donut 属同一类问题（ueventd 节点、cgroups、SELinux 占位、
  lowmemorykiller/firmware-loader 路径全都需要审计）。
- kernel 镜像格式 `Image.gz-dtb` 晚于 KitKat 的 mkbootimg。预期需要
  mkbootimg 回移（先例：
  `patches/donut/mkbootimg-pagesize.patch`；见
  `docs/advanced/porting-notes/kitkat.md`）。

### 阻塞清单（2026-10-15 全部已解决 —— 留档备查）

1. **ARM64 SoC vs 仅 32 位的 KitKat —— 结论：可行（VIABLE）。** 32 位
   `armeabi-v7a` 用户空间（cortex-a15）能在 4.4 kernel 上跑
   （CONFIG_COMPAT）；kernel 侧唯一需要的移植是 binder
   64 位 UAPI（见下）。Modem/firmware blob 未动（尚无
   蜂窝）。
2. **工具链/容器 —— 完成（DONE）。** Trusty + JDK 6 容器
   （`containers/kitkat/Dockerfile`）、`build-jdk-openjdk6.patch`、
   `lib32stdc++6 lib32z1`、`python` 符号链接。完整 `make -j6` 全绿。
3. **显示/framebuffer —— 硬件 GL 已可用（WORKING）2026-10-15。** Adreno 540 没有
   KitKat 的 EGL/HWC，因此 EGL 经 glrenderd（在
   Lineage chroot 里跑 Adreno）走，libagl 作软件回退。glrenderd 是
   唯一的 fb0 翻页者（SF 经 rcFBPost 提交）；冷启动在
   1080x1920 下验证通过（`GLES: Qualcomm Adreno 540, ES 3.2`）。三个已修根因
   见下面的 gpu 条目与 TEST 30。显示不需要 DTB/驱动工作。
4. **存储/init —— 完成（DONE）。** GPT 按裸节点挂载
   （system→sde46、cache→sda5、userdata→sda15、persist→sda4）；
   KitKat 上 `/dev/block/bootdevice/` **并不存在** —— by-name 位于
   `/dev/block/platform/soc/by-name/` 下。全线 ext4
   （`TARGET_USERIMAGES_USE_EXT4`，被擦分区用 TWRP mke2fs）。
5. **WiFi/BT/RIL/相机/GPS。** 全是专有组件（BCM43xx + qcwcn、QCOM BT、
   MSM8998 RIL、QTI camera）。仍是 stub/通用（cooper 套路：
   `USE_CAMERA_STUB`、移除 rild、禁用 BT）—— 各 HAL 的移植是
   输入/显示之后的下一步工作。
6. **首次启动无蜂窝/音频/相机** —— 与 cooper 相同的
   已记录限制姿态（见下面的状态）。

### cooper 直接教给 maple 的东西

- 在 QCOM HAL 路径被证明之前，用 `TARGET_BOARD_PLATFORM := maple`
  （而不是 `msm8998`）—— 与 cooper 绕开 `hardware/msm7k` 是同一招。
- 密度必须实测，不能猜（cooper 120→160）。
- 每次刷写都用回读验证（cooper 的 BML 规矩，对 fastboot 同样适用）。
- Provisioning/`device_provisioned`、keymaps、`TARGET_PROVIDES_INIT_RC`、
  updater-script 参数个数 —— 均已在
  `docs/advanced/porting-notes/kitkat.md` 中为 KitKat 重新审计
  （KitKat Edify 有 `run_program` + ext4 `format`，与 Donut 不同 —— 这里比 cooper 容易）。
- blob 不进 git（`.gitignore` 覆盖 `aosp-kitkat/`、`out/`、`work/`）。

## 打通日志与后续动作
功能矩阵与版本状态：[设备主页](README.zh-CN.md)。

开机进 UI，触摸 + adb 可用（2026-10-15 —— 打通日志见 TEST 24–29）。
最新进展（TEST 33，2026-10-16）：poplar 可靠性集合 +
lights HAL + keyguard-scrim 修复已生效 —— systemui 扛住导航栏
压力测试，GL 经 glrenderd 稳在 Adreno 540，亮度/休眠正常。
构建前的工具（这些不需要服务器）：
`containers/kitkat/Dockerfile`（Trusty/JDK6，已验证）、
`scripts/dump-maple-stock.sh`（经 adb 取原厂事实 → `dumps/`，已 gitignore）、
`scripts/sync-device-tree.sh maple kitkat`（已验证）。
后续动作（日志用的复选框）：

- [x] 骨架设备树 + init/fstab 骨架（块路径已按 TWRP `fstab_maple.recovery`
      修正为 `/dev/block/bootdevice/by-name/*`，
      经实测 `by-name` 转储确认：system→sde46、userdata→sda15、
      cache→sda5）
- [x] KitKat 容器配方 + 原厂转储脚本（脚本已修：echo 写到了
      stdout，补上 `adb root` 步骤 —— cmdline/fb 缺口需重跑补齐）
- [x] 显示密度实测：**410**（实测 `ro.sf.lcd_density` + dumpsys
      1080x1920@403dpi）；`system.prop` 已钉住，framebuffer 目标 1080x1920
- [x] 构建服务器上 `repo sync` 干净（浅克隆 `--depth=1 -c --no-tags`，
      14 GB）；`lunch full_maple-eng` 通过（BUILD_ID=KTU84Q）
- [x] `boot.img` 已验证：ANDROID! magic、kernel 16744559 B（与 TWRP 转储的
      kernel 完全一致）、base 0 + 0x8000、pagesize 4096 —— KitKat
      mkbootimg 原生就能处理 `Image.gz-dtb`/base-0，无需回移。
- [x] `patches/kitkat` 首条：`build-jdk-openjdk6.patch`（接受
      OpenJDK 6；Oracle JDK 6 在 2026 年已装不上）+ 容器内的 `python` 符号链接
      与 32 位运行时库（`lib32stdc++6 lib32z1`）。
- [x] 首次完整 `make -j6`：用户空间编译通过（host tools、aidl、java）；
      仅停在 `No rule to make target vendor/sony/maple/kernel`。
- [x] wpa_supplicant 这桩公案已了：qcwcn 配置是对的（KitKat 的
      `driver_nl80211.c` 声明了 p2p/driver_cmd 钩子，而只有
      `lib_driver_cmd_qcwcn` 定义它们；通用的无驱动配置在
      `sme_*` 上挂掉，因为没人设 NEED_SME）。`lib_driver_cmd_qcwcn`
      能编译；supplicant 能链接。WiFi 在驱动移植（阻塞 5）之前仍然不可用
      —— 只是能链接。
- [x] ext4 修复：没有 `TARGET_USERIMAGES_USE_EXT4` 时，KitKat 默认
      用 yaffs2；为 system/userdata/cache 设为 ext4。
- [x] 完整镜像集 2026-10-13：`boot.img` 17 MB（几何已验证）、
      `system.img` 284 MB（稀疏 ext4，magic 正常）、`cache.img`、
      `userdata.img`。阻塞 1（MSM8998 kernel 上的 ARM32 用户空间）进入
      实弹阶段：刷机测试 + 日志采集。
- [x] TEST 1 已刷（TWRP dd，哈希已验证）→ 卡在 Sony logo，无
      USB。在构建出的 ramdisk 里找到根因：**没有 `/init.rc`**
      （`TARGET_PROVIDES_INIT_RC=true` 压掉了原厂那份，设备树
      也没提供替代）→ init 空转，零 actions/服务。
      修复：`devices/maple/kitkat/init.rc`（原厂 KitKat init.rc + `import
      /init.maple.rc`），接入 `full_maple.mk`。TEST 2 的 `boot.img`
      （17,080,320 B，已确认 ramdisk 内含 init.rc）已刷（仅 boot）。
- [x] TEST 2：kernel 已启动，init 跑了，随后 `reboot to recovery` —— ramoops
      （经 TWRP pstore 取 `console-ramoops-0`）显示 `/system` 从未挂载
      （每个服务都 `cannot find /system/bin/*`；mkdir 落到了
      rootfs）→ 根因：TEST 1 把**稀疏** system.img 原样 `dd` 了进去
      （ext4 垃圾，无法挂载）。修复：用 simg2img 转裸 ext4 推到
      `/data/media` 再 dd（5 GB，分区上验证 magic `53 ef`）。
- [x] TEST 3/4（init.rc 在场，加 kmsg 标记）：标记从不出现 ——
      init 的 `write /dev/kmsg` 观察不到（SELinux/policy），且
      `do_mount` 是**静默**失败。教训已记录，标记已移除。
- [x] TEST 5（`wait_for_coldboot_done` + 裸 sde/sda 节点 + 修正挂载
      语法 —— KitKat 要求标志以空格分隔、末尾只能有一个 options
      参数）：`/system`（sde46）与 `/data`（sda15）都挂上了，所有服务
      都找到。新的卡点：`healthd` 退出 4 次 → 25 s 时重启进 recovery。
- [x] 阻塞 1 根因（更正）：TWRP 侧的 32 位 SEGV 是环境问题
      （recovery ramdisk 缺 `/system/bin/linker`；PIE
      linker 会自己解析自身路径，缺了它便失败）。开机时
      servicemanager **没有**崩溃循环（没有 critical 消息），所以 4.4 kernel 上的 32 位
      exec 正常 —— kernel 有 CONFIG_COMPAT，刷入的内容
      持久。cortex-a15 重编保留（无论如何都是 Kryo 的正确变体），
      但不是 healthd 的修复。
- [x] TEST 6（cortex-a15 系统）：挂载保持，所有服务找到，healthd
      循环依旧。
- [x] TEST 7（独立的 mount 块 —— 在 KitKat init 里，挂载失败会静默
      中止其 action；按 cooper 先例禁用 vold + rild；加 logcat 写文件
      服务）：只有 system+userdata 挂上（cache sda5 + persist sda4 失败，
      现已隔离、非致命）。仍然没有 `on boot`（没有 logcat 文件）+ healthd 循环。
- [x] 阻塞项，2026-10-14 解决（无需审批 —— 数据早已
      没了）：`/data`（sda15）与 `/cache`（sda5）被发现完全
      清零，根本没有文件系统（kmsg 里
      `EXT4-fs (sda15): VFS: Can't find ext4
      filesystem`，blkid 空白，head + 1 MB 采样全零；
      Lineage 的 FBE 数据早已被毁，原因不明 —— 一次没有格式化的
      擦除）。只有 `/system` 挂上，rootfs 保持 ro，于是所有
      `/data/property` 写入失败，installd/keystore 卡在 `restarting`，
      启动从未完成。修复：在 TWRP 里现场把两者格式化为 ext4
      （`mke2fs -t ext4 -b 4096 -L userdata/cache`）。同一轮里的设备树修复：
      在 `init.maple.rc` 的挂载之前 `mkdir /cache + /persist`
      （这些挂载此前**静默** ENOENT 失败 —— 没有 ramdisk 目录，kmsg 里也无信息）、
      去掉无效的 `wait_for_coldboot_done`（KitKat init 没有
      该命令）、去掉重复的 `import /init.maple.rc`（全部五个
      服务都被记为忽略的重复项）、fstab by-name 路径改为
      `/dev/block/platform/soc/by-name/*`（`/dev/block/bootdevice/` 在
      KitKat 上不存在）。
- [ ] Kernel（`Image.gz-dtb`）：关键路径 —— 需要机主的 Lineage 构建
      产物。期间跑 `make -j6 systemimage` 验证用户空间其余部分。
      → 2026-10-13 已解决：从 TWRP 现场转储
      （`adb pull /dev/block/bootdevice/by-name/boot`，64 MB，ANDROID!
      magic，pagesize 4096，base 0）。Kernel（16.7 MB gzip，`Image.gz-dtb`）
      在服务器上用 abootimg 拆出 → `vendor/sony/maple/kernel`
      （带外 blob，**不入** git —— 与 cooper blob 同策略）。
      `BOARD_KERNEL_CMDLINE` 已按现场 bootimg 配置更新。
      正在跑完整 `make -j6`。
- [x] 用（修好的）`scripts/dump-maple-stock.sh` 重跑补齐缺失的
      `/proc/cmdline`、`/proc/partitions`、fb0 sysfs 节点
      → 重跑干净（无断连）；需 root 的节点在 shell 用户下仍为空 ——
      改为从 TWRP recovery adb（以 root 运行）拉取；
      没有关键项受阻。
- [x] 对原厂/TWRP 状态的 maple 跑 `scripts/dump-maple-stock.sh`；按转储
      修 `fstab.maple` + `system.prop` 密度 → 已完成
      （platform/soc by-name 路径，密度钉住 410）。
- [x] `repo init -u https://android.googlesource.com/platform/manifest -b android-4.4.4_r2` → `aosp-kitkat/`（浅克隆 `--depth=1 -c --no-tags`）
- [x] 在构建服务器上构建容器，首次 `lunch full_maple-eng`
- [x] msm8998 上跑 ARM32 用户空间的可行性预研（阻塞 1 结论）
      → 结论：可行（VIABLE，见下面 TEST 26 + binder 公案）。
- [x] TEST 8-13（binder 公案）：servicemanager/healthd 死于 binder
      WRITE_READ EINVAL。根因：KitKat 的 24 字节 binder_write_read
      （ioctl 0xc0186201）对 v8-only kernel 的 40 字节布局
      （0xc0286201）—— 再加上 v7-vs-v8 协议、4 字节 Parcel 偏移 vs
      8 字节、20 字节扁平对象 vs 24 字节。修复：
      `patches/kitkat/binder-uapi-64bit.patch`（64 位干净的 UAPI 头、
      Parcel mObjects u64 + hdr.type + 类型转换、IPCThreadState 类型转换 +
      read/writeInt64 + 8 字节偏移、servicemanager 本地结构体）。
      现场 ENTER_LOOPER res=0。完整细节见 commit message。
- [x] TEST 14：system_server 起来了，dexopt 开始。surfaceflinger 在
      eglGetDisplay 中中止（10 个 tombstone）—— KitKat 的 EGL 加载器跳过了
      libGLES_android.so。修复：`egl-use-software-renderer.patch`。
- [x] TEST 15：**不再**重启进 recovery，黑屏 + 背光亮，没有新
      tombstone，dalvik-cache 1 → 15 个 jar。启动正在推进
      dexopt。仍有一处 reply-path 写入 EINVAL（非致命；怀疑
      FREE_BUFFER/death 布局 —— 待复查）。
- [ ] 让首次启动的 dexopt 跑完（约 30-40 分钟），然后看 UI。
      → 并**未**完成：后续所有启动中 dalvik 都冻在 15 个 jar。
- [x] TEST 16-19（卡死排查）：load 钉在约 6.5，任何地方 CPU 都为零，无
      崩溃。已排除：SELinux audit 风暴（改 permissive 毫无变化）、
      存储错误（早期 kmsg 干净，TWRP 里 I/O 很快）、电池（100%）。
      Watcher 演进：loadavg → +proc 快照（toolbox `ps` 不输出任何东西，
      `sort` 在此 kernel 上 SEGV —— 两者都避开；纯 sh +
      cat/grep）→ +meminfo/dmesg（`head`/`tail` 的输出会消失，`dmesg`
      走管道会给出 debuggerd SIGPIPE tombstone —— 改为整份文件写出）
      → +每 PID 的 wchan。
- [x] TEST 20-21（wchan）：用户空间全部健康空转（binder reads、polls；
      zygote + mediaserver + netd + bootanimation 全在）。任何采样里都
      **没有** system_server —— zygote 从不 fork 它。6+ 的 load 来自
      kernel 线程，不是用户空间自旋。卡点在 system_server 完成的上游：
      PM/dexopt 冻住是因为 system_server 没完成（不是 dexopt 慢）。
- [x] TEST 22（autowinch）：`sbin/autowinch.sh` + 服务会在开机 15 分钟后
      把手机送回 TWRP —— 不用再手动按按键组合。完整的
      刷写→开机→拉取 循环现在可无人值守（除了盯屏幕）。
- [ ] TEST 24（在 TWRP 里把 userdata/cache 格式化为 ext4 之后）：重启
      进 KitKat，验证 `/data` + `/cache` + `/persist` 都能挂载，
      installd/keystore 脱离 `restarting`，system_server 出现在
      zygote 下，dexopt 越过那 15 个开机 jar。（2026-10-14 诊断中途
      15 分钟的 autowinch 触发，在 `ps`/`service list` 被采集到之前
      就把手机送回了 TWRP —— 既然 adb 已可用，考虑现在关掉
      autowinch 启动项。）
      → 部分完成 2026-10-14/15：重启显示 `/data`（sda15）**已挂载**
      （`EXT4-fs (sda15): mounted ... noauto_da_alloc,barrier=0`，不再有
      property 错误）、installd/keystore 为 `running`、`/data` 已完全
      填充、servicemanager 有应答（16 个原生服务，含
      SurfaceFlinger/batterypropreg/keystore）。system_server 现在会
      规律地 fork，并进到 PMS 的 apk 扫描（WM/AM/PackageManager 线程、
      SettingsProvider + batterystats 写入），但每一轮生命周期都在约 10 s 时死在
      `collectCertificatesLI` 的 manifest 解析中（SIGQUIT 拿 traces.txt：
      main 在 `CaseMapper.toLowerCase` ← `Attributes$Name.
      hashCode` ← `ManifestReader.readEntries` ← `scanPackageLI` ←
      `scanDirLI`），Java 层（无 tombstone，logcat 瞎），dalvik-cache
      始终为空（在 dexopt 之前就死）。Zygote 守护进程也每
      ~10-60 s 循环一次，无 tombstone/kmsg（头号嫌疑：
      ZygoteInit.main 里的 RuntimeException 路径 —— 没有 logcat 就是瞎）。
      现场用了 `stop autowinch` 拆掉 15 分钟的保险丝。
- [x] TEST 25（诊断构建 2026-10-15）：在构建服务器上加了临时文件标记
      （ZygoteInit preload/fork/death → /data/misc/zygote.txt、
      ServerThread throwable → /data/misc/syscrash.txt、PMS 每个 apk →
      /data/misc/pmscan.txt），重建 system+boot（WITH_DEXPREOPT 本就开着），
      经 TWRP 刷入（simmg2img 转裸 5 GB + 17 MB boot，两者都经 md5
      回读验证）+ 重启。手机在 `adb reboot` 之后**黑掉**了
      （黑屏、红灯、完全无 USB —— 无 adb/fastboot/枚举；
      UART 无输出），需要人工上电（没有远程手）。镜像
      经结构验证无问题（ANDROID!/sparse/ext4 magic、ramdisk
      含 usb.rc + usbudc.sh + 修好的 init 文件、标记在
      services.jar/framework2.jar 里、cmdline 保留 androidboot.hardware）。
      怀疑是电源事件而非镜像内容 —— 上电后待查（TBR）。
- [x] TEST 26（heap 修复 2026-10-15）：死亡循环的根因 ——
      每一轮生命周期里，`JarUtils.verifySignature` 在**第一个** apk
      （`/system/framework/framework-res.apk`，11.8 MB）上抛
      `java.lang.OutOfMemoryError`；build.prop 完全没做 dalvik heap 调优
      （4 GB 手机上用 Dalvik 默认值）。修复：在 full_maple.mk 里继承
      `frameworks/native/build/phone-xhdpi-2048-dalvik-heap.mk`
      （192m/512m）。结果：扫描顺利过 54 个包、
      **75 个服务，含 activity/package/window**、一次稳定的 zygote
      生命周期、零 syscrash、开机动画走完、**Android UI 出现在
      屏幕上**。WITH_DEXPREOPT 让 dalvik-cache 保持为空（设计如此）。
- [ ] TEST 27（USB-ABD 2026-10-15）：完整启动**没有** USB（gadget 从不
      bind；KitKat 的 adb 不可达）。kmsg 显示 adbd 活着但**零**条
      usbudc 行 —— 一旦 system_server 跑起来，`on property:sys.usb.config=adb`
      触发就再也不发（该 property 归 UsbDeviceManager 管）。
      修复（已入树、已刷）：在 adbd 兜底旁边无条件 `on boot`
      里 `start usbudc`。显示也出现错乱（hsync 撕裂 ——
      stride/时序；需要 adb + dumpsys/fb0 探测，等 USB 通后）。
      临时诊断已回退；服务器↔仓库再核为逐字节一致。
      → 2026-10-15 找到根因：init.maple.rc 里缺了
      `import /init.maple.usb.rc` —— 该 import（以及 usb 文件）只存在于
      构建服务器上，早前一次 repo→服务器 同步丢掉了 import 行，
      于是 usb.rc 虽被拷进 ramdisk 却从未被解析，
      `usbudc` 未知，`start usbudc` 是静默空操作。修复：import
      恢复（+ 保留无条件的 `start usbudc` 作为双保险）。
      只重建 boot、刷入、重启：**18d1:4ee7 枚举、
      adb 中出现 `maplekk device`、`sys.boot_completed=1`、75 个服务、
      /system+/data+/cache+/persist 全部挂载、Launcher 合成。**
      maple 上的 KitKat 已启动（BOOTED）。剩余：显示 hsync 撕裂、autowinch
      仍上膛（每次启动 15 分钟后重启进 recovery —— USB 可信后
      即移除）、临时诊断已回退。
- [x] TEST 28（显示 2026-10-15）：面板显示滞留的 xboot 开机图，而
      fb0 持有完美帧（launcher 解码干净）—— mdss 从不
      提交 fb0（白帧 + unblank 循环两种测试在
      视觉上都是空操作；pan 卡在 0,0）。子发现：(a) fb0 stride 是 4352 B
      （1088 px）而 gralloc 报告 1080 → 每行错切 8 px 成
      平行四边形 —— 已在 `gralloc_alloc` 中修复（对 `HW_FB` 报告
      `finfo.line_length` 的 stride；正式化为
      `patches/kitkat/hardware-libhardware-gralloc-fb-stride.patch`，
      现场推送 + 通过 fb0 解码中的反向错切验证）；
      (b) glrenderd **确实**在跑（12 fps，按正确 stride 拷贝）但
      启动时算出 `flips=0`（fb HAL 稍后才把 yres_virtual 翻倍；
      启动竞态）—— 在 fbdev 翻页也停滞时属表面问题；
      (c) 面板活体在跨启动时存在竞态（4 次观测中 2 次活过来：
      overlay 启动 vs MDP idle 塌缩/splash 交接的时序；
      见过的唯一硬错误是启动中途重启 glrenderd 时的
      `mdp ctl start failed`（EBUSY））。目前 glrenderd 保持关闭
      （去掉第二个不协调的翻页者；它的 flips=0
      启动竞态也要先修好才能回归），由 SF 独占翻页
      驱动面板。若未来某次启动冻在开机图上，优先怀疑
      这个竞态（pan 卡住 + kmsg 里 EBUSY）。基础显示不需要
      DTB/驱动工作。
      autowinch 已从设备树移除（adb 现在可信了）。
      → 2026-10-15 解决：glrenderd 不协调的 FBIOPAN 翻页
      卡住了 mdss overlay 启动（`mdp ctl start failed`，EBUSY），并
      把面板冻在开机图上。不启动 glrenderd（纯
      SF+libagl）时，面板是活的，且（配合 stride 修复）是**正确的**。
      → 2026-10-15 重新架构（charquirks 单一翻页者）：根因
      是混合模式（glrenderd 启动晚时 SF 锁定到软件路径）+
      flips=0 竞态。`start glrenderd` 移到 post-fs-data（在
      SF 探测之前），`open_panel` 自己先等再翻倍 yres_virtual。
      glrenderd 现场验证通过（listening、flips 1、无 EBUSY）。待办：
      重建 + 重刷 + 启动验证（服务器不可达）。
- [x] TEST 29（触摸 2026-10-15）：触摸到达 kernel（clearpad MT
      事件）与分发器（RecentQueue），但毫无响应。
      根因：systemui 崩溃循环（ImageWallpaper 里 `eglConfig not initialized`
      —— 需要 ES2，libagl 只有 ES1，glrenderd 又没起；
      约 1000 条 dropbox 崩溃）每轮生命周期都干掉 keyguard 窗口，而
      PhoneWindowManager 驻留一个僵尸全屏 KeyguardScrim
      （"Removing keyguard window (Did it crash?)"），吞掉所有输入。
      修复：EGL init 抛异常时让 `ImageWallpaper` 回退到 canvas 路径
      （正式化为
      `patches/kitkat/frameworks-base-systemui-wallpaper-canvas-fallback.patch`；
      APK+odex 现场推送，重启后生效）。结果：systemui
      稳定、scrim 消失、launcher 获得焦点、**触摸完美工作**。
      （触摸映射正常 —— 固件发的是全量程坐标。）
- [x] 同步审计 2026-10-15（服务器 vs 仓库）：7 个 patches/kitkat
      在两侧完全一致，**且**与现场设备树逐字节相同（反向 apply
      检查通过）；没有残留的 smdbg/bdbg。服务器曾在 4 处
      领先 —— 已拉回仓库（未提交）：`init.maple.usb.rc` +
      `usbudc.sh`（新文件，走 configfs 的 ADB 打通件）、
      BoardConfig 的 `WITH_DEXPREOPT := true`、full_maple.mk 的 usb.rc/usbudc
      行。devices/maple/kitkat 现在服务器↔仓库逐字节一致
      （kernel blob 除外）。
- [x] 后续项（由 TEST 26 解决）：zygote **确实** fork system_server ——
      早前「从不 fork」的采样是 PMS heap-OOM 死亡循环
      （每轮生命周期都在 fork 之前死在 `collectCertificatesLI`）。
      heap 调好之后，MountService/volume 等待与 reply-path 的 EINVAL
      都没有阻塞启动。
- [x] 待办项（已解除阻塞）：现场服务器上的所有改动都已正式化 ——
      `bionic-binder-uapi-64bit` + `frameworks-native-binder-64bit`
      （+ egl/glrenderd 那一组）都在 `patches/kitkat/` 里，且验证与
      现场设备树一致（反向 apply 检查）；smdbg/bdbg
      临时诊断已清除；`boot.img` 由 `make bootimage` 打包，源为
      转储的预编译 kernel（`TARGET_PREBUILT_KERNEL`，**不在** git 里）+
      构建出的 ramdisk；经 configfs gadget 的 USB adb 可用
      （`init.maple.usb.rc` + `usbudc.sh`）；无需重建 kernel
      （无 logger 环境下的日志走文件 + dropbox + debuggerd）。
- [x] TEST 23（已被取代）：15 个 jar 的卡死是 binder 64 位 ABI
      缺口（24 字节 vs 40 字节 `binder_write_read`，现已打补丁）加上
      PMS heap 大小 —— **不是**丢回包导致的卡顿。system_server 能跑，
      dexopt 不是问题（WITH_DEXPREOPT 在构建期预优化）。
- [x] 存储（可用）：内置存储是模拟存储（emulated），`/data/media` 经
      `/mnt/shell/emulated` 的 `sdcard` fuse 守护进程，以
      `/storage/emulated/legacy` 暴露，并带 `/sdcard` 链接（nexus 5
      kitkat 布局，现场验证已挂载）。overlay 的 `storage_list.xml`
      标明其为 emulated/primary。`sdcard` 以 `class main` 运行
      （挂载是手工做的、不走 `mount_all`，故不需要 `late_start`）。
      MicroSD（`sdcard1` 经 vold 挂在
      `/devices/soc/c0a4900.sdhci/mmc_host`，仅 vfat）仍未测试（UNTESTED）——
      下一项存储工作。
- [x] gpu —— 硬件加速 GL/GLES 已验证 2026-10-15（单一翻页者）：540 没有
      KitKat 的 adreno 驱动，所以用 emulator 的 GL 栈作传输层。
      `glrenderd`（在 Lineage-20 chroot 里跑 adreno）独占面板；surfaceflinger
      在宿主侧经 eglimages 合成，并通过 `glrenderd` 抽象 socket 提交
      `rcFBPost`，所以 glrenderd 是唯一的翻页者。冷启动现在直接
      跑在 Adreno 上：`dumpsys SurfaceFlinger` → `EGL implementation: 1.4`、
      `GLES: Qualcomm, Adreno (TM) 540, OpenGL ES 3.2 V@331.0`、settings/launcher
      渲染正常，一个 GLES2 shader 三角形测试光栅化并回读正确。
      五个根因，全部已修：
        (a) 两个翻页者 —— 开机后再启动 glrenderd 会让 SF 锁死在
            软件渲染器上（egl/gralloc 的模拟探测在该进程生命周期内被缓存），
            于是 SF 翻 fb0 **且** glrenderd 也翻 → `mdp ctl start
            failed`（EBUSY，面板冻在开机图上）。修复：把 `start glrenderd` 放在
            `post-fs-data`，即 SF 首次探测之前，让 SF 走 emulator 路径
            （rcFBPost，绝不翻 fb0）。charquirks 的单一翻页者设计。
        (b) flips=0 启动竞态 —— glrenderd 模式下没人打开 fb HAL，所以
            glrenderd 采样时 fb0 的 `yres_virtual` 还是单缓冲；
            glrenderd 随后只做 memcpy，从不翻页。修复：让 `open_panel`
            （tools/glrenderd/src/glrenderd.cpp）自己经
            `FBIOPUT_VSCREENINFO` 翻倍，效果与 fb HAL 完全一致（立即翻倍 ——
            先等再翻倍的版本会给 socket bind 增加约 10s，见 (c)）。
        (c) 探测窗口太短 —— 去掉无意义的等待 fb-HAL 后，glrenderd 冷启动到
            "listening" 约 0.2s；留着那步则是约 10s，SF 原本的 5s 等待就错过了
            （回退到软件路径后不再重新考虑）。修复：egl + gralloc 探测现在最多
            等 30s（`kRenderdWaitTries`/`kWaitTries` = 300）。
        (d) 翻页 ioctl 选错 —— glrenderd 用 `FBIOPAN_DISPLAY` 翻页；maple 的
            `mdss_mdp_overlay_pan_display` 会打印 `unable to allocate base pipe`
            并返回 SUCCESS 但不移动偏移，于是 fb0 持有正确帧而面板
            始终不变（截图看着正常，面板是黑的）。修复：用
            `FBIOPUT_VSCREENINFO` + 新的 `yoffset` 翻页，正是能工作的原厂
            gralloc 的 `fb_post` 所做的。（关于 `set_par`「重做整个模式」的
            移植注释来自 pdx203 的 drm 路径，不是这条 fbdev 路径。）
        (e) mdss 空闲掉电 —— DT 里的 `qcom,mdss-idle-power-collapse-enabled`
            会在显示空闲时给 MDP 断电；面板随后变黑（背光暗、无扫描输出），
            下一次翻页被卡住，于是静态 UI 在触摸之前一直消失。
            修复：从每个追加 DTB 里剥掉该 property
            （scripts/patch-maple-dtb.py，即 pdx203-jellybean 的修复）。
            已在设备上验证：UI 现在能常驻。
      ES2 缺口已补上：hwui/动态壁纸的 ES2 现在可用（这条路径上不再只有
      canvas 回退；glrenderd 停掉时 `ImageWallpaper` 的 canvas 回退仍留作
      安全网）。glrenderd 缺席时，libagl 软件回退仍能渲染出
      正确的 1080x1920 UI。glrenderd 的设计（移植自
      [pdx203-jellybean](https://github.com/chardidathing/pdx203-jellybean)，
      作者 @chardidathing）：emulator 的 gl 库经 `glrenderd`
      抽象 socket 流式传给守护进程（32 位，跑在 lineage 20 的
      system+vendor chroot 里），后者在 adreno 上绘制、回读、翻 fb0。
      构建：先打上四个 `*glrenderd*` 补丁，然后
      `tools/glrenderd/build.sh $AOSP_DIR <android-ndk-r21e>`、
      `tools/glrenderd/extract-lineage.sh <lineage 20 maple zip>
      <sysroot> [oem.img]`、`tools/glrenderd/stage.py <sysroot>
      tools/glrenderd/out $AOSP_DIR/vendor/sony/maple-glr`（oem ==
      lineage vendor；zip 若已不在就从 TWRP 转储）。协议
      自 4.2 未变；守护进程按 KK sdk 构建。
      Kernel blob：把 `Image.gz-dtb` 转储到
      `vendor/sony/maple/kernel` 之后，运行
      `scripts/patch-maple-dtb.py vendor/sony/maple/kernel`，从追加的 DTBs 里
      剥掉 `qcom,mdss-idle-power-collapse-enabled`
      （需要 `dtc`）；blob 在 git 之外，所以该补丁不会
      自动应用。之后由 `make bootimage` 打包打补丁后的 kernel。
      构建服务器备注：NDK r21e 现已装在 `~/android-ndk-r21e`
      （从 dl.google.com 取；构建脚本需要它 + 宿主 C++
      编译器 + python3）。
      **已知偶发**（与 GL 无关）：KitKat 的 keyguard 极少见地会卡进
      已记录的僵尸 `KeyguardScrim`（`KeyguardViewManager`/PhoneWindowManager
      里的开机/解锁竞态，不是 GL）。keyguard 窗口 add 会抛一次
      `BadTokenException: another window of this type already exists`，
      随后 `removeWindowLw` 显示 scrim，UI 就被卡在它后面，直到
      重启。若干次启动里约 1 次复现；非 glrenderd 引起（同样的循环
      在它之前就有）。恢复办法：息屏/亮屏（`input keyevent 26` 两次）会重新触发
      keyguard 的 `onShown` → `hideScrim`，现场就清掉了；重启也行。
      非安全 keyguard 用 MENU 解锁（`input keyevent 82`）。真正的修复是
      WMS/keyguard 的竞态，尚未动手。
- [x] 触摸与按键（触摸 2026-10-15 实测可用）：clearpad
      在 post-fs-data 里 `post_probe_start` 之后探测（同 lineage）；
      `clearpad.idc` + 全量程固件坐标 1:1 映射（不需要
      缩放修复）；带上 `gpio-keys.kl`（音量键分发
      已验证：RecentQueue 里 keyCode 24）；电源键经 qpnp_pon +
      Generic.kl；导航栏开启（`config_showNavigationBar`）。两段式
      相机键（528/766）未测试（UNTESTED）。
- [x] TEST 30（硬件 GL，2026-10-15）：把 glrenderd 拉起为默认
      渲染器，并端到端验证了 Adreno 540 上的 GLES 3.2。
      证据：`dmesg` → 4.95s 时 `glrenderd: starting (pid N)`、`doubled fb0
      virtual to 1080x3840`、`panel 1080x1920 stride 4352 flips 1`、5.19s 时
      `listening on @glrenderd`；`dumpsys SurfaceFlinger` → `EGL implementation
      1.4`、`GLES: Qualcomm, Adreno (TM) 540, OpenGL ES 3.2 V@331.0`、flips
      持续增长；一个 ES2 pbuffer 测试（`test_3d`：红底清除 + 蓝色 shader
      三角形）回读 20808 个三角形像素 / 44728 个清除像素，`glGetError=0`；
      Settings 渲染正常、fb0 解码干净。修复（全部入树）：
      `start glrenderd` 移到 post-fs-data（在 SF 缓存的模拟探测
      之前 —— 干掉双翻页者的 EBUSY 卡死）、`open_panel` 立即翻倍 fb0 的
      yres_virtual（没有别人做这件事 —— 干掉 flips=0 竞态）、
      以及 egl/gralloc 模拟探测改等 30s（glrenderd 的 bind 在冷启动时慢；
      5s 会错过，SF 就整轮生命周期锁在软件路径）。
      另外：构建服务器上重装了 NDK r21e（`~/android-ndk-r21e`）；
      `frameworks-native-egl-glrenderd.patch` + `device-generic-goldfish-
      glrenderd.patch` 更新为 300 次重试等待；glrenderd 重建并
      现场推送（`/system/glr/root/glrenderd`、`/system/lib/libEGL.so`、
      `/system/lib/libOpenglSystemCommon.so`、`gralloc.maple.so`）；boot.img
      重刷（start-in-post-fs-data，回读验证）。测试二进制
      （`test_egl*`、`test_3d`）留在 `/data/local/tmp`。另有
      一处独立的偶发 keyguard-scrim 竞态见上文（不是 GL）。
- [x] TEST 31（面板呈现，2026-10-15）：GL 已经能用，但物理
      面板显示昏暗/黑图，而 fb0 与截图持有正确
      帧。两个独立原因，都已修：
      (d) glrenderd 用 `FBIOPAN_DISPLAY` 翻 fb0；`dmesg` 显示
      `mdss_mdp_overlay_pan_display: unable to allocate base pipe`（ioctl 返回
      成功，偏移从不移动）。能工作的软件路径所用原厂 gralloc
      用 `FBIOPUT_VSCREENINFO` + `yoffset` 翻页；把 glrenderd 改成这套
      之后，`/sys/class/graphics/fb0/pan` 开始翻转，base-pipe 错误消失。
      (e) `qcom,mdss-idle-power-collapse-enabled` 让 MDP 在空闲时断电
      → 面板黑到被触摸为止。已从全部 4 个追加 DTB 里移除
      （`scripts/patch-maple-dtb.py`，与只改该 property 的手工 dtc
      往返结果验证逐字节一致）、重建 boot.img
      （回读验证）、重刷。结果：UI 现在常驻面板
      （机主确认）。另外学到：`mDisplayReady=false` 与
      `idle_power_collapse` sysfs 字符串都是不可靠指标；有活动时
      `/sys/class/graphics/fb0/pan` 里的偏移翻转才是真信号。
      本测试期间设的临时诊断已回退（锁屏保留、
      `screen_brightness` 回到 102、`stayon false`）。
- [x] TEST 32（GL 工作之后重启造成的开机卡死 + 冻结取证 + poplar 修复集，
      2026-10-16）：TEST 30/31 之后机主重启了设备；机器卡在 Sony bootloader 的
      开机画面上，**USB 完全没有反应**（没有 18d1/0fce/05c6，usbmon 静默）。来
      自 TWRP 的事实：这次失败的启动什么都没写（`dmesg-boot.txt` / `watch.txt`
      的 mtime 未变 —— bootlog 根本没跑过），`/sys/fs/pstore` 为空，
      `/proc/last_kmsg` 不存在，boot 分区回读 md5 == 服务器上的 `boot.img`（`3f0f8a7d…`）
      → 刷进去的内容是完整的；卡死属于 userspace 之前的状态，不是内容问题。与
      TEST 25 同类（重启后无 USB 的死启动；需要物理上电开机）。**恢复办法：在
      TWRP 里直接 `adb reboot` → KitKat 18 秒起来**（adb 能枚举；glrenderd
      4.98 s 开始启动 / 5.19 s 开始监听）—— 在重刷任何东西之前先试这个。
      - 分诊规则：「卡在开机画面」按 USB 状态分成两类：adb 还活着 + 画面不动 =
        显示交接卡住（TEST 28 那一类，系统已经起来）；**完全没有 USB =
        userspace 之前就挂了**；走一趟 TWRP 往返来恢复；别指望 pstore（强制断
        电会在 TWRP 读到 ramoops 之前把它丢掉）。
      - 冻结取证（为什么会重启）：上一次会话跑了约 9.6 h；在设备时间约
        13:43/13:59，systemui 的主线程永远阻塞在 `SocketStream::readFully` 里
        的 `recvfrom` 上 —— 一次经由 `eglInitialize`/`rcQueryEGLString_enc`，
        一次经由 `Surface::lock` → `gralloc.maple.so` →
        `rcColorBufferCacheFlush_enc`。glrenderd 停止应答，而没有上界的 socket
        等待把一个渲染器的小抽动变成了永久冻住的 UI（Watchdog 内核 dump 在
        U+33528/33625/33721/33818 s；SYSTEM_RESTART dropbox 13:44；ANR
        13:43/13:59）。
      - 收到 poplar（XZ1）的修复集 —— 同一套 MSM8998/Adreno
        540/emugl-glrenderd 架构。Zip：
        `reference/poplar-kitkat-gpu-fixes-2026-10-16.zip`（sha256 `9effee3a…`；
        里面 `GPU-FIX-AND-QUIRKS.md` = 完整记录，`source/` 是打好补丁的源码，
        `patches/` 是编辑脚本，还有 poplar 专用的参考二进制）。maple 这套可靠
        性修复一样都没有：
        - (A1) fork 安全 —— TLS 的 GL 连接会跨 zygote fork 被继承下来，于是好
          几个进程共享同一个 socket（帧界定丢失）。修法 = 在
          `HostConnection::get()` 里按 pid 重新认领一个 file-static 连接；绝不
          新增成员变量（inline 的 `alloc()`/`flush()` 偏移已经烧进预编译的 enc
          库）。
        - (A2) glrenderd 启动时把 `/proc/sys/net/core/{r,w}mem_max` 提到 16
          MiB —— 默认的 208 KB 会静默地把大 buffer 掐小，让整帧推送卡住。
        - (A3) **有界应答 + 重连 + SIGPIPE** —— `SO_RCVTIMEO`（默认 20 s，可用
          `persist.glr.replytimeout` 调整），超时/EOF/EPIPE ⇒ 标记为 dead，就
          地重连（绝不 free：会 use-after-free —— 他们的 `fix_reconnect.py` 是
          修正后的设计；`fix_wedge_FIRST-DESIGN-DO-NOT-USE.py` 是陷阱），发送
          时带 `MSG_NOSIGNAL`，dead 状态的 `writeFully` 返回 0（要是返回失败，
          会把预编译编码器 memcpy 进去的 buffer 置 NULL）。这修的就是上面那次
          冻结。
        - (A4) 给 `GLConsumer.cpp`（libgui）里的 `glGetError()` 清错循环加上界——
          每次迭代都是合成线程上的一个 socket 往返。
        - (A5) 渲染器侧：`ReadBuffer` 上限 32 MiB + 丢弃客户端，`RenderThread`
          一次只解码一条已声明的消息 + 帧界定诊断（`FRAMING LOST`/`RESYNC`/
          `NOPAYLOAD`、`[glr-rt] client pid=`），丢弃时调 `shutdownStream()`。
          需要在 host 侧的 IOStream/SocketStream 上补 `peerPid()`/
          `shutdownStream()`（这个 bundle 没有附带那处改动）。
        - gralloc：lock 时跳过 `rcColorBufferCacheFlush` 往返 —— host 侧是个空
          stub，但它会阻塞 app 的 UI 线程；它就在我们的 ANR 栈里。
        - C2：`InputDispatcher` 的冻结解冻（10 s），用于死掉的窗口切换造成的派
          发冻结（libinputservice）；B8：`lights` HAL —— maple 压根没有 lights
          模块（`/system/lib/hw` 下没有 `lights.*`；亮度和休眠都需要它）；B9：
          KeyguardScrim 的 no-op/焦点标志（maple 有 canvas 回退，但没有 scrim
          补丁）。
      - 不要跨设备照搬（每条结论都是在各自的硬件上验证的）：poplar 用
        `FBIOPAN_DISPLAY`，但 maple 的 TEST 31 证明 FBIOPAN 在这里是不搬移的空
        操作（「unable to allocate base pipe」），真正能翻页的是
        `FBIOPUT_VSCREENINFO` + yoffset —— 保留 maple 的做法。poplar 期望 fb0
        的虚拟高度事先已经翻倍；maple 的 glrenderd 必须自己把 `yres_virtual`
        翻倍（flips=0 竞态，见 TEST 30）—— 保留 maple 的做法。A6 直接回读（把
        回读直接写进 panel page）：不要移植；poplar 试过并回滚了（开机卡死 /
        画面花屏）。渲染器重编译规则：`glrenderd` 的构建会重新生成 codec 表；
        单独部署一个重编译出来的渲染器会出现偏暗/花屏 —— 要么用同一棵源码树重
        编 guest 的 `*_enc.so`，要么继续用已知可用的那个二进制。
      - 移植前的备份：设备上 `/data/local/tmp/glr-fix-backup-20261016/`，服务
        器上 `~/glr-backup-20261016/` —— glrenderd `c88c3883…`、gralloc.maple
        `5088dd12…`、libOpenglSystemCommon `e8953e41…`（都做过服务器↔设备的
        md5 确认），libgui `6a18ca67…` / libinputservice `3a0b9ed8…`（服务器副
        本已留；设备侧 md5 回读仍为 TODO）。
      - 后续（NEXT）：一次把 A1–A5 + gralloc + C2（+ lights HAL）全部移植完，
        推送，只重启一次，然后做长时间 GL 浸泡，盯 `recvfrom` 一类的卡住（现在
        都不该超过应答超时）以及保持为 0 的 `FRAMING LOST`。→ 已在 TEST 33 完
        成。
- [x] TEST 33（移植 poplar 可靠性修复 + lights HAL + scrim，2026-10-16）：
      A1–A5 + gralloc + C2 整套修复、lights HAL 和 scrim 修复都已移植、编译、
      部署，并在真机上验证（一次批量推送，只重启一次；服务器和设备两侧都留了备
      份）：
      - (A1) `HostConnection.cpp`：在 `get()` 里按 pid 重新认领连接（file-static，
        不是类成员 —— inline 的 `alloc()`/`flush()` 偏移已烧进预编译的 enc 库）。
      - (A3) `SocketStream.{h,cpp}`（guest + sdk 两份副本）：`SO_RCVTIMEO` +
        `SO_SNDTIMEO` 20 s（属性 `persist.glr.replytimeout`），每次发送都带
        `MSG_NOSIGNAL`，超时/EOF/EPIPE ⇒ 标记 dead + **关闭 fd**。MAPLE 在
        poplar 之上额外做的：poplar 发布的 bundle 从不关闭 socket，于是
        `valid()` 一直为 true、`reconnectIfDead()` 永远触发不了 —— 要让重连设
        计真正生效，这个 close 是必需的；另外，往 dead 流上写会把命令丢掉却报
        成功（如果返回失败，就会把 `IOStream::alloc()` 返回的、编码器要往里
        memcpy 的那个 buffer 置 NULL）。
      - (A3) `RenderdStream.{h,cpp}`：就地重连，限频 1/s；`kWaitTries` 保持
        **300**（30 s —— maple 冷启动需要整个窗口，poplar 用的是 50）。MAPLE
        额外做的：重连时必须重放每连接的握手字（`clientFlags=0`，4 字节），
        `RenderServer::Main` 在开始解码之前会先读它 —— 首次连接从
        `HostConnection::get()` 拿到，重连就得自己发；不发的话渲染器会把第一条
        GL 命令当成 clientFlags 吃掉，或者触发 `IOSTREAM_CLIENT_EXIT_SERVER`
        退出。
      - (A4) `GLConsumer.cpp`（libgui）：两个 `glGetError` 清错循环的上界设为
        8 —— 每次迭代都是一次同步往返。
      - (A5) host `ReadBuffer.cpp`：上限 32 MiB，满了又没有进展就丢弃客户端（旧
        代码会一直翻倍到约 2 GB，把渲染线程搞死）。host `RenderThread.cpp`：每
        个解码器一次最多给一条已声明的消息，帧界定丢失时重新同步，把 12 MiB 的
        滚动流历史 dump 到 `/dev/glr-stream-<pid>.bin`，打印
        `[glr-rt] client pid=` 和 `dropped (getData=)`。需要在 `IOStream` 上加
        `peerPid()`/`shutdownStream()` —— 只加在 host/sdk 副本里，且追加在所有
        已有虚函数之后，这样 guest 的 vtable 槽位不会移位；`SocketStream` 用
        `SO_PEERCRED` + `SHUT_RDWR` 实现它们。poplar 的 bundle 没有附带这两个
        方法。
      - gralloc（`gralloc.maple`）：`lock()` 跳过 `rcColorBufferCacheFlush` 往
        返（host 侧是个空 stub，但它是同步往返，会排在繁重的 GL 工作后面，把
        systemui 的 canvas 绘制堵住 —— 就是记录到的两次 `recvfrom` ANR 之一）。
      - (A2) `glrenderd`：启动时把 `net.core.{r,w}mem_max` 提到 16 MiB，并忽略
        `SIGPIPE`，这样 guest 在应答中途死掉也带不走守护进程。
      - (C2) `InputDispatcher`：解除持续超过 10 s 的派发冻结（WMS 会在窗口切换
        前后冻结派发；如果切换永远完不成，派发器就永久睡下去、UI 什么触摸都收
        不到）；证据在 `/data/system/dispatch-thaw.log`。
      - (B8) 新增 `vendor/sony/maple/lights/`（模块 `lights.maple`）：亮度同时
        写到 `/sys/class/leds/lcd-backlight` 和 `/sys/class/leds/wled` —— 两个
        节点互相独立（实测：写一个不会改变另一个），TWRP 是通过 wled 驱动背光
        的，而 AOSP 的惯例是 lcd-backlight。另外加了
        `TARGET_PROVIDES_LIBLIGHT := true`，并在 PRODUCT_PACKAGES 里加
        `lights.maple`。
      - (B9) 让 `KeyguardServiceDelegate.showScrim()` 变成空操作，并把 scrim
        窗口设为 `FLAG_NOT_TOUCHABLE|FLAG_NOT_FOCUSABLE`，这样即使 keyguard 死
        了也吃不下所有输入（僵尸 scrim 卡死问题）。
      - 补丁：从源码树重新生成 `device-generic-goldfish-glrenderd.patch` 和
        `sdk-glrenderd.patch`；新增
        `frameworks-native-glconsumer-glgeterror-bound.patch`、
        `frameworks-base-input-dispatch-freeze-thaw.patch`、
        `frameworks-base-keyguard-scrim-no-input.patch`。
      在设备上验证（只重启一次）：
      - glrenderd：`rmem_max`/`wmem_max = 16777216`、`doubled fb0 virtual`、
        `listening on @glrenderd`、`[glr-rt] client pid=` 行、一条
        `dropped (getData=-1)` 之后 **6 ms 后**就出现新的 `client pid=`（就地
        重连路径确实被触发），`FRAMING LOST`/`RESYNC` 均为零，整个会话内
        glrenderd 零重启。
      - surfaceflinger：`GLES: Qualcomm, Adreno (TM) 540, OpenGL ES 3.2` —— 经
        glrenderd 走硬件 GL，没有软件回退。
      - navbar 压测（18 次 home/切 app 的 keyevent）：systemui 的 pid 不变，没
        有新的 drops，没有 watchdog/tombstone 活动。
      - lights HAL：`settings put system screen_brightness 200` → 亮屏时两个节
        点都读到 3211，休眠时读到 0 —— 真正的背光控制（在这个 HAL 之前，
        framework 根本碰不到面板）。
      - 已知坑点（本来就存在，只是这次才看得见）：Keyguard 窗口设了
        `userActivityTimeout=10000`（AOSP 的 `AWAKE_INTERVAL_DEFAULT_MS`），所
        以只要这个窗口在，WMS 就把息屏超时压在 10 s —— 闲置约 10 s 后屏幕就黑
        了。它不是卡死；按电源键能唤醒。除非机主觉得烦，否则先不动它。
      - 坑点：设备上的 KitKat toolbox 没有 `head`/`tail`/`sed`/`pidof` —— adb
        一行命令只能用 `grep`/`cat`/`ls`/`ps`。
      - 渲染器重编译规则被遵守：glrenderd 是从产出已部署 `*_enc.so` 的同一棵源
        码树重编译的（codec 表从没改过的 `.in` 文件重新生成）—— 面板起来正常。
- [x] TEST 34（动画性能审计 + socket buffer 修复，2026-10-16）：机主问「硬件加
      速是 100% 吗？有些动画有点卡」。结论：是，各处都是 100% 硬件加速；卡的原
      因是模拟链路里的每帧延迟 —— 没有软件回退，也没有资源被打满。事实与这次收
      紧的地方：
      - 硬件检查：surfaceflinger 的 GL = 「Qualcomm, Adreno (TM) 540, OpenGL
        ES 3.2」，经 glrenderd 提供（哪儿都没有 libagl）；即便在放动画，GPU 也
        待在最小时钟（257 MHz，0–19% 占用）；8 个 CPU 全钉在最高频（governor
        为 `performance`，1.9/2.45 GHz）；没有东西跑飞（UI 闲置时 `top` 显示所
        有进程都是 0%）。
      - 帧路径埋点现在常驻在 glrenderd 里：每第 60 次 present 会紧挨着
        readback/copy/flip 打印 `posts= drops= postgap stage`。postgap = guest
        的帧间隔，drops = 面板没能看到的帧数，stage = 渲染线程 memcpy 进
        presenter 槽的那一段。
      - 每呈现一帧（实测）：readback（glReadPixels）8.7–10.0 ms，stage 1.3–2.7
        ms，copy（presenter 线程，并行）2.5–10.4 ms，flip 0.7–9.6 ms。所有测过
        的窗口里 drops 都是 0 —— present 路径从来不是限制项。
      - 真正的限制是 guest 的帧节奏（postgap）：纯窗口动画约 20 ms/帧（50 fps
        的爆发），需要 app 重绘的帧（锁屏圆环拖动、settings 滑动、launcher 抽
        屉）40–60 ms/帧（17–25 fps），开机动画约 30 fps（它 zip 自身的目标帧率）。
        这期间 CPU 和 GPU 都在闲置 ⇒ 节奏由跨模拟层串行化的同步往返决定（swap
        fence、BufferQueue 交接、socket 往返），不是算力。要再提升流畅度必须针
        对这些同步点（见下面的选项清单）。
      - 修掉了 poplar 文档里写过却从未发布的 socket 限幅：
        `net.core.{r,w}mem_default` 是 **212 992（208 KB）**，而一帧的 GL 命令
        流轻松就有几百 KB —— guest 会在帧中途阻塞在 `send()` 里，与渲染器串行
        化。只调高 `{r,w}mem_max`（TEST 33）还不够：现在两端每条连接都真的
        `setsockopt(8 MiB)` —— host 侧在 `UnixStream::accept()`（tools），
        guest 侧在 `RenderdStream.cpp` 的连接/重连处（`glrSetSocketBuffers`，
        两份 SocketStream.h 副本里都有声明）。启动窗口没有回归（第一个窗口改前
        改后都是 7.2 fps/50.6 ms）；负载噪声把干净的 A/B 对比盖住了（见下一条
        注记）。
      - 测试方法的教训：`input swipe` 连发是个噪声很大的基准（一次报告需要 60
        个呈现在面板上的帧；静止的 UI 永远凑不满 —— 这里几次「no data」其实只
        是屏幕黑着/睡着了）。要用持续动画并读多个窗口，或者直接给 guest 的
        swap 频率加埋点。另外：这个移植上 `screencap` 返回的是一张恒定的白图（截
        屏路径坏了）—— 真相在 `/dev/graphics/fb0`（把 1080×1920 的两页都 dump
        出来，stride 4352 B，按 1088×1920 RGBA 解码再裁到 1080；launcher/锁屏
        的状态就是这么确认的）。锁屏在 (540,1477) 的解锁圆环是个很方便的可重复
        动画源；僵尸 Keyguard 窗口可以在 launcher 可见时仍然持有 FOCUS（触摸仍
        按位置路由，所以屏幕内的 navbar 能用，但 `input keyevent 3` 不行）。
      - 如果还想要更流畅，可选方案（大致按收益排序，都还没做）：(a) 异步/PBO
        双缓冲回读，把 9–10 ms 里的大部分藏到下一帧后面（会多约 1 帧延迟）；
        (b) 直接回读到 presenter 槽（poplar 的 A6），省掉 2 ms 的 stage 和一趟
        8.3 MB 的内存搬运；(c) 给 guest 的 swap/fence 路径加埋点（BufferQueue
        深度、KHR_fence_sync 等待），它看起来才是真正卡 app 帧的关口；(d) 以半
        分辨率呈现，UI 最顺（回读+copy 减半；代价是变糊，由机主决定）。
- [x] TEST 35（poplar A6 + 异步回读试验 + swap 埋点，2026-10-16）：机主说：「还
      是有点卡，特别是 launcher3 和滚动；把 poplar 剩下的 GL 修复和我提的那些
      方案都实现，半分辨率除外」。已完成：
      - **A6 已移植**（poplar GL 里最后缺的一项）：post 回读现在直接落到
        presenter 槽，而不是 FrameBuffer 的 buffer ——
        `FrameBuffer::setPostReadback()` + glrenderd 里的 `present_acquire()`
        + `ColorBuffer::readbackTo()`（文档里「不要回读进 panel page」的警告被
        遵守了：只写槽，绝不碰 fb0）。真机实测：每帧 `stage 0.0 ms`（原来是
        1.3–2.7 ms）；同口径的启动窗口从 9.8 ms 的 readback+stage 降到 8.9 ms，
        而且每帧省掉一整趟 8.3 MB 的内存搬运。测试脚本：每个上报窗口里
        `drops=0`。
      - **异步 PBO 回读已实现，但被实测否掉**：藏在
        `persist.glr.asyncreadback` 后面（运行时可切，不用重启）。同一个抽屉滑
        动激励下的实测结果：**13.1 fps / postgap 76 ms，而同步路径是 31–35 fps
        / 29–32 ms**；SF 的 swap 阻塞时间从 11 ms 跳到 58.6 ms —— PBO 的
        map+copy 比它想藏起来的同步回读还贵（回读的发起确实降到 0.1 ms，但 map
        连本带利还回去了）。默认关闭；管线留着给以后的试验用。
      - **swap 路径埋点**（host 侧，按连接）：一次 window-surface swap 是
        `rcFlushWindowColorBuffer` → queue/dequeue → `rcSetWindowColorBuffer`；
        每 60 次 swap 记录一次这个间隔。在持续激励下实测：surfaceflinger 每帧
        在自己的 swap 里阻塞 **10.7–11.9 ms**（framebuffer buffer 的释放要等上
        一次 post，也就是 host 的回读算在这个数字里），动画期间它的 compose/等
        待间隔是 **17.0–26.4 ms**。这个构建上的持续帧率：**抽屉翻页 31–35
        fps**（postgap 29–32 ms）、**settings 列表滚动 26–28 fps**（postgap
        35–39 ms）；各段耗时：readback 9.1–10.5 ms、presenter copy 5.0–11.7 ms、
        flip 1.1–3.9 ms。app 客户端（launcher、settings）从来不出现在 swap 日
        志里 —— 它们的 swap 应该走的是另一套 op（很可能是 v2 window-surface 路
        径），所以如果要 app 侧的数字，还得在那里也加埋点。
      - **值得记住的测量陷阱**（今天每一条都真的浪费了时间）：(1) fb0 的像素是
        RGBA —— 全零帧是*透明黑*，把它存成 RGBA PNG 看起来会是白的；解码时先加
        `format=rgb24` 再下结论；(2) 最后一次输入之后约 10 s 屏幕就休眠（keyguard
        窗口的 `userActivityTimeout`），而且**触摸唤不醒它** —— 每个测试都必须
        先查 `mScreenOn` 并用 power/menu 键唤醒，否则这个「测试」是在睡着的屏
        幕上跑的；(3) Launcher2 的抽屉会记住标签页，它的 WIDGETS 标签页在这里
        渲染是空白的 —— 先查 `dumpsys activity top`（view flags）再怪管线；(4)
        这个移植上的 `screencap` 返回恒定图像 —— 用 fb0 dump；(5)
        `input keyevent 26` 是开关切换：先看状态，别假设。
      - 给机主的结论：poplar 的 GL 那套现在**全部移植完成（A1–A6）**。UI 动画
        能持续跑到约 26–35 fps；剩下的开销在模拟链路的每帧同步路径上（回读 +
        buffer 释放 ≈ 11 ms，加上 compose/等待 ≈ 18–26 ms）。异步试验说明回读
        没法轻易藏起来；下一批候选（尚未做）是 app 侧 v2-surface op 的埋点和
        guest 的 fence/queue 路径。
- [ ] TEST 36（wifi + audio 打通，2026-10-16，进行中）：机主要求参照
      `reference/CHARQUIRKS.md`（pdx203 的 4.2 移植）来做 wifi 和 audio。先在
      设备上诊断，再改源码树；除标注 LIVE 的之外，下面内容都还没在设备上验证过。
      - LIVE 事实（adb、`maplekk device`、`sys.boot_completed=1`）：audio：
        `/proc/asound/cards` = 「--- no soundcards ---」，`/dev/snd/` 里只有
        `timer`，`dmesg` 显示「No soundcards found」，
        tavil/tasha/wcd/slim/qdsp 的 probe 行一条都没有（只有 TDM DAI 在 probe），
        `/sys/kernel/debug/asoc/{codecs,dais,platforms}` 也是空的 —— machine
        driver 在悄悄 defer。DT 里同时有 `sound-tavil`（`qcom,model=msm8998-tavil-snd-card`，
        真正的那张卡）和 `sound-9335`，两边都带布尔型的 `qcom,wcn-btfm`（0 字
        节属性）和 `qcom,wsa-devs`（16 B）+ `qcom,wsa-max-devs`；codec 挂在
        `slim@171c0000`（tavil_codec/tasha_codec）下，wcn3990 挂在
        `slim@17240000` 下。运行中的内核（`/proc/config.gz`，
        `4.4.302-whatawurst+`，2024 年 11 月）把所有东西都编进去了（`CONFIG_SND_SOC_MSM8998=y`、
        WCD9335+WCD934X、WSA881X、QDSP6V2、APRV2_GLINK、PDR、
        `CONFIG_MSM_SERVICE_LOCATOR=y`、`CONFIG_QCA_CLD_WLAN=y` 内建 ——
        lineage-17.1 defconfig 里的 `=m` 已经过时）。cmdline 上有
        `service_locator.enable=1`；
        `audio_notifer_reg_service: SSR_MODEM is in use`；7 个 msm_subsys（ipa_fws
        venus spss a540_zap adsp slpi modem）全部处于 SYSTEM；
        `/system/vendor/firmware` 里只有 glr 暂存的 a5xx GPU 固件；ADSP 的 PIL
        加载从未被尝试过（只有 5.14 s 时的 a540_zap）。wifi：qca_cld3 内建，驱
        动 v5.1.1.77V 已加载，`/dev/wlan` 为 chr 229,0，
        `/sys/module/wlan/parameters/fwpath` 存在但为空 —— 可是没有 wlan0，没
        有 `/sys/class/ieee80211` phy，`/proc/net/wireless` 为空。
        `wlan.driver.status=unloaded`，supplicant 从未跑过。根因都在 userspace
        （两处都已在源码树里修掉）：(a) `/data/misc/wifi/sockets` 和
        `/data/misc/dhcp` 从未创建（只有 softap.conf 存在）；(b) 任何地方都没
        有定义 `wpa_supplicant` / `p2p_supplicant` / `dhcpcd_*` 服务，所以
        wifi.c 的 `ctl.start wpa_supplicant` 是个静默空操作。
        `lib_driver_cmd_qcwcn` 是静态链接的（被链进 wpa_supplicant —— 它不在
        `/system/lib` 里是对的，不是 bug）。`echo ON > /dev/wlan` 创建不出接口；
        手工跑 wpa_supplicant 因为没有 wiphy 就直接静默退出（得先完成 WLFW/QMI
        固件握手 —— modem 侧 `wlanmdsp.mbn` 在 modem 分区上有，但这里的 modem
        从来没起来过）。modem 分区（vfat 的 `image/`，实测以 ro 挂载）里带
        `adsp.*`、`bdwlan.*`（+`.bin`）、`cpe/wcd`、`slpi_v*`、`venus.*`、
        `wlanmdsp.mbn`；bluetooth 分区带 cherokee BT（`crbtfw*.tlv`/
        `crnv*.bin`）；`/persist/wlan/wlan_mac.bin`（32 B）存在。`dmesg` 里还
        有 `ipa_smmu_wlan_cb_probe: could not alloc iommu domain`（新 ini 里的
        `gIPAConfig=0` 就是因此而来）。
      - 源码树改动（本次改动，编译 + 刷机 + 验证都还没做）：wifi 的
        `init.maple.rc` 加上 sockets/dhcp 目录、两个 supplicant 服务 +
        `dhcpcd_*`（照 hammerhead 的写法，class main —— 没有 mount_all 时
        late_start 永远不会触发），以及 adsp/slpi 的 RELATED 写入（subsys4/5——
        顺序已在设备上验证）；BoardConfig 里 `service_locator.enable=0`（CHARQUIRKS
        的 audio 结论：设成 =1 时那张卡要经 pdr 花约 5 分钟才起来，cmdline 里
        设为 0）；修正了 BoardConfig 里错误的 wifi 注释（WCN3990/cherokee 的
        qca_cld3，不是 BCM43xx —— 由 `/proc/config.gz` + BT tlv 名字证明），并
        记录下 CHARQUIRKS 在 `BOARD_WLAN_DEVICE` 上的分歧（仍保留 qcwcn：
        KitKat 的 driver_nl80211 必须链上这个私有库才能 LINK）；新增
        `vendor/sony/maple/wifi/`（最小化的 `WCNSS_qcom_cfg.ini` 带
        `gIPAConfig=0`，两个 `*_overlay.conf` stub）和
        `vendor/sony/maple/audio/`（`audio_policy.conf`、来自 sony-msm8998 ten
        的 `mixer_paths_tasha.xml`、`audio.primary.maple` 这个 tinyalsa HAL：
        扬声器 = `speaker` + 深缓冲 MM1/pcm0，麦克风 = `handset-mic`/dmic1 +
        MM1/pcm0，DEC7 104（+20 dB，不用 acdb），卡不在时静默安全，另为录音加
        了 `libsrec_jni`）；`scripts/patch-maple-dtb.py` 现在还会剥掉布尔型的
        `qcom,wcn-btfm`（相当于把 CHARQUIRKS 的 `qcom,wcn-bt = <0>` 翻译过来——
        已在真实 blob 上验证：4 个 DTB 全都 -38 B，mdss 修复完好，tavil
        model 完好，可重复执行）。固件 blob（adsp.*、bdwlan.*、wlan_mac.bin）
        刻意不进 git（与内核 blob 相同的「不入库」策略）—— 提取 + 暂存是这个镜
        像启动起来之后的下一步。
      - 后续（需验证，按顺序）：(1) 重刷后看卡是否 probe（`/proc/asound/cards`
        出现 tavil；若仍没有，下一个怀疑对象是 WSA881x 在 defer —— DT 里带着
        wsa-devs/max-devs，却一条 wsa/swr probe 日志都没有）；(2) 通过新 HAL
        测扬声器 + 麦克风；(3) WLFW 固件问题有答案后再走
        `setprop ctl.start wpa_supplicant` 这条路径（可能被 modem 卡住 —— 这个
        移植上 modem 从来不启动，和蜂窝/GPS 是同一堵墙）。
      - 挫折 2026-10-16（同一会话内修掉）：带新 HAL + policy 的第一次启动让
        mediaserver 反复崩溃重启（SIGSEGV fault addr 0，位置
        `AudioFlinger.cpp:1349`，`loadHwModule` → pc 0，共 10 个 tombstone；
        `init.svc.media=restarting`，没有 boot_completed）。根因：HAL 没有给
        `init_check` 赋值（也没有任何 stream getter）—— framework 能碰到的每个
        op 都必须赋值，见新增的实战手册教训。修法：在 `audio_hw.c` 里补齐整张
        ops 表（device + 两个 stream 的 common + out/in 各自的具体项，用
        `-ENOSYS`/中性默认值），与通用 stub 对齐。只重编 HAL + 在线推送。
      - 已验证 2026-10-16（修完之后，只重启一次）：修好的 HAL 在线推送后，
        `sys.boot_completed=1`，`init.svc.media=running`，mediaserver 的 pid
        稳定 5 分钟以上，没有新的 tombstone。`boot.img` 已在设备上验证：
        `/proc/cmdline` 里 `service_locator.enable=0`，4 个 DTB 里的
        `wcn-btfm` 都没了，init 创建了
        `/data/misc/wifi/{sockets,wpa_supplicant.conf,entropy.bin}`。
        `setprop ctl.start wpa_supplicant` 现在能解析了（oneshot 退出后是
        `stopped` —— 之前是空白/未知）；它退出是因为 wlan0 依然不存在（WLFW 握
        手，下一步）。卡还是 `--- no soundcards ---`（内核那条线的工作），
        wlan0 仍然没有（WLFW/modem 的问题）。
      - 跟进 2026-10-16（同一会话，机主反馈：拨号和音量键都没声音，Settings 里
        看不到 Wi-Fi）：两个都在设备上解释了。音频：AudioFlinger 跑的是我们自
        己的 primary output（dumpsys：48000 Hz 输出线程，HAL frame count 1024；
        policy dump 显示的是我们的采样率）—— 链路一路通到 HAL 的静默安全丢弃，
        所以没声音恰好就是缺内核那张卡，没有别的原因。Wi-Fi：
        `/system/etc/permissions` 里一个 feature xml 都没带，于是
        PackageManager 把 Wi-Fi 从 Settings 里藏了起来；补了
        `android.hardware.wifi.xml`（frameworks 源码，一行 PRODUCT_COPY_FILES——
        按 CHARQUIRKS 的处置不加 p2p xml）。推送 + 重启后 feature 被授予，
        整条开关路径都跑通了：`svc wifi enable` → WifiStateMachine 的
        DeviceActiveState → wifi.c → `wpa_supplicant` oneshot 跑起来又退出（没
        有 wlan0）。Settings 现在能看到 Wi-Fi；扫描/连接要等内核接口。
      - TEST 37（SKIP_QMI 实验，2026-10-16）：把 `icnss.quirks=388`（SKIP_QMI
        + defaults）烧进一个测试 boot.img，想绕开 QMI WLFW 握手强行让 HDD
        probe。结果：卡在 Sony logo 反复重启（userspace 之前，内核 panic 那一
        类）—— 通过 TWRP 重刷之前的 boot.img 恢复（`/data/media` 里的
        `boot-test36.img`，设备侧 md5 校验 `c31321cb…`，热重启后回到
        `boot_completed=1`）。教训：这个旁路确实生效（启动时会跑 probe），但没
        有 QMI 提供的初始化设置就崩；要抓 panic 得在整轮循环里保住 pstore（没
        做）。cmdline 标志已在源码树里回退。剩下的 wifi 路径：在 64 位 Lineage
        chroot 里跑 cnss-daemon（真正的 QMI 握手），或者让 modem 启动。
      - TEST 37b（SKIP_QMI + BDF 重测，2026-10-16）：第一次 SKIP_QMI 可能只是
        缺 board data 才崩，所以把 test37 的完整组合都刷了进去 ——
        `system-test37.raw.img`（5 GB，md5 `4b8539ac…`，dd 之后按分区校验过；
        内含 FW_DIR 的接线：adsp.* + cpe_9335.* + bdwlan.* + wlan_mac.bin + 测
        过的 HAL）加上同一个 quirks boot.img。结果：一模一样的反复重启（110 s
        后仍无 adb，两次都这样）。没有 QMI 的初始化设置，SKIP_QMI 不管 BDF 配
        成什么都行不通 —— 已回退，不再重试。恢复待办（机主明天才回来）：TWRP →
        把 `/data/media/boot-test36.img`（`c31321cb…`）dd 到
        `/dev/block/bootdevice/by-name/boot`，重启。test37 的 system 分区保留
        （好事：FW 接线 + HAL 都留在那儿）。这个教训是撞出声的：覆盖正在运行的
        system 分区会把活着的 libc 弄坏（`CANNOT LINK EXECUTABLE ... empty/missing DT_HASH`）——
        推送、校验，然后立刻重启，其间不要再跑任何东西。
      - Audio DSP 卡住（TEST 36 的后续）：tasha 卡已经起来，24 个扬声器控制项
        通过静态编译的 `tone_test`（`tools/tone_test.c`，NDK r21e armv7a，静态
        链接 tinyalsa）验证全部 SET，但播放停在 PREPARED，日志是
        `msm_pcm_playback_copy: wait_event_timeout` —— ADSP 是 ONLINE 却不返回
        任何 buffer。首要嫌疑：音频保护域（这个移植上没有 pd-mapper/adsprpcd；
        Lineage 两个都有，还带 rmt_storage 和 tftp_server）。这次探测没有产生
        新 tombstone（唯一一个新 tombstone 是 toolbox 里 `ls|grep` 的 SIGPIPE，
        已知噪声）。
      - QRTR 结论（2026-10-16，定论）：`/proc/kallsyms` 里 `qrtr` 符号一个都没
        有（阳性对照通过：binder 409、msm_ipc_router 58、qmi_handle 12），
        `/proc/net` 里没有 qrtr，配置里只有遗留的 `CONFIG_IPC_ROUTER` + 内核内
        部 QMI。后果：任何现代 QMI userspace（pd-mapper、cnss-daemon、
        rmt_storage、tftp_server —— Lineage vendor 里全是 64 位 QRTR 客户端）
        在这个内核上都跑不了，chroot 也不行。64 位 chroot 另外还走不通：哪儿都
        没有 `linker64`（APEX payload 是单独发的；`sysmnt/apex` 是空的）。走遗
        留传输确实能用的有：内核 QMI（sysmon-qmi 已在线触达 ADSP SSCTL）、SMD
        FastRPC（`/dev/adsprpc-smd` 存在 —— adsprpcd 的通道）和 PIL。所以音频
        PD 这条路，如果有的话，只能走 adsprpcd-over-SMD 或 HAL 内加载 ACDB（`/dev/msm_audio_cal`
        存在；服务器上暂存了 7.9 MB 的 `maple-fw/acdbdata`），绝不能靠 QRTR 守
        护进程。同一个结论也否掉了 cnss-daemon chroot 的想法 —— wifi 剩下的路
        是 modem 启动或者内核 QRTR 后向移植（各自都是一条独立的线）。

## 打通日志：service locator + pdserve（2026-10-17）

- **TEST 39（service_locator.enable=1，modem 先起，adsp 在 modem 之后）：**
  boot_completed 约 25 s；modem 在约 6 s 时 ONLINE；adsp-boot 在 2 s 后看到
  modem ONLINE，写入 `boot_adsp`；`/proc/asound/cards` 显示
  `msm8998-tasha-snd-card` —— **locator=1 没有带来音频回归**。locator 那 5 个
  卡住的 `pd_locator_work` kworker（audio_pdr、icnss、slimbus、ath10k、+）就是
  那道闸：内核在等一个 SERVREG_LOC（QMI 0x40、vers 1、instance 0x0101）服务器，
  而这个移植上没有任何东西提供它（原厂 64 位的 `pd-mapper` 在 32 位 userspace
  上跑不了，之前「没有 QRTR」的结论依然成立）。
- **pdserve**（`devices/maple/kitkat/pdserve/pdserve.c`，静态 musl armv7，现已
  作为 `pdserve` 进入 `PRODUCT_PACKAGES`）：一个 32 位的 SERVREG_LOC 提供者，
  走 `AF_MSM_IPC`（SOCK_DGRAM，family 27），绑定名字
  `{service=0x40, instance=0x0101}`，并从 modem 分区的 `.jsn` 表（modemuw.jsn、
  modemr.jsn、adspua.jsn、adspr.jsn）读取数据来应答 `GET_DOMAIN_LIST`（消息
  0x21）。设备上验证：`servloc: ... Service locator initialized`，并且内核连上
  了 instance 74（adsp）和 180（modem）的 servreg-notif 服务。modem 自己的 TMS
  是这个服务器的客户端（对 `tms/pdr_enabled`、`tms/pddump_disabled`、
  `kernel/elf_loader`、`wlan/fw`、`avs/audio` 的请求都会到达并被应答）。
- **未解阻塞 —— modem 稳定性：** modem 会触发自己的 err-fatal 中断，并且每约
  41 s 重启一次（`subsys-restart: ... Restart sequence requested for modem`，
  失败原因 `smem_get_entry_no_rlock failed`）。这早于 pdserve（TEST 39 里从
  t=46 s 就能看到），与 locator 无关。后果：WLAN PD 永远起不来（没观察到
  `wlfw`/`wlan0`），因为 modem 的 root PD 在 servreg-notif 注册完成约 3 s 后就
  崩了。怀疑原因：这个移植上没有 rild/keepalive（官方原厂是靠 `vendor.qcrild`
  让 modem 保持活着）；没有 AP 侧的 QMI 客户端，modem 的 watchdog 就会咬。下一
  步是用 64 位 chroot 跑 `vendor/bin/hw/qcrild`（或者一个最小化的 QMI
  keepalive）。在那之前，Wi-Fi 打通代码本身是对的、也确实解开了 PDR 链，但没法
  端到端验证。
- **待修（下一个 boot 镜像）：** `adsp_boot` 不是 oneshot，所以 `adsp-boot.sh`
  每约 5 s 就重跑一次；把它改成 `oneshot`（已在 `init.maple.rc` 里改好）。另外
  把 audio HAL 的修复（`audio/audio_hw.c` 里的 `stop_threshold = INT_MAX`）烤
  进下一个 system 镜像。

## 打通日志：全新镜像上的 GL 可靠性（2026-10-17）

- **TEST 41（机主：「硬件加速 GL 只是有时候能用」—— 要一直全速；2026-10-17）：
  ** 找到并修掉了三个叠加的缺陷，用冷启动加上一轮崩溃/重启压力矩阵验证。
  - **全新镜像丢掉了 chroot 里的空目录，于是 SF 锁死在软件渲染上。** 症状：从
    开机起就个位数 fps，`init.svc.glrenderd=restarting`；dmesg 里
    `hwchroot: bind /dev -> /system/glr/root/dev: No such file or directory`；
    `/dev/block/sde46 /system ext4 ro`。根因：`full_maple.mk` 用
    `find . -type f` + `PRODUCT_COPY_FILES` 来暂存渲染器 chroot，这样带不了
    `stage.py` 会建的那些空目录（`dev`、`proc`、`sys`、`data/...`）；hwchroot
    运行时再 mkdir 就在只读分区上 EROFS 失败，每个 bind 都拿到 ENOENT，
    glrenderd 反复重启，而 surfaceflinger 那个一次性的硬件 vs 软件探测（等 30
    s，结果按进程锁定）就掉到软件渲染器上。修法：`hwchroot` 改为从 `/dev/.glr`
    上一个可写的 tmpfs 骨架来组装 chroot（通用入口 bind，先绑 /dev，再补合成目
    录），而不是在 `<root>` 里 mkdir —— 日志戳是
    `hwchroot: assembled /dev/.glr from /system/glr/root`。冷启动验证（最终
    hwchroot md5 `24adff33…`）：约 4.9 s 组装完成，SF 报告
    `GLES: Qualcomm, Adreno (TM) 540, OpenGL ES 3.2`，开机动画 28–37 fps，
    `posts=60 drops=0` 稳定。
  - **镜像里还带了一个过期的守护进程 —— guest 和 server 两半来自不同构建。**
    `/system/glr/root/glrenderd` 还是 A1–A6 之前的二进制（md5 `c88c3883…`，
    162320 B，统计行里没有 `posts=`），而同一个镜像里的 guest 库是新的（证据：
    `/system/lib/libOpenglSystemCommon.so` 里带着
    `glr-guest: reconnecting to the renderer`、`persist.glr.replytimeout`）——
    可靠性修复做完之后，server 的暂存目录一直没刷新。这个不匹配在使用 5 分钟内
    暴露出约 3 次守护进程崩溃（FORTIFY
    `pthread_mutex_lock called on a destroyed mutex (0xf3ef332c)`；
    `glBindTexture+29` 里的 `signal 11 at 0x20`；经 `glTexSubImage2D` 进到
    `EsxContext::TexImage` 的 `signal 11 at 0x4`），都发生在客户端掉线、面板切
    换前后。修法：用当前源码重编（`tools/glrenderd/build.sh`；md5 `bcb4ab7a…`，
    170668 B），部署，并刷新暂存树，让镜像发出去的两半是同一批。判断跑的是哪个
    守护进程：新构建会打印 `posts=… drops=… postgap … stage …`。验证：做同样的
    压力（启动 settings 并滚动、翻页/划抽屉、熄屏亮屏循环、守护进程停/起折腾）
    → **0 次崩溃**，动画窗口按激励不同在 12–35 fps。
  - **重启过的守护进程会让活着的 surfaceflinger 悬在那里：** 新起的守护进程对
    SF 的窗口对象没有任何 server 侧状态，所以在新实例下 `posts=0`，而 SF 还在
    翻它那些过期的 buffer（guest 的就地重连不会重建窗口对象）。恢复办法是
    `setprop ctl.restart surfaceflinger`（`service_restart`，
    `system/core/init/init.c:400`：running → stop+start，not running → start，
    restarting → 空操作）—— 已验证：SF 的 pid 变了，重新探测到 Adreno，帧恢复。
    这把 init.maple.rc 里「在线 `stop glrenderd` 之后需要重启 surfaceflinger」
    的注记推广到了每一次守护进程死亡。
  - **hwchroot 里自愈（不需要额外的 watchdog 服务）：** /dev 这个 tmpfs 上的一
    个标记文件（`/dev/.glr/ran`）记录「本次启动守护进程已经跑过」；本次启动内
    只要有第 2 次及以后的 hwchroot 运行、并且守护进程二进制存在，hwchroot 就自
    己 fork 出 host 的 `/system/bin/setprop ctl.restart surfaceflinger`，然后
    再 exec 守护进程。冷启动不受影响（第一次运行是 init 从 post-fs-data 里发起
    的）。没有做限频：init 自己的崩溃-重启退避（`time_started + 5`、
    `restart_service_if_needed`、init.c:418）本来就把崩溃循环的周期拉到 ≥5 s，
    而压制自愈反而会让最后活下来的那个实例悬着。设备上验证：
    `stop/start glrenderd` → 自愈 + SF 重新探测 + 帧恢复；对守护进程
    `kill -ABRT` → init 重启 → 自愈（服务一回来 SF 的 pid 就变了）→ 帧恢复；冷
    启动 → **没有**自愈日志行。
    - **做这个时抓到的陷阱：绝不要用「SF 在不在跑？」当重启信号。** 开机时
      post-fs-data 的 `start glrenderd` 在 hwchroot fork 出去后立刻返回，init
      马上就会执行 `on boot` 的 `class_start core` —— SF 的进程只比 glrenderd
      的晚几毫秒出现（第一次尝试把一个才约 10 ms 大的 SF 踢了：「daemon
      restart」在 4.87 s，替换的 SF 到 9.86 s 才起来 = 正好是 5 s 退避；这个竞
      态就是这么发现的）。运行次数标记才是诚实的信号；SF 的 GL 探测要几秒之后
      才发生，那时 glrenderd 已经在监听了。
  - 运维笔记（每条都花了一次启动周期）：替换 `/system/glr/hwchroot` 直接 push
    即可（运行中的进程镜像是 `/glrenderd`）；替换 `/system/glr/root/glrenderd`
    会碰上 `Text file busy`，必须先 `stop glrenderd` —— stop → cp → chmod 755
    → `sync` → 重新挂载 ro → `start`。验证部署上去的身份要用 md5，不要用时间戳。
