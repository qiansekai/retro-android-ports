# glrenderd —— 为没有 GPU 驱动的 Android 版本提供硬件 GL

> 中文译文。英文原文见 [glrenderd.md](glrenderd.md)。技术名词、代码、路径、命令与日志一律保留原文。
>
> 归档说明：上游于 2026-10-19 用 [libhyb](libhyb.md)（进程内 Adreno 驱动 + 64 位 `fbpresentd`）取代了 glrenderd，并删除了英文原文；本译文仅作历史存档。本 fork 的 raphael（K20 Pro）仍在使用 glrenderd 的 DRM/KMS 后端，代码在 `tools/raphael/glrenderd/`。

`glrenderd` 让**较新的 GPU 驱动跑在旧版 Android 上**。在 maple（MSM8998，Adreno 540）上，
KitKat 根本没有 EGL 驱动，于是 guest 把 Android 模拟器的 GL 栈（goldfish `libEGL`/GLES）当作
传输层：GL 调用经 `@glrenderd` 抽象套接字流式发往一个运行在*新版 LineageOS 系统的 chroot
之内*的守护进程，由它在真正的 Adreno 上绘制，并把帧呈现到 `/dev/graphics/fb0`。

移植自 @chardidathing 的 [chardidathing/pdx203-jellybean](https://github.com/chardidathing/pdx203-jellybean)。
源码位于 [`tools/glrenderd/`](../../../tools/glrenderd/)；AOSP 侧的补丁是
[`patches/kitkat/`](../../../patches/kitkat/README.zh-CN.md) 里 `*glrenderd*` 那几个条目。

## 为什么需要它

- KitKat 早于 Adreno 540；这个版本不存在可用的厂商驱动。`libagl` 是软件实现，只支持
  ES1 —— 任何 ES2 客户端（SystemUI 动态壁纸、hwui 应用）都找不到可用配置，直接崩
  （`eglConfig not initialized`）。
- 新驱动无法直接跑在旧 userspace 里（bionic ABI、SELinux、root 布局都不同）。chroot +
  套接字的设计绕开了这个矛盾。

## 架构

- **guest 侧**：打过补丁的 goldfish GL 库。`HostConnection` 连接 `@glrenderd`；
  `gralloc.maple.so` 负责把窗口缓冲区交出去；套接字不回应时，EGL 与 gralloc 的探测回落
  到 `libagl`/`gralloc.default`。
- **守护进程**：32 位的 `glrenderd`（emugl 线格式携带 32 位指针）运行在 Lineage 的
  `system`+`vendor` 闭包 chroot 之下（`hwchroot`），加载
  `libEGL_adreno`/`libGLESv2_adreno`，渲染、回读并翻动面板。
- **单一翻页者规则**：只允许一个组件翻转 fb0。glrenderd 在 `post-fs-data` 中启动，
  **早于** SurfaceFlinger 的首次 GL 探测，于是 SF 走模拟路径、经 `rcFBPost` 提交 —— 它
  从不 `FBIOPAN`。启动太晚会把 SF 锁死在软件路径上（按进程缓存一次），两个翻页者还会卡
  死 mdss，报 `mdp ctl start failed`（EBUSY）。
- **面板翻转**：maple 的 mdss 忽略 `FBIOPAN_DISPLAY`（返回成功、报
  `unable to allocate base pipe`、偏移量不动）。glrenderd 用 `FBIOPUT_VSCREENINFO` +
  `yoffset` 来翻转，与官方原厂（stock）gralloc 的 `fb_post` 用的是同一个 ioctl；
  `open_panel` 自己把 `yres_virtual` 翻倍（glrenderd 模式下没人去打开 fb HAL）。
- **MDP 的空闲断电（idle power collapse）** 必须在 DT 里关掉
  （`qcom,mdss-idle-power-collapse-enabled`），否则静态界面会一直黑屏直到被触摸 —— 见
  [scripts/patch-maple-dtb.py](../../../scripts/patch-maple-dtb.py)。

## 构建与暂存

前置条件：把四个 `*glrenderd*` 补丁，外加
[`patches/kitkat/files/`](../../../patches/kitkat/README.zh-CN.md) overlay（RenderdStream.\*，
diff 带不动的整份文件）应用到 AOSP 树；准备一个 NDK（我们的构建服务器上用 r21e）；再为
chroot 准备一份 Lineage 20 的 maple 构建（zip 或 system/vendor 镜像）。然后：

```sh
tools/glrenderd/build.sh $AOSP_DIR <android-ndk-r21e>
tools/glrenderd/extract-lineage.sh <lineage-20-maple.zip> <sysroot> [oem.img]
tools/glrenderd/stage.py <sysroot> tools/glrenderd/out $AOSP_DIR/vendor/sony/maple-glr
make bootimage systemimage
```

`full_maple.mk` 会在 `vendor/sony/maple-glr` 存在时把它拷进 `/system/glr`（该目录放在
`vendor/sony/maple` 之外，因为 `sync-device-tree.sh` 用 `--delete` 做 rsync），所以暂存之后
要重新构建镜像。init 服务是 `/system/bin/sh /sbin/glrenderd.sh` →
`hwchroot /system/glr/root /glrenderd 1080 1920 -fb 2/dev/kmsg`。

**暂存刷新规则**：镜像构建会原样打包暂存目录里的内容，所以只 live-push 到设备上的守护
进程，下一次从未刷新的暂存树构建镜像时就会被悄悄回退。要在同一次改动里既重新构建、又刷新
暂存，并核对：
`md5sum vendor/sony/maple-glr/root/glrenderd tools/glrenderd/out/glrenderd`（`hwchroot`
同理）。maple 2026-10-17 就是这样把可靠性补丁集之前的守护进程二进制和新的 guest 库一起发
了出去 —— 交叉构建不匹配让守护进程在使用中每 5 分钟崩约 3 次（完整记录：
[maple 怪癖](../../devices/maple/quirks.zh-CN.md) 中的 TEST 41）。没有 md5 时怎么判断
「跑的是哪个守护进程」：A1–A6 的构建会在 stats 行里打印
`posts=… drops=… postgap … stage …`，旧的那版不会。姊妹设备提示：`hwchroot` 与 poplar
共用 —— 这里的修复会在 poplar 下次做暂存构建时到达 poplar。

**渲染器重建规则**：`build.sh` 会重新生成 guest 侧的 codec 表；新构建的守护进程若配上
陈旧的 `*_enc.so` 部署，画面会发暗或花屏。如果协议 `.in` 文件没动过，生成的表完全相同，
重建是安全的 —— 但无论如何都把已知可用的二进制留作备份。完整清单见
[KitKat 移植笔记](../porting-notes/kitkat.zh-CN.md)。

## 可靠性规则（踩坑踩出来的）

完整的「症状 → 根因 → 修复」记录在 [KitKat 实战教训](../porting-notes/kitkat.zh-CN.md)；
简版如下：

- **fork 安全**：TLS 上的 GL 连接会跨 zygote fork 被继承；在 `HostConnection::get()` 里
  按 pid 变化重新持有它（用文件级 static，绝不要新增成员 —— 成员偏移已经烧进预编译的
  encoder 库里）。
- **给每一次等待都设上界**：`SO_RCVTIMEO`/`SO_SNDTIMEO`（~20 s，属性
  `persist.glr.replytimeout`），发送侧用 `MSG_NOSIGNAL`；超时/EOF/EPIPE 意味着这条流已死
  —— **close 掉 fd**，**原地**重连（绝不能 free —— 会 use-after-free），并重放渲染器在
  解码前读取的每连接握手字。
- **给套接字缓冲区定好大小**：这个内核上 `net.core.{r,w}mem_default` 约 208 KB，而一帧
  的命令流就超过 200 KB；两端都用 `setsockopt` 设到 ~8 MiB（guest 在连接/重连时设，守护
  进程在 `accept` 之后设）。
- **渲染器一侧**：给 `ReadBuffer` 设上限（32 MiB，超了丢弃客户端），一次只解码一条已声明
  的消息，framing 丢失时重新同步，别让 guest 的死拖累守护进程
  （`signal(SIGPIPE, SIG_IGN)`）。
- **给 GL drain 循环设上界**：`GLConsumer` 清 `glGetError()` 每次迭代都是一次同步往返 ——
  必须限次（8）。
- **回读落到 presenter 的 slot 里**（poplar A6），绝不直接落进 fb0 页本身。在这个 Adreno
  上实测异步/PBO 回读*更慢*（`persist.glr.asyncreadback`，默认关闭）。
- **守护进程重启会抛下一个还活着的 surfaceflinger**：新守护进程没有 SF 那些窗口对象的
  服务端状态 —— SF 会一直用陈旧缓冲区翻页，`posts=0` 永远如此（它的 GL 模式每进程只锁存
  一次）。`hwchroot` 会自愈：在 `/dev` 的 tmpfs 上放一个标记（`/dev/.glr/ran`），使开机
  首启之后每次运行 hwchroot，都在 exec 守护进程之前去 fork 宿主机的
  `/system/bin/setprop ctl.restart surfaceflinger`，于是每次守护进程死亡只付一次 SF 重启
  的代价（~2–4 s 的 UI 卡顿），而不是帧通路冻结。冷启动不受影响，也绝不要拿「SF 在不在
  跑」当重启信号 —— 启动时 SF 的进程只比 glrenderd 晚几毫秒 fork 出来（`class_start core`
  紧跟在 post-fs-data 的 `start glrenderd` 之后）。
- **chroot 是在 `/dev` 的 tmpfs 上组装的，不在 `<root>` 之下**：用 `find . -type f` 暂存
  （见下）构建出来的镜像，`<root>` 里没有空的 `dev`/`proc`/`sys`/`data` 目录，而运行时
  mkdir 它们会在只读 system 分区上 EROFS 失败 —— 随后每个 bind 都 ENOENT 失败，
  glrenderd 反复重启，SF 的探测则退化为软件渲染器。`hwchroot` 改为每次运行都在可写骨架
  上构建挂载点（`/dev/.glr`）；日志戳为
  `hwchroot: assembled /dev/.glr from /system/glr/root`。

## 状态与性能（maple，已验证）

- 冷启动后界面就跑在 Adreno 上：`dumpsys SurfaceFlinger` → `EGL implementation 1.4`，
  `GLES: Qualcomm, Adreno (TM) 540, OpenGL ES 3.2`。
- 持续 UI 动画约 **26–35 fps**；每帧下限来自同步的 `glReadPixels`（1080p 下 ~9–10 ms）
  加上缓冲区释放与合成等待，而不是算力（GPU 在最低频率，CPU 空闲）。
- 可靠性补丁集（TEST 33–35）：fork 安全重持有、有界应答 + 原地重连、8 MiB 缓冲区、防失步
  渲染器，以及上一节所列各项。
- 可靠性后续（TEST 41）：新镜像启动已修好（tmpfs chroot 骨架）、陈旧守护进程与 guest 构建
  不匹配导致的崩溃已修好（二进制已部署 + 暂存已刷新）、守护进程重启自愈；冷启动与压力
  矩阵于 2026-10-17 验证。

## 移植到其它设备

1. 确认目标版本确实没有原生驱动；保留一条非 GL 的退化路径（libagl），供守护进程缺席时使用。
2. 把*同一 SoC* 的新版厂商 GL 闭包解到 chroot 里（该设备的 Lineage 构建）；
   `extract-lineage.sh` 会处理 13 时代镜像的 apex/bionic 细节。
3. 在目标机上重新推导翻转规则 —— **不要照搬**：maple 用 `FBIOPUT_VSCREENINFO` 翻转并自己
   把 `yres_virtual` 翻倍（TEST 30–31）；poplar 用 `FBIOPAN_DISPLAY`，并要求缓冲区预先
   翻倍。姊妹设备的结论互相冲突，要重新验证。
4. 为你的冷启动重新给探测窗口定时（maple 需要 ~30 s），并在 SurfaceFlinger 首次探测之前
   启动守护进程。
5. 重跑套接字缓冲区大小与 framing 的测量；这些数字是按内核、按驱动而异的。
