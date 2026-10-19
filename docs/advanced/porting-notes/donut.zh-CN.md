# 移植笔记：Donut 1.6 在新硬件上

> 中文译文。英文原文见 [donut.md](donut.md)。技术名词、代码、路径、命令与日志一律保留原文。

本实战手册提炼自在现代 Arch 宿主机上把 AOSP Donut（`android-1.6_r2`，DRD35）跑在三星 Galaxy Ace GT-S5830（`cooper`，2011，MSM7227）上的过程。下面所有内容适用于任何在 2009 年之后的硬件上构建/运行 Donut 的尝试；cooper 专属事实见 [cooper 怪癖](../../devices/cooper/quirks.zh-CN.md)，分步构建见 [build/donut.md](../build/donut.zh-CN.md)。KitKat 时代的差异（4.4.4 在新硬件上，例如 maple）见 [porting-notes/kitkat.md](kitkat.zh-CN.md)。返回[进阶索引](../README.zh-CN.md)。

## 源码与工具链
- **Cupcake 已从 AOSP 中消失。** `platform/manifest` 里已没有 `cupcake` / `android-1.5` 分支，只剩 `android-1.6_r1…` 及更晚的，所以 `repo init -b cupcake` 不可能成功，Donut 是你还能 checkout 的最老的版本。（这就是项目从 Donut 起步的原因；自定义 1.5 构建不在范围内。）
- **Donut 在 2009 年之后的硬件上天然合适。** 它构建 `armeabi`（armv5te），可在 cooper 的 MSM7227 这类 ARMv6 SoC 上运行；它的 HVGA 时代 UI 与 2010–2012 年 320×480 级别的手机相匹配，使这些机器成为更多 Donut 移植的良好候选池。
- **Java 5 是强制要求**（`build/core/main.mk` 会 grep 1.5）。现代 JDK 连把 1.5 字节码当作目标都做不到。唯一可行的路线：同年代的 chroot。
- **宿主 GCC 太新**，不适合 Donut 的宿主机工具（`apriori` 等在 GCC 16 下因 `-Wincompatible-pointer-types` 报错退出）。答案相同：chroot。
- 我们这套可用的配方：从 `old-releases.ubuntu.com` 执行 `debootstrap --arch=i386 hardy`，加 Sun `sun-java5-jdk`（1.5.0_15）+ GCC 4.2.3 + Make 3.81 + Python 2.5。Donut 的 ARM 工具链（`arm-eabi-4.2.1`，32 位）只要补上 32 位 loader 库，在 64 位宿主上跑得很好。

## Chroot 坑点（现代宿主上的 Hardy）
- 现代 debootstrap 会先试 `InRelease`（Hardy 没有，返回 404），然后回退到 `Release`——给它时间，并限制 `wget` 的重试/超时，因为某些 `old-releases` 端点会黑洞（否则会卡 20 秒以上）。
- 下载卡住时**钉死一个可用端点**（我们在 chroot 内通过 `/etc/hosts` + `nsswitch.conf → hosts: files` 使用 `185.125.190.37`）。
- **老掉牙的 apt 对新版 Apache：** 禁用流水线（`Acquire::http::Pipeline-Depth "0"`），否则索引抓取会损坏。
- **`sudo` 的 `secure_path` 不含 `/bin`**，于是 chroot 内的 apt 无法执行 `/bin/bzip2`/`/bin/gzip`/`/bin/tar` → 每个 `.bz2` 索引都以「sub-process bzip2 returned an error code」失败。始终用显式包含 `/bin:/sbin` 的 `PATH` 调用 chroot 命令，或把工具软链到 `/usr/bin`。
- Sun Java 5 需要预先接受许可：为 `sun-java5-bin/-jre/-jdk` 执行 `debconf-set-selections`，写入 `shared/accepted-sun-dlj-v1-1 boolean true`，然后 `apt-get -f install`。
- 除非确有必要，**不要**在 `linux32` 下运行 debootstrap/mkbootimg 那类命令；在 x86_64 上直接用 `chroot`/`sudo chroot` 即可。

