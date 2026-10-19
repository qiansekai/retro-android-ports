# libhyb —— 在 KitKat 进程内运行较新的 Adreno 540 驱动

> 中文译文。英文原文见 [libhyb.md](libhyb.md)。技术名词、代码、路径、命令与日志一律保留原文。

`libhyb` **让较新的 GPU 驱动在旧版 Android 上以进程内方式运行**。在 maple
（MSM8998，Adreno 540）上，KitKat 根本没有 EGL 驱动，于是由一个 32 位 ELF loader
把 LineageOS 22.1（Android 15）的 vendor closure —— Adreno 540 驱动、QTI
gralloc1、各项依赖 —— 载入每一个 KitKat 进程，再由 64 位 `fbpresentd`
通过一次 MDSS atomic commit 把 SurfaceFlinger 的缓冲送上屏。它
取代了 glrenderd 的设计（把 GL 经套接字流式送入一个 Lineage
chroot），该设计已被删除：驱动现在跑在调用它的进程之内。
同一个 loader 在 maple 上还承载了第二个、与之无关的消费者：Android 15
**ACDB 音频校准 loader**（`libacdbloader.so`），由 `audio.primary.maple`
载入，把调音数据交给 dsp（见下文）。

移植自 [DoomGuy41/Taimen-KitKat](https://github.com/DoomGuy41/Taimen-KitKat)
（Pixel 2 XL，同一 SoC 家族），并先在 maple 落地 —— 其余每个 Taimen 补丁的处置
（已采用 / 已跳过 / 已排队）见
[taimen-kitkat 对照](../taimen-kitkat-mapping.zh-CN.md)。源码：
[`devices/maple/kitkat/{hyb,egl,gralloc,fbpresentd}/`](../../../devices/maple/kitkat/)；
暂存工具：[`tools/libhyb/`](../../../tools/libhyb/)；AOSP 侧补丁是
[`patches/kitkat/`](../../../patches/kitkat/README.zh-CN.md) 里那张表。实战教训见
[KitKat 移植笔记](../porting-notes/kitkat.zh-CN.md)、[maple 怪癖](../../devices/maple/quirks.zh-CN.md)。

**状态：2026-10-18 构建完成，2026-10-19 刷机并在硬件上验证**
（冷启动，附 md5 回读；文末的检查清单记录了测了什么、怎么测的）。
仍标着 `verify-me` 的内容来自 Taimen
移植或与源码的交叉核对，而不是 maple 硬件。

## 为什么改成进程内

- KitKat 比 Adreno 540 早三年；这个发行版没有可用的 vendor 驱动。
  `libagl` 是软件实现，且仅支持 ES1 —— 任何 ES2 客户端（SystemUI 动态
  壁纸、hwui 应用）都找不到 config 而挂掉（`eglConfig not initialized`）。
- glrenderd 用一个 chroot + `@glrenderd` 套接字绕过了 ABI 缺口：每次
  GL 调用都是一次往返，guest 跑的是模拟器的 GL 栈（emugl 线格式
  携带 32 位指针），呈现需要 `glReadPixels`（1080p 每帧约 9–10 ms），
  UI 被卡在约 26–35 fps。它还带来一条规矩 ——
  绝不出现两个翻转者 —— 那条规矩约束了其余一切。
- KitKat 与 Android 15 之间的 C 层 EGL/GLES ABI 是稳定的；不同的是
  **bionic**（少数几个较新的 libc 符号）以及**缓冲 / handle
  格式**。loader 与 hooks 把这两者都覆盖了，于是可以直接调用驱动
  真正的入口点。没有传输层、没有回读、没有 chroot，除 gralloc 自带的 fb HAL
  之外也没有第二个翻转者。

## 架构

- **Loader**（`hyb/linker.c`）：面向较新 Android 库的 ARM 32 位 ELF loader。
  `HYB_ROOT` 是 `/system/a15`（[`hyb/hyb.h`](../../../devices/maple/kitkat/hyb/hyb.h)；
  Taimen 把 `/system/a11` 写死 —— 在这里只是一个宏）。它处理 PT_LOAD +
  PT_GNU_RELRO、REL/APS2 Android packed 重定位、RELR、SysV + GNU 哈希、
  symbol version 与 DT_INIT/DT_INIT_ARRAY、递归 `DT_NEEDED`，以及
  `PT_ARM_EXIDX`（C++ 展开）。它还实现了较新 closure 所需的 ARM
  TLS：一张模块表（每个被载入的库调 `hyb_tls_register`，
  `DT_TLS` 在 `map_file` 里捕获）、对着该表解析
  `R_ARM_TLS_DTPMOD32`/`DTPOFF32`，以及一个真正的 `__tls_get_addr`：按「每线程每模块」
  惰性分配一个对齐块并拷贝 `PT_TLS` 模板。实际出现的只有
  `DTPMOD32`（5 个重定位，符号全为 0 → 模块 = 自身，
  `PT_TLS` 是纯 `.tbss`）；`R_ARM_TLS_TPOFF32` 仍未实现，一碰到就
  大声报错失败，而 closure 也没有 `__emutls_get_address`。缺了这套东西，
  loader 会拒绝这些重定位，驱动永远载不进来 —— zygote 死在
  `preloadOpenGL`（maple 怪癖 TEST 49）。解析裸库名时的搜索顺序：
  `vendor/lib/egl`、`vendor/lib/hw`、`vendor/lib`、
  `system/lib/hw`、`system/lib`（相对 `HYB_ROOT`）；较新一侧的
  绝对路径（例如 `/vendor/lib/hw/gralloc.default.so`）先重定基到
  `HYB_ROOT` 之下，失败再回退成裸名在上述
  目录里查找。符号解析顺序：hooks → 本地组（
  dlopen 的根，然后按广度优先遍历依赖）→ 已载入的库 → KitKat。
  本地组很关键：同一个 global 在多个库里以不同
  大小定义时，必须绑定到它自己那个组的副本。
- **宿主侧库名**：`libc.so`、`libm.so`、`libdl.so`、`liblog.so`、`libcutils.so`、
  `libz.so` 解析到 **KitKat 的**版本（同样的 32 位 ABI）；`ld-android.so`
  和 `libdl_android.so` 是虚拟的（在内部解析）。其余一切都来自
  hyb 根目录。
- **Hooks**（`hyb/hooks.c`）：较新库所 import、而 KitKat 的
  bionic 缺失或实现不同的函数 —— 68 个符号，来自对驱动 + gralloc + 依赖
  所构成的 closure 的 `readelf` 遍历（发现 100 个缺失
  符号；其余用别的办法提供）。例如：`iswblank`、
  `strtold`、`aligned_alloc`、`fseeko64`/`ftello64`/`sendfile64`/`truncate64`、
  `iswblank_l`、`localeconv`、fortify 包装 —— 以及 TLS 入口
  `__tls_get_addr`：它原先是会 abort 的绊线，直到后来发现 closure
  其实需要 TLS（见 loader 那一条；现在它是 `hyb/linker.c` 里的真正
  实现，`hooks.c` 只是把它重新导出）。
- **EGL/GLES shim**（`egl/`）：`libEGL_adreno.so` / `libGLESv1_CM_adreno.so` /
  `libGLESv2_adreno.so` 保留它们的 KitKat 名字，但只是薄薄的 shim（从
  本树构建），它们通过 libhyb 载入真正的驱动并转发。GLES 走
  一张生成的跳转表（`gles*_stubs.S` + `*_names.c`，KitKat 的
  `frameworks/native/opengl/libs/entries.in` 里每个驱动中存在的函数对应一项；
  用 `egl/gen_stubs.py` 重新生成 —— Android 11 与 15 的导出经核对
  完全相同）。EGL 在较新驱动会直接触碰 KitKat 结构的两处做了拦截：
  - **窗口 surface**：一个中间层 `ANativeWindow` 负责翻译 KitKat 不认识的 query/
    perform 码（`NATIVE_WINDOW_*`），并按较新格式（`layerCount`、64 位 usage）
    把缓冲交给驱动，其 handle 正是
    导入 QTI gralloc1 的那一个；
  - **原生缓冲的 `eglCreateImageKHR`**（`EGL_NATIVE_BUFFER_ANDROID`）：
    同样的中间缓冲。
- **gralloc**（`gralloc/gralloc.c`，模块 `gralloc.maple`）：KitKat 的 gralloc
  module 0.2 + allocator + framebuffer HAL，实现于同一 closure 里的 **QTI
  gralloc1** 之上（`gralloc.msm8998.so`，以
  `vendor/lib/hw/gralloc.default.so` 暂存，因此不存在与官方原厂 `gralloc.default.so` 的命名
  冲突；由 libhyb 载入）。因此这些缓冲是真正的 ION 缓冲，
  采用 QTI 的 `private_handle_t` 布局 —— 正是 Adreno 驱动
  所期待的。跨进程传递的 handle 在 import 前会被克隆（复制 fd）：
  QTI gralloc1 在最后一次 release 时会销毁它拿到的那个 handle，而 KitKat 的
  `GraphicBuffer` 会关掉自己的那个。
- **fbpresentd**（`fbpresentd/fbpresentd.c`）：64 位、静态、用 NDK 构建
  （`tools/libhyb/build-native.sh`）。KitKat 的构建系统只产出 32 位
  二进制，而内核的 **`MSMFB_ATOMIC_COMMIT` 32 位兼容路径
  会把系统搞崩**，所以这一块放在树外。协议：抽象
  `SOCK_SEQPACKET` 套接字 `@fbpresent`，每帧一个 `struct fbp_req`，
  缓冲的描述符只发一次（SCM_RIGHTS），之后按 id 寻址，每次 commit 有
  一个 int32 ack（[`fbpresentd/fbpresent.h`](../../../devices/maple/kitkat/fbpresentd/fbpresent.h)）。
  它把缓冲作为主显示器 DMA0 管道的单层提交
  （`pipe_ndx = 64` = `BIT(6)`，即内核的 `MDSS_MDP_SSPP_DMA0` 编码；
  已对着 `~/kernel-44` 的 `msm_mdp_ext.h` 核对过），并在客户端死掉时
  做一次空提交，以免面板冻结在一个已死的层上。
- **固件**：a540 的 microcode/GPMU/zap blob 被暂存到
  `vendor/firmware`（与 modem/adsp blob 同一位置），并通过
  `firmware_class.path=/vendor/firmware` 找到（见[怪癖](../../devices/maple/quirks.zh-CN.md)）。

## EGL 路径（为什么不再需要 EGL 补丁）

- 官方原厂 KitKat 的逻辑是靠扫描、而不是靠配置来选驱动：
  `Loader::load_driver` 取 `/vendor/lib/egl` 里第一个 `libEGL_*.so`，
  然后是 `/system/lib/egl`（只跳过 `libGLES_android.so`）—— 我们的 shim
  是那里唯一的硬件实现。`BOARD_EGL_CFG` 仍然随包发出官方原厂的
  设备布局，位于
  [`devices/maple/kitkat/egl.cfg`](../../../devices/maple/kitkat/egl.cfg)
  （`0 0 android` / `0 1 adreno`），在本发行版运行时是惰性的。
  `Loader::checkGlesEmulationStatus` 保持原样 —— 删掉的那个 glrenderd
  EGL 补丁从来也只是把这里恢复成官方原厂的样子。
- **任何地方都不要设 `ro.kernel.qemu`**：它一出现就会把 loader 切到
  模拟路径并禁用 hwui。模拟库
  （`libEGL_emulation` 等）、`BUILD_EMULATOR_OPENGL`、goldfish/sdk 补丁
  以及 `GLConsumer` 的 `glGetError` 上限都随 glrenderd 一起消失了 ——
  官方原厂树加上我们的 shim 就是全部。
- `libGLES_android`（软件 ES1）留在构建里，作为无驱动时的兜底。
- **现在会构建 hwui 了**（`BoardConfig.mk` 里的
  `USE_OPENGL_RENDERER := true`，与 Taimen 对齐；`frameworks-base-hwui-gles2-cap.patch`
  让它保持 KitKat 被测过的 ES2 行为）。glrenderd 时期的
  构建从未设过这个开关，所以 `libhwui` 从未被构建、UI 是
  软件绘制的 —— 加速 UI 正是这次切换的意义之一，
  而且这是首次刷机时要盯的行为变化（`dumpsys gfxinfo`、
  `/system/lib` 里的 `libhwui.so`）。

## 呈现

- **单一翻转者规则**（延续下来）：只能有一个组件去驱动 fb0 的
  offset。`gralloc.maple` 拥有 framebuffer HAL，所以 SurfaceFlinger 的 post 经
  它下发，SF 自己从不 `FBIOPAN`（`FramebufferSurface` 消费
  HAL 的 `post`）。`fbpresentd` 替 gralloc 执行真正的面板
  提交。
- **零拷贝主路径**（2026-10-19 在 maple 上验证）：gralloc 在 fb-open 时
  连到 `@fbpresent`，并把每个缓冲的描述符发一次；
  呈现就是对 DMA0 管道的一次 MDSS atomic commit。不拷贝、不 pan、不
  回读 —— **这也意味着 fb0 的内存从不被写入**：对一个已被驱动的面板
  做 `dd if=/dev/graphics/fb0` 回读，结果全是 0，所以
  glrenderd 时期的 fb0 解码检查在这条路径上是瞎的（下面那条拷贝路径
  部分就是为了这个）。证据改为来自 `fbpresentd`，它把日志写进
  `/dev/kmsg`（以前写 stderr，而 init 把 stderr 指向 /dev/null ——
  presenter 一边干活一边是个哑巴）：`ready`、`client connected`、
  前三次 commit，以及每 600 次一行，携带*上一帧*的
  MDP `release_fence` 状态。那个 fence 只在 DMA0 已读走
  该缓冲用于扫描输出时才触发，所以
  `fbpresentd: commit #2 1080x1920: previous frame scanned out` 就是
  「面板已被驱动」的判据（失败文本是 `NOT scanned out in 100 ms`）。
  同一行还携带活跃期间的帧率
  （`… 59.9 fps while active`）；屏幕静止时 SF 什么都不 post，所以
  把空闲间隙一起平均出来的帧率会读成假的变慢（实测 2.3 fps，
  而 `dumpsys SurfaceFlinger --latency` 说 60.0 —— 现在指标会跳过
  超过 100 ms 的间隙）。
- **拷贝兜底**：如果套接字不存在或守护进程拒绝（init 在 `post-fs-data`
  里启动 `fbpresentd`；没有这个二进制的启动会走到兜底），gralloc
  就拷进 fb0，并用 **`FBIOPUT_VSCREENINFO` + 新的 `yoffset`** 翻转。
  maple 的 mdss 忽略 `FBIOPAN_DISPLAY`（它记一条 `unable to allocate base pipe`
  然后返回成功，但 offset 没动 —— maple TEST 30）；这与官方原厂 gralloc 的 `fb_post` 用的是
  同一个 ioctl。`persist.gralloc.fb_commit=0` 强制走
  拷贝路径（用于二分定位 presenter 时有用）。2026-10-19 已验证：把
  该属性设为 0 后 gralloc 记录 `atomic commit 0`，fb0 的两个 page 里都装着已合成的
  帧，回读解码出来的行 stride 是 4352 字节
  （1088 px），裁到 1080x1920 干净利落 —— 兜底路径和 stride
  都成立。该属性存在 /data：它能挺过一次系统刷机，所以 A/B 测试完要把它
  重置回 1，否则设备会一直停在慢路径上。
- MDP 的**空闲断电（idle power collapse）**必须在 DT 里保持禁用
  （`qcom,mdss-idle-power-collapse-enabled`，由
  [`scripts/patch-maple-dtb.py`](../../../scripts/patch-maple-dtb.py) 剥掉），否则
  静态 UI 会变黑，直到有人碰屏 —— 这与 presenter 无关，见
  TEST 30。
- **SurfaceFlinger 配置**：fb HAL 上报 `numFramebuffers = 3`、
  `RGBA_8888`、`minSwapInterval = maxSwapInterval = 1`、fps 60；SF 从
  HAL 读到 width/height/format（对 framebuffer surface 它忽略 stride/numFramebuffers）。

## 第二个消费者：音频 ACDB 校准（maple，2026-10-19）

图形并不是 KitKat 能这样跑起来的唯一较新 Android vendor 库。
`audio.primary.maple`（`devices/maple/kitkat/audio/audio_hw.c`）通过 libhyb
载入 `libacdbloader.so`，用于 **ACDB 校准**：qcom 的内核音频
驱动在 stream/port 启动时到 `/dev/msm_audio_cal` 里查 ACDB 块，
这个 loader 是那些块的唯一写入者，而它的 Android 15 构建无法跑在
KitKat 的 linker 或 bionic 之下。播放列表如下：

- HAL 调用 `hyb_dlopen("libacdbloader.so", RTLD_NOW)`，解析
  `acdb_loader_init_v2` + `acdb_loader_send_audio_cal_v3`，并**在整个 mediaserver 生命周期内
  持有该 handle** —— 一旦 loader 的 `/dev/msm_audio_cal` fd 关闭，cal 块就会被丢弃，
  所以用一次性小工具不够。
  每个启动也只有一个 loader：mediaserver 一持有这些块，另一个进程里的第二次 init
  就会死在 `cal_block_ion_alloc: audio ION import failed, rc = -22` → `voice_alloc_cal … failed` → `acdb_loader_init_v2 = -12`，所以
  诊断跑法应该安排在一次全新启动之后。
- loader 的设备列表是**一张硬编码表**，而 TX id 需要
  `dev_type = ACDB_DEV_TYPE_IN = 2`（vendor HAL 在
  `hardware/qcom/audio/hal/audio_hw.h` 里声明的是 `1`/`2`）；用 `0` 会记录 `ACDB -> Device is
  not RX or TX!acdb_id = %d` 并返回非零拒绝（65–67）。
  扬声器 15、耳机 10、扬声器+耳机 799 是 RX 条目；
  麦克风家族 4（手持）、8（耳麦）、6、9、35、131、143、152 在
  dev_type 2 下全部通过（`acdbtest --scan`）。这些 id 来自 qcom 的
  遗留表（`hardware/qcom/audio/hal/msm8974/platform.c`），而不是
  较新平台的 `audio_platform_info.xml`。
- msm8998 KitKat 上暂时把 **TX（采集）校准关掉**：loader
  会取 acdb 4 并推入 `Topology Id 112fb`，此后每一次采集
  prepare 都会死 —— 死在 ADM 里（`adm_callback: cmd = 0x10326 returned error =
  0x1`、`adm open failed copp_idx:-131`、prepare `-22`）或死在 SLIM TX
  后端（`cpu DAI prepare error: -131`），取决于 cal 是怎么进去的 ——
  直到重启为止。这些块能活过 `kill -9 mediaserver`，任何 TX 发送
  都会触发它，`acdbtest --scan` 也算。RX cal（15/10，topology `112fc`）
  不受影响。细节见
  [KitKat 移植笔记](../porting-notes/kitkat.zh-CN.md) 与 maple TEST 51。
- 同一套暂存工具：`stage.py` 从 `ACDB` 根（`libacdbloader.so`）
  出发，把它的 `DT_NEEDED` closure
  （`libaudcal`、`libacdbrtac`、`libacdb-fts`、`libadiertac`、`libmiscta`、
  `libdiag`、vendor 的 `libtinyalsa`）一并放进 Adreno 驱动所在的
  `/system/a15` 树。
- 数据**不在** closure 之内：`/sys/devices/soc0/hw_platform`
  在 maple 上读到 `MTP`，所以 `stage.py` 把 Lineage 的 yoshino acdb 数据
  （`vendor/etc/acdbdata/Sony/`）拷到 `root/` 旁边的 `acdbdata/MTP/`，再由
  `full_maple.mk` 安装到 `/system/vendor/etc/acdbdata/MTP/`。
- 节点权限是一处移植修复：`ueventd.maple.rc` 把
  `/dev/msm_audio_cal` 开成 `0660 media audio`（驱动默认是
  `root:root 0600`，而 mediaserver 的 uid 是 `media`）。
- 2026-10-19 端到端验证：AudioTrack 的提示音经
  framework HAL 能听到（采集信号 99 % 的频带能量在 440 Hz），对该提示音的 framework
  采集读到 440.00 Hz，耳机路由 + acdb 10
  cal 也能准备并播放。听测脚本与失败模式见
  [maple 怪癖](../../devices/maple/quirks.zh-CN.md) TEST 50/TEST 51，通用教训见
  [KitKat 移植笔记](../porting-notes/kitkat.zh-CN.md)。

随它一起交付的诊断工具：`acdbtest`
（`devices/maple/kitkat/hyb/acdbtest.c`，在镜像里）直接驱动 loader
（`--init-only`、`--send ID TYPE`、`--scan` —— 后者在一次 init 里遍历 loader 的
RX/TX 表、`--v3 --hold 15 1` —— `--hold` 这种写法就是常驻 fd 的证明）；`audiotrack_test`
（`devices/maple/kitkat/audio/audiotrack_test.cpp`）经
AudioFlinger 而不是 tinyalsa 播放提示音，而 `audiorecord_test`
（`devices/maple/kitkat/audio/audiorecord_test.cpp`）是它的采集版孪生 ——
两者都接受一个可选的 `routing` 参数，其应用方式与
AudioPolicyManager 的插孔处理一致（`AudioSystem::setParameters(0,
"routing=N")`）。对拉回来的采集做检查的宿主机侧工具是
[`scripts/analyze-rec.py`](../../../scripts/analyze-rec.py)（峰值/rms、
主频、卡顿边带；需要 numpy）。

## 构建与暂存

补丁集：图形这部分工作**不再需要**任何 AOSP 图形补丁 ——
树是官方原厂 KitKat 加上属于这次移植的 `patches/kitkat/` 条目
（binder 64 位，以及较新内核的修复：liblog→kmsg、alarms/time 等）。这套栈需要的是
**暂存好的 closure**：

```sh
tools/libhyb/extract-lineage.sh <lineage-22.1-maple.zip> <sysroot> [vendor.img|dir]
tools/libhyb/stage.py <sysroot> $AOSP_DIR/vendor/sony/maple-hyb
tools/libhyb/build-native.sh $AOSP_DIR            # NDK r21e; builds fbpresentd
make bootimage systemimage                        # HYB_DIR/BIN_DIR copied by full_maple.mk
```

- `extract-lineage.sh` 解包一个 Lineage 22.1 的 maple 构建（system + vendor，以及
  bionic 用的 runtime apex）；`stage.py` 从 Adreno 驱动 + QTI gralloc1 出发遍历
  `DT_NEEDED`，把 closure 连同 a540 固件拷进
  hyb 根（`root/vendor/...`、`root/system/...`）。自 2026-10-19 起它还会遍历
  第二个根 `libacdbloader.so`（音频 ACDB，见上文），并把 yoshino
  acdb 数据拷到 `root/` 旁边的 `acdbdata/MTP/`。
- `full_maple.mk` 把 `vendor/sony/maple-hyb` 拷进 `/system/a15`、
  把 `vendor/sony/maple-bin` 拷进 `/system/bin`，**前提是它们在**；两个暂存目录
  都放在 `vendor/sony/maple` 之外，因为 `sync-device-tree.sh` 用
  `--delete` 做 rsync。重新暂存之后要重建镜像。
- **暂存刷新规则**（沿用，略作调整）：镜像构建发出去的是暂存目录里当时的
  内容；只 live-push 到设备的 `fbpresentd` 或 closure，会被下一次用未刷新暂存
  做的镜像构建悄悄覆盖回去。
  刷新暂存要和重建放在同一次改动里做，并比对哈希：
  `md5sum vendor/sony/maple-bin/bin/fbpresentd .../maple-hyb/root/vendor/lib/egl/libEGL_adreno.so`。
- **头文件的权威来源**：MDSS 结构体来自 **maple 内核的**
  `include/uapi/linux/msm_mdp_ext.h`（+ `msm_mdp.h`），收在
  [`gralloc/mdss/`](../../../devices/maple/kitkat/gralloc/mdss/) 之下 —— 就是运行中内核
  当初编译所用的那些头文件。Taimen 的副本只有 include 风格、一个 `rect_num`
  （保留）字段以及 HDR 宏定义三处不同。

## 状态与设备上的检查清单

2026-10-18 随 KitKat 镜像的其余部分一起构建，2026-10-19 刷机并**在硬件上
验证**（冷启动，两个镜像都刷了并做 md5 回读）。下面这份
清单就是按顺序跑过的东西：

1. `hybtest` —— 载入 closure、建一个 ES3 context、绘制并回读像素；
   打印驱动字符串。已验证：`EGL 1.5`、`Adreno (TM) 540`、
   `OpenGL ES 3.2 V@331.0`，绿色 clear + 像素回读，2000 次 clear 带
   `glFinish` 用时 18.2 ms，进程内驱动载入 9 ms。这里失败意味着
   loader/hooks/closure 有问题，而不是 framework —— 第一个真正的失败是 TLS
   重定位（上面的 loader 那一条）。
2. `dmesg`（这个内核上只要节点可写，liblog 就落进 `/dev/kmsg`，见移植
   笔记）：closure 按 `DT_NEEDED` 顺序载入，
   然后是 `egl_adreno: Adreno 540 driver ready (gralloc import ok)`；
   `gralloc.maple` 记录 `fb0 1080x1920, line 4352 bytes, double buffer 1,
   BGRA 0, atomic commit 1`（走兜底的话记录的是
   `presentation by fbpresentd refused (...)`）。SurfaceFlinger 自己的
   ALOG 行在 dmesg 里也能读到（`SurfaceFlinger[pid]: …`）。
3. `dumpsys SurfaceFlinger` → `EGL implementation: 1.5`、
   `GLES: Qualcomm, Adreno (TM) 540, OpenGL ES 3.2 V@331.0`、
   `EGL_NATIVE_VISUAL_ID: 1`、`refresh-rate: 60.000002 fps`，各层在
   1080x1920 上合成；`sys.boot_completed=1`、`init.svc.surfaceflinger=running` 与
   `init.svc.fbpresentd=running` 齐备，没有手工步骤。
4. UI 现在是 GL 绘制的（glrenderd 时期从未构建过 hwui）：
   `ls /system/lib/libhwui.so` 存在，`dumpsys gfxinfo com.android.settings`
   显示出真正的 DisplayList 绘制命令。
5. 不依赖 `logcat` 的调试可用：loader 错误查 `dmesg | grep -i hyb`，
   再看各进程的 tag（`SurfaceFlinger[pid]`、`gralloc.maple[pid]`、
   `libhyb[pid]`、`egl_adreno[pid]`、`Adreno[pid]`、`fbpresentd`）。
6. 面板正常性：`fbpresentd` 报告 `commit #2 … previous frame scanned out`
   （MDP release fence → DMA0 确实在扫描输出）；framework 点亮
   背光（两个节点 1638/4095 = brightness 102）；静态 UI 保持不灭
   （空闲约 15 分钟，下一次突发仍是 `59.9 fps while active`，没有断电）；
   `persist.gralloc.fb_commit=0` A/B：fb0 的两个 page 里都装着该帧，且能以 4352 字节 stride
   干净解码 → 拷贝兜底可用，stride/几何正确。
7. FPS：用 `dumpsys SurfaceFlinger --latency` 实测 59.5–60.0（Settings
   滚动）对比 glrenderd 基线（约 26–35 fps）。动画下的功耗
   没有重测（工作站上没有功率计）—— 如果这个对比重要，记 TODO。
8. 经同一个 loader 的音频（2026-10-19 加入）：一边跑 `audiotrack_test 6`，
   一边用 `tone_test cap` 录音 —— 采集在 150–3000 Hz
   频带上以约 99 % 的能量持续 440 Hz 三秒（音乐音量 11/15 时峰值 ≈ 200），
   `dmesg` 显示 mediaserver 打出的 `acdb: loader init(msm8998-tasha-snd-card) = 0`，
   每个 stream 启动时都写入一组 `ACDB-LOADER[…] send_audio_cal, acdb_id = 15` 块，
   且没有 `cal_block` 错误。这里失败则问题在 ACDB
   closure、`hw_platform`/acdbdata 目录、`/dev/msm_audio_cal` 的
   DAC 规则，或 tinyalsa 的字节/帧单位 —— 见上文 *第二个消费者*。

## 移植到另一台设备

1. 确认目标发行版没有原生驱动，并保留一个非 GL 的兜底，用于 closure
   不存在的场合。
2. 为**同一 SoC** 抽取现代的 vendor closure（该设备的 Lineage 构建）；
   32 位/64 位分工很重要 —— loader 载入 32 位库，
   presenter 是 64 位。
3. 重新推导**符号 closure**（`readelf -d` 遍历，或 Taimen 的
   `scripts/closure.py`），为目标 bionic 所缺的东西写 hooks。
   不要盲目照抄别的设备的 hook 清单；bionic 缺口取决于
   closure。
4. 在目标上重新推导**翻转者规则** —— 不要照搬：maple
   忽略 `FBIOPAN_DISPLAY`，改用 `FBIOPUT_VSCREENINFO` 翻转（TEST 30）；
   姊妹设备各有不同。atomic commit 的管道编码要对着
   目标内核的头文件重新核对。
5. 把 gralloc 头文件（`msm_mdp*.h`）对着设备实际运行的**内核**重新核对，
   并把 QTI 的 `private_handle_t` 对着该 SoC 暂存的 gralloc 核对。
6. 重新安排 init 时序：`fbpresentd` 要在 SurfaceFlinger 第一次 post 之前
   （`post-fs-data`）起来，并且保证只有一个翻转者。
7. 在 `BoardConfig.mk` 里设 `USE_OPENGL_RENDERER := true`（若驱动上报 ES3，
   还要带上 hwui 的 ES2 上限）—— 没有这个开关，KitKat
   根本不会构建 `libhwui`，每一帧 UI 都是软件绘制。
8. 对同一个 loader 的音频消费者：把目标自己的
   acdbdata 暂存到 `/sys/devices/soc0/hw_platform` 报告的目录名下（而不是
   vendor 树里用的那个名字），把 `/dev/msm_audio_cal` 开给运行
   mediaserver 的 uid，并在 HAL 里让 loader 的 handle 保持存活 —— cal
   块会随它的 fd 一起死掉。
