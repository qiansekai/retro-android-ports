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
- Donut adbd 的 shell 使用 **/dev/ptmx**（`grantpt`/`unlockpt`）；当 pty 设置出问题时，每个 shell 都零诊断地挂住，而 sync（pull/push）照常工作。替代方案：在 `create_subprocess` 里改用分离管道（这个时代的 bionic **没有 `socketpair()`**——用两个 `pipe()`，并让 poll 循环认识这对分离的 fd）；见 `patches/donut/system-core.patch`。
- Donut 的 vold 遇到陌生 uevent 会**崩溃重启（SIGSEGV，NULL devpath）**，并在 `EEXIST` 上反复重试 `mknod`，占满一个核并淹没 logcat。给 NULL 加保护 + 把 EEXIST 当成功，或者暂时不用 vold，等重新处理 SD 支持再说。
- `rild` 缺少它的专有 RIL `.so` 会崩溃重启，并把依赖它的服务一起拖下水——如果你没有 Donut 的 RIL 库，就把该服务注释掉。
- 如果你需要一个年代正确的 adb 客户端，`system/core/adb` 的宿主机工具在 chroot 里能正常构建。