## Donut 构建系统的意外之处
- `TARGET_BOARD_PLATFORM := msm7k` 会拖进 Dream 时代的 `hardware/msm7k` HAL（`libcamera2` 等），这些 HAL 需要 **Donut 的 bionic 里没有的专有相机头文件** → 用 `USE_CAMERA_STUB := true`，最好再用你自己的平台名，让它们一个都不构建；音频用通用实现（`HAVE_HTC_AUDIO_DRIVER`、`BOARD_USES_GENERIC_AUDIO`）。
- `BOARD_GPS_LIBRARIES := libloc_api` 会链接一个 Gingerbread 时代的专有库，而 Donut 没有对应构建规则（`No rule to make target ... libloc_api.so`）→ 保持不设置即可（通用 `gps.cpp` 会构建）。
- `packages/providers/CalendarProvider/tests` 需要专有的 `com.google.android.googlelogin`（vendor/google，不在 AOSP 里）→ 提供一个很小的 `vendor/googlelogin` stub java 库，并在该测试的 `LOCAL_JAVA_LIBRARIES` 里加一行（见 `patches/donut/`）。
- **`frameworks/base/preloaded-classes` 里列了专有的 `com.google.common.*` / `com.google.masf.*`**（GTalk 时代）。在开启 adb 的 eng 构建上，`ZygoteInit` 抛 `IllegalStateException: Missing class(es) for preloading`，并且 **zygote 会无限崩溃重启**（实测 61 次重启，load ~5）。修法：删掉这些行（保留那两条能解析到的 `io.protocol.ProtoBuf*`）。logcat 里的症状：类清单原样打印。
- chroot 里缺 `unzip` 会**静默地**破坏宿主端的 java 库合并（随后 `layoutlib_create` 以 `NoClassDefFoundError: org/objectweb/asm/...` 死掉）。装上它。
- `mkbootimg` 把 pagesize 硬编码为 2048，**并且**硬编码了一个 2048 字节的填充缓冲——更大的 pagesize 会损坏输出。打补丁加上 `--pagesize` + 一个 8K 缓冲（`patches/donut/mkbootimg-pagesize.patch`）。
- Donut 的 `make` **不会**跟踪 `BoardConfig.mk` 里的开关变化：改动例如 `BOARD_USES_GENERIC_AUDIO` 不会重建任何消费该开关的产物（`libaudiointerface`/`libaudioflinger` 仍是旧的——我们发布过一整个构建，其中新的 `libaudio.so` 静态链接的是旧的 GENERIC_AUDIO `AudioHardwareInterface.o`，于是它静默地继续用 `/dev/eac` → stub）。改动开关后，用 `rm -rf` 删掉受影响的 `out/target/product/<device>/obj/{STATIC_LIBRARIES/libaudiointerface_intermediates,SHARED_LIBRARIES/{libaudio,libaudioflinger}_intermediates}` 并重建；验证结果（`AudioHardwareInterface.o` 必须引用 `createAudioHardware`，`libaudioflinger.so` 必须引用 `libaudio.so` 而不是 `/dev/eac`）。
- 把 `lunch` 的输出接管道，它的 export 就丢了：`lunch full_cooper-eng 2>&1 | tail` 会在**子 shell** 里跑 lunch，于是接下来的 `make` 会毫无报错地构建 `generic`。改成重定向到文件再 `cat`。

## Donut init 的限制（对照 CWM 时代的记忆）
- `mount` 只接受 **3 个参数**（`type location mountpoint`）；**没有 `wait` 标志**（被静默忽略），没有 `on fs` 触发器（死代码），`exec` 是未实现的 stub（返回 -1）。
- `format()` 只接受 **2 个参数**，且只认 `MTD`——别的都会中止脚本。非 MTD 设备上无法从 Edify 做 ext4 格式化；改用 recovery UI 擦除。
- `write_raw_image(file, partition)` 把分区当作 **MTD 名字**处理；别的都会中止。我们给自己那份打了补丁，加了裸块设备回退（见 `patches/donut/bootable-recovery.patch`），但优先用平台工具。
- Donut **没有 `run_program`**（Eclair 才加入）。我们回移了一个约 30 行的 `fork`/`execv`/`waitpid` 版本，失败时返回 `""`，好让 assert 能工作。
- `TARGET_PROVIDES_INIT_RC := true` 允许设备自带 ramdisk `init.rc`（否则 `system/core/rootdir/init.rc` 生效）。
- init.rc 各段内的 `import` 在 Donut 里是**空操作**（do_import 返回 -1）。机器专属的 `/init.<hardware>.rc` **会**被解析——硬件名转小写，并**在第一个空格处截断**（`GT-S5830 Board` → `gt-s5830`），`init.gt-s5830.rc` 就是这么被加载的。
- `package_extract_dir` 是 FILES_ONLY：zip 里的符号链接会被解成极小的文本文件。把符号链接作为真正的 symlink 条目发出去，配上显式的 `symlink()` 命令（Donut 自己的 `ota_from_target_files` 就是这个模式）。
- Donut 的 EGL **忽略 `egl.cfg`**（硬编码 `libagl.so` 软件 + `libhgl.so` 硬件，失败则回退软件）。**没有 gralloc HAL 这个概念**（surfaceflinger 直接驱动 framebuffer）。

## 现代内核上的 Donut 用户空间
- Donut adbd 的 shell 使用 **/dev/ptmx**（`grantpt`/`unlockpt`）；当 pty 设置出问题时，每个 shell 都零诊断地挂住，而 sync（pull/push）照常工作。替代方案：在 `create_subprocess` 里改用分离管道（这个时代的 bionic **没有 `socketpair()`**——用两个 `pipe()`，并让 poll 循环认识这对分离的 fd）。
- **在管道改造之后 `adb shell <cmd>` 仍可能永久挂住：服务参数是一处 stack-use-after-return。** `service_to_fd("shell:…")` 在自己的栈上构造 `const char* args[2]`，并把指针传给 `create_service_thread()`，而后者在*新*线程里跑服务；等线程去读 `args` 时那个栈帧早就没了，于是子进程被当作裸 `/system/bin/sh` exec，没有 `-c`——它*交互式*启动，阻塞在 stdin 的 `read(0)` 上，宿主于是一直等一个永远不来的载荷（症状：客户端 trace 在发出 `shell:<cmd>` 之后立刻显示 `OKAY`，然后什么都没有；`sync:` 的 pull/push 正常，因为它们传的是 `NULL`）。即使没有一个能用的 shell 也能从设备侧诊断：`adb pull /proc/<pid>/cmdline`（只显示 `/system/bin/sh\0`）、`/proc/<pid>/wchan`（`pipe_read`）和 `/proc/<pid>/syscall`（`3 …` = `read(0)`），其中 `<pid>` 可以在一个长 `adb shell sleep 60` 打开着的时候从 bootlog 的进程快照里找到。修法：在 `service_to_fd` 里 `strdup()` 命令，在 `shell_service` 里构造 `-c <cmd>`，子进程退出时 `free()`。同样的潜伏 bug 存在于 `reboot:`（参数指向 OPEN 包，传输结束即被释放）——那里也要 strdup。见 `patches/donut/system-core.patch`。
- Donut 的 vold 遇到陌生 uevent 会**崩溃重启（SIGSEGV，NULL devpath）**，并在 `EEXIST` 上反复重试 `mknod`，占满一个核并淹没 logcat。给 NULL 加保护 + 把 EEXIST 当成功，或者暂时不用 vold，等重新处理 SD 支持再说。
- `rild` 缺少它的专有 RIL `.so` 会崩溃重启，并把依赖它的服务一起拖下水——如果你没有 Donut 的 RIL 库，就把该服务注释掉。
- 如果你需要一个年代正确的 adb 客户端，`system/core/adb` 的宿主机工具在 chroot 里能正常构建。
- **现代内核上的 configfs USB gadget 绑定：只 bind，永不 unbind。** `ffs` 的 UDC 属性写入只有在用户空间侧已经把描述符 + 字符串写进 ep0 之后才会成功；在那之前内核会打 `configfs-gadget …: failed to start g1: -19`，写入失败。bind 是*异步*的——写入会在 gadget 真正启动（`~0.4 s` 后）之前就返回（甚至 `rc=0`），所以同一瞬间回读 UDC 是空的。因此维护循环必须在 UDC 读空时轮询并重新 bind，但绝不往它写 `""`：unbind 一个活着的 gadget 会断掉到宿主机的 USB 链路，而 unbind/rebind 循环会让宿主端口反复跳变，直到 QCOM dwc3 PHY 卡死（宿主日志每个周期都是 connect/disconnect；手机需要断电重启）。还要记住：关闭 ffs 实例（adbd 退出/断开——旧 adbd 构建会关 ep0）本身就是一次 unbind，所以 rebind 循环必须活过整个启动过程。给 adbd 约 12 秒去写描述符 + 字符串（更早的写入会以 `-19` 失败，无害但吵），然后就每隔几秒重试一次写入：对一个已绑定 UDC 的冗余写入会被 `-EBUSY` 拒绝，所以这个循环根本不需要「就绪」门——尤其不需要轮询 `ep1` 是否存在（在 maple 上试过并放弃；那次「没有 USB」的启动完全是另一个原因，见下面那条 shell）。如果循环只该在未绑定时 bind，注意未绑定状态下的 UDC 属性恰好是一个 `"\n"` 字节——但这个判断需要一个条件语句能正常工作的 shell，而 **Donut 自带的 shell 没有 `[`**（下一条）。maple 上 2026-10-18 验证可用的配方：用一个只含一个换行的参考文件，`cmp $UDC /cache/usbudc-unbound >/dev/null 2>&1 && echo a800000.dwc3 > $UDC`。实现 + 证据：maple [怪癖](../../devices/maple/quirks.zh-CN.md) TEST 42。
- **Donut 的 `/system/bin/sh` 没有 `[` / `test`——既不是内建，也没有对应二进制。** 每个 `[ … ]` 都打印 `[: not found`、返回非零，条件于是静默地走 **else** 分支；一个 `while [ $i -lt 600 ]` 执行零次迭代。一次打通脚本把它的 configfs UDC 写入门控在 `[ -z "$(cat $UDC)" ]` 上，结果整个启动都没绑上 gadget，一次开机全程没有 USB，而它所有的日志行看起来都人畜无害（maple，2026-10-18；从 TWRP chroot 进 Donut 的 `/system`、用 Donut 自己的 shell 跑发布出去的脚本才找到）。用同样方法验证过**可用**的：`while/until/if/case`、`break`、`&&`、`||`、`!`、`{ }`、`$( )`、`$(( ))`（含 `%`）、重定向和注释，全都由*命令退出状态*驱动；toolbox 的 `cmp`（没有 `-s`）是常用的 test 替身，例如 `cmp a b >/dev/null 2>&1 && …`。`/system/bin` 里同样缺的：`grep`、`sed`、`awk`、`tr`、`head`、`tail`、`wc`、`pidof`；`echo` 是内建（`sleep`、`cat`、`ls`、`cmp`、`kill`、`ps`、`date`、`dd`、`sync`、`reboot`、`getprop` 都在），而且**没有 `/tmp`**——临时文件写到 `/cache` 或 `/data`。
- **FunctionFS 的 magic 值是按内核树而定的，不是按内核版本。** 本移植的 adbd 用硬定义常量写描述符/字符串 blob（Donut 的 bionic 没有 `<linux/usb/functionfs.h>`）。在一个 uapi 还带着远古 enum 的内核上（`DESCRIPTORS_MAGIC = 1`、`STRINGS_MAGIC = 2`、`DESCRIPTORS_MAGIC_V2 = 3`——whatawurst msm8998 4.4 就是这样）挑现代的 `0x502`/`0x503`，会让 `write(ep0)` 返回 `-EINVAL` 且没有任何别的症状：adbd 永远在写描述符，`desc_ready` 永不上位，UDC bind 持续失败 `-19`，而 kmsg 里什么都不解释。内核自己的 f_fs QCOM IPC 日志（`/sys/kernel/debug/ipc_logging/f_fs/log`）会显示 `__ffs_data_got_descs: exit: ret -22` 且没有任何 `ffs_do_descs` 行，这就把拒绝钉在头部检查（长度或 magic）上。永远先读目标内核的 `include/uapi/linux/usb/functionfs.h`，或者从那个内核上已知可用的 blob 里取这些值（TWRP 的 adbd 把它们放在 `.rodata` 里）。完整配方 + 一个不需要重启的实机测试装置：maple [怪癖](../../devices/maple/quirks.zh-CN.md) TEST 42。

## 弱序（多核）SoC 上的 ARM 原子操作
- **Donut 的 bionic `__atomic_*` 丢掉了 kuser helpers 的完整内存屏障。** `bionic/libc/arch-arm/bionic/atomics_arm.S` 用 LDREX/STREX 重新实现 `__atomic_cmpxchg/inc/dec/swap`，却漏掉了原始 kuser helpers 提供的 `dmb`。`cutils/atomic.h` 记录了这个契约（「所有在 android_atomic_* 操作之前发出的读或写，保证在该原子操作发生之前完成」= 完整屏障）。在弱序多核 SoC 上（MSM8998 的 Cortex-A73 跑 AArch32 兼容模式）这会破坏 pthread mutex（bionic pthread.c）和 libutils `futex_mutex`（两者都调 `__atomic_*`）的互斥，在竞争下腐蚀 native 堆（GC 期间在 `mspace_free` 里 abort）。症状：多线程进程（system_server、acore）以堆损坏崩溃重启；用 `msptest 3`（4 线程 × 100 万次迭代）即可复现 = SIGSEGV rc=139。修法：在四个 `__atomic_*` 里的每个 LDREX/STREX 前后加 `dmb sy`（`.word 0xf57ff05f`）；同时把 libcutils 的 `android_atomic_swap`（仅存的那处裸 `swp`）改写成 LDREX/STREX+dmb。已验证：修复后 msptest 3/4 在两个内核上都 PASS；无屏障的基线则 SIGSEGV。
- **ARMv8 上 `swp` 没了；kuser helpers 还在。** 在这个 4.4 内核上 `CONFIG_KUSER_HELPERS=y` 且 `CONFIG_COMPAT=y`，所以 kuser 页（0xffff0000，version 5）是映射着的，基于 kuser 的 `android_atomic_*`（libcutils）全部通过一致性测试。`CONFIG_SWP_EMULATION=y` 意味着 `swp` 是模拟的、不致命——早先那个「kuser/页陷阱」的理论是错的；真正的原因是缺失的屏障。用 LDREX 重新实现 swap 既去掉了模拟开销，也去掉了对 `swp` 的依赖。
- **复现器：** `external/msptest/msptest.c` 的模式 0–4（模式 3 猛打、模式 4 一致性测试）。用 `scripts/build-maple-donut.sh msptest` 构建。在 TWRP/Donut 下调用：`LD_LIBRARY_PATH=/system/lib /data/msptest <mode>`。推到 `/data/msptest`（`/dev/block/sde46` 的 rw 重挂）。

## 等待用户空间握手的触摸屏
- 有些现代面板驱动 i2c probe 完成后停在一个驻留状态，在用户空间戳某个 sysfs 属性之前什么都不发——这不是故障，是契约。在 maple 上 Synaptics clearpad 驱动在 dmesg 里直说了（`post_probe_start sysfs is required to start post probe`），并保持沉默（无 IRQ、无事件），直到把 `1` 写进 `/sys/devices/virtual/input/clearpad/post_probe_start`。症状与坏掉的转发无法区分：对面向框架的节点*和*真实节点 `getevent` 都什么都不显示，框架照样接受这个设备（class 对、ABS 范围对——EventHub 的一次性扫描只看这些），而且哪里都不报错。
- **先读设备自己的 sysfs 属性。** 厂商的一次性属性（`post_probe_start`、`enabled`、`fwstate`）就是驱动在宣告这个握手；`ls /sys/devices/virtual/input/<name>/` 只是一条命令。通过 input class 的符号链接去访问（`.../input/clearpad/...`），不要用 `inputN/`——那个编号取决于 probe 顺序。
- **recovery 的 ramdisk 记录了厂商的用户空间契约。** 触摸屏在同一个内核的 TWRP 里能用，所以 recovery 镜像里一定带着缺的那一块：TWRP 的 `/init.recovery.maple.rc` 在 `on post-fs` 里恰有一行 `write /sys/devices/virtual/input/clearpad/post_probe_start 1`（"filesystem is available for fwflash"）。反编译任何东西之前先 grep recovery 的 `/init*.rc`。
- 触发器的*可用性*与版本有关：Donut 1.6 的 init 根本没有 `post-fs`/`post-fs-data` 触发器，而驱动的 sysfs 节点可能出现在 init 的 `on boot` 块之后（maple 上节点在约 2.9 s 内核时间），所以一次性的 `write` 会静默地抢跑。把这个戳放进一个本来就必须存在的服务里，并给它一个有界重试循环（maple：`vtouch`，在虚拟节点替换之后、在转发循环之前，这样 system_server 的一次性输入扫描仍能看到它——写入之前不可能有事件到达，所以这个等待零成本）。
- 值得复用的诊断顺序：对真实节点和面向框架的节点各跑一次 `getevent` → 看 `dmesg` 里的驱动状态消息 → 列 sysfs 属性 → 运行时写那个可疑属性，再观察 dmesg + `getevent`（maple：戳完之后 5800 条原始 MT protocol-A 事件、1571 条翻译后事件）。

## 等待缺失的用户空间 helper 的固件加载

- 在启用了 `CONFIG_FW_LOADER_USER_HELPER`（或 Android 回退路径）的内核上，`request_firmware()` 先按 `firmware_class.path` / `/lib/firmware` 做一次直接的文件系统查找，失败就发一个 uevent 并等用户空间 loader 把文件写进 `/sys/class/firmware/<name>/...`。Donut 1.6 没有这样的 loader（ueventd 不处理固件），于是这个等待总是跑满整个超时（默认 60 秒）并返回 `-EAGAIN`（rc=-11）。因此一个重试 N 次的驱动会在放弃前卡 `N * 60 s`。
- maple（clearpad）上的症状：post-probe 的「确保固件」步骤调 `request_firmware(touch_module_id_0xd1.img)` 三次；触摸要到启动后约 184 秒才活过来（`end post probe @ 183.759 (rc=0)`）。锁屏早就出来了，所以看上去像「锁屏显示之后触摸开始工作了」——其实不是；那是个计时器。
- 旋钮：等待长度是 class 属性 `/sys/class/firmware/timeout`（默认 60，单位秒）——注意它是*class* 属性，不是模块参数（这个内核上 `/sys/module/firmware_class/parameters/` 只有 `path`）。写 `1` 能让每次尝试约 1 秒就失败。在驱动的第一次请求之前设好它（maple：`vtouch` 在 `start_post_probe()` 里第一件事就写它，先于写 `post_probe_start`）。
- 如果固件文件本身可得（TWRP 的 recovery ramdisk，或官方原厂 `/system/etc/firmware` 里的副本），直接查找就会成功、回退路径永远不跑——但提供一个错的文件有刷坏面板的风险；快速失败路径是安全的默认。不要从一个设备上把 TWRP 与 Donut 的时序差异普遍化，先查清各自跑的是哪个内核（maple：TWRP 4.4.263 vs Donut 4.4.302）。

## 出厂即不可读（mode 0640）的按键字符映射

- Donut 的宿主工具 `build/tools/kcm/kcm` 用 `open(..., O_RDWR|O_CREAT|O_TRUNC, 0660)` 创建 `.kcm.bin` 文件。构建的 umask（022）把它们留成 0640（`root:root`，他人不可读），于是 app 进程（uid `app_*`）打不开。`KeyCharacterMap::load()` 返回 NULL，native JNI 路径直接解引用它 → 任何加载按键字符映射的 app 都在 `libui.so` 里 SIGSEGV（fault addr 4）（Settings、Donut 上的 Launcher——Donut 上 Launcher 跑在 `android.process.acore` 里）。
- 修法：在 `kcm.cpp` 里 `fchmod(out, 0644)`（单靠 creat 的 mode 会被 umask 掩掉），记录为 `patches/donut/build-kcm-file-mode.patch`（在 `aosp-donut/build` 里应用）；maple 的打包脚本还会把 `*.kcm.bin` 归一成 0644 作为双保险。`.kl` 和 `.idc` 文件本来就是 0644，从未受影响。
- 验证配方：`W/KeyCharacterMap: Can't open keycharmap file ...`，随后 `E/KeyCharacterMap: Can't find any keycharmaps (also tried .../qwerty.kcm.bin)`，然后是 `I/DEBUG: signal 11 ... fault addr 00000004` 与 `#00 pc ... /system/lib/libui.so`。

## 带翻盖磁传感器的硬件上的显示方向

- Donut 的 `PhoneWindowManager.rotationForOrientationLw` 把 `mLidOpen`（SW_LID == 0）当成滑盖键盘被打开，并在未指定方向的情形下返回 `ROTATION_90`（landscape）。一台带翻盖霍尔传感器的手机（maple：bu520x1nvx，SW_LID）在没有装翻盖时也上报「open」，于是整个 UI 在竖屏面板上以横屏起来。framebuffer 本身已经是竖屏（1080x1920）；错的只是策略。
- 修法：用 `!KEYBOARD_ALWAYS_HIDDEN` 守住 lid-open 分支，并对没有滑盖键盘的设备（maple）设 `KEYBOARD_ALWAYS_HIDDEN = true`。记录为 `patches/donut/frameworks-policies-orientation.patch`。自动旋转还需要一个能工作的 sensor HAL（`sensors.maple.so`），本移植还没有，所以方向固定保持竖屏。

## 没有 MENU 键的硬件上的 keyguard
- Android 1.6 的非安全 keyguard *只*在 `KEYCODE_MENU` 上解锁（`LockScreen.onKeyDown` → `mCallback.goToUnlockScreen()` → `keyguardDone(true)`）；平台假设的是 G1 那类导航行里带 MENU 键的硬件。现代手机一个都没有——而且 Donut 早于 action bar，所以 app 菜单也需要 MENU。
- 两个独立的修法，都很小：(1) 在设备按键布局里把某个空闲硬件键重映射为 MENU（maple：两段式相机快门，全按 766 → `MENU WAKE_DROPPED`；半按不要动——全按同时也会发出半按的码，把两者都映射到 MENU 会让每次按下触发两次，把刚打开的菜单又关掉）。半按（528）后来改作 `BACK` 用于 app 内导航（不带 wake 标志），因为点按解锁让「用快门当 MENU」不再是解锁所必需；代价是放弃了半按的相机自动对焦；(2) 触摸解锁——覆写 `LockScreen.onTouchEvent` 并在 ACTION_DOWN 上调用同一个 `goToUnlockScreen()`，这样安全 keyguard 仍会走它自己的 `UnlockScreen`，并把 `lockscreen_instructions_when_pattern_*` 字符串从「Press Menu to unlock.」改成「Tap to unlock.」。keyguard 窗口是可触摸的（`KeyguardViewManager`：TYPE_KEYGUARD，带 FLAG_FORCE_NOT_FULLSCREEN / 可选的 FLAG_ALT_FOCUSABLE_IM——没有 FLAG_NOT_TOUCHABLE），并且只有紧急拨号按钮消费触摸，所以在它之外的点击会落到 LockScreen 视图上。
- **SIM 缺失锁屏在无射频的移植上是死路。** `LockPatternKeyguardView.stuckOnLockScreenBecauseSimMissing()`（`mRequiresSim && !isDeviceProvisioned() && simState == ABSENT`）和 PUK_REQUIRED 都会让 `goToUnlockScreen()` 变成空操作，于是 MENU 和点按都解不开任何东西。`mRequiresSim` 为 false 当且仅当属性 `keyguard.no_require_sim` 被设置——把它放进移植的 `system.prop`（maple 还设了 `DEVICE_PROVISIONED=1`）。
- 布局 token 的坑：键名会对 `frameworks/base/include/ui/KeycodeLabels.h` 校验，未知 token 会让 `KeyLayoutMap` 丢弃整个文件——发布之前先在那里核对名字；代码改动住在 policies 项目，而提示字符串住在 `frameworks/base` 的 core 资源里，所以记成两个 patch。
- 验证配方：用 `getevent` 找一个键的扫描码（不带设备参数会 dump 所有节点——按下键，看哪个 eventN 亮）；框架侧解锁成功的标志是 logcat 里的 `keyguardDone(true)`。
