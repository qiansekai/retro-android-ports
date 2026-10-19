# patches/kitkat

> 中文译文。英文原文见 [README.md](README.md)。技术名词、代码、路径、命令与日志一律保留原文。

本移植对干净 AOSP KitKat（`android-4.4.4_r2`）检出所做的改动。
分步构建：
[`docs/advanced/build/kitkat.zh-CN.md`](../../docs/advanced/build/kitkat.zh-CN.md)；
实战教训：
[`docs/advanced/porting-notes/kitkat.zh-CN.md`](../../docs/advanced/porting-notes/kitkat.zh-CN.md)。
布局与 [`patches/donut/`](../donut/README.zh-CN.md)相同：每个
`.patch` 都是针对所列仓库项目的 `git diff`，在该项目根目录下应用：

```sh
cd aosp-kitkat/system/core && git apply ../../patches/kitkat/<name>.patch
```

| Patch | 项目 | 内容 |
| --- | --- | --- |
| `build-jdk-openjdk6.patch` | `build` | `core/main.mk`：接受 OpenJDK 6（Oracle JDK 6 在 2026 年已装不上）；其下的版本检查仍强制 1.6.x |
| `bionic-binder-uapi-64bit.patch` | `bionic` | `libc/kernel/common/linux/binder.h` 作为 64 位 binder abi（协议 8），它是 4.4 kernel 唯一能说的一种 |
| `frameworks-native-binder-64bit.patch` | `frameworks/native` | libbinder 与 servicemanager 走该 abi，kernel 看到的每个指针与偏移都是 64 位。取代 `binder-uapi-64bit.patch`；应用前先 reset 这两个项目 |
| `device-generic-goldfish-glrenderd.patch` | `device/generic/goldfish` | 模拟器的 gl 库改为拨 glrenderd 的抽象 socket，而不是 qemu 管道；gralloc 以 `gralloc.maple` 构建，无 glrenderd 时回退到 `gralloc.default`；gles1 编码器在启用 `TEXTURE_EXTERNAL_OES` 时的图像规格修正。可靠性集：`HostConnection::get()` 中的 fork 安全 pid 重新归属、有界回复 + 原地重连并重放握手（`SocketStream`/`RenderdStream` —— RenderdStream 相关文件本身经 `files/` 交付）、每连接 8 MiB 的 socket 缓冲（`glrSetSocketBuffers`）、gralloc 的 `lock()` 跳过 `rcColorBufferCacheFlush` 往返 |
| `frameworks-native-egl-glrenderd.patch` | `frameworks/native` | egl loader 在 glrenderd 应答时选模拟库，否则用 libagl。取代 `egl-use-software-renderer.patch` |
| `frameworks-native-glconsumer-glgeterror-bound.patch` | `frameworks/native` | `libs/gui/GLConsumer.cpp`：给两个 `glGetError` 排空循环加上界 8 —— 每次迭代都是一次同步渲染器往返，无界排空会让某个 surface 的主线程在渲染器繁忙期间一直空转 |
| `sdk-glrenderd.patch` | `sdk` | glrenderd 的宿主渲染器、不透明 config 的 alpha 孪生（adreno 不会把不透明 pbuffer 复制进 rgba）以及无头投递。可靠性集：`ReadBuffer` 上限 32 MiB（丢弃客户端，而不是翻倍成约 2 GB 的 realloc）、抗失步的 `RenderThread`（每次解码一条消息、重同步、`[glr-rt]` 诊断 + 流历史转储）、`IOStream`/`SocketStream` 的 `peerPid()`/`shutdownStream()`、共享 `SocketStream` 增加 8 MiB socket 缓冲 + 回复/写超时。性能集（TEST 35）：poplar A6（`FrameBuffer::setPostReadback` + `ColorBuffer::readbackTo` —— post readback 落在 presenter 槽位，无中间拷贝）、可选的异步 PBO 回读（`persist.glr.asyncreadback`；在 maple 上实测*更慢*，默认关闭）、swap 路径计时（按连接 `rcFlushWindowColorBuffer`→`rcSetWindowColorBuffer`） |
| `frameworks-base-input-dispatch-freeze-thaw.patch` | `frameworks/base` | `services/input/InputDispatcher.cpp/.h`：解除超过 10 秒的分发冻结（WMS 会在窗口切换前后冻结；一次永不结束的切换让 dispatcher 沉睡、UI 不再接受触摸） |
| `frameworks-base-keyguard-scrim-no-input.patch` | `frameworks/base` | `policy/.../KeyguardServiceDelegate.java`：绝不显示崩溃遮罩，并让它 `FLAG_NOT_TOUCHABLE`/`FLAG_NOT_FOCUSABLE` —— 死掉的 keyguard 不能一边留着最后一帧、一边吞掉所有输入 |
| `system-core-glrenderd-fs-config.patch` | `system/core` | 给 glrenderd chroot 中被 exec 的文件设 0755，make_ext4fs 从 fs_config 取权限位 |
| `hardware-libhardware-gralloc-fb-stride.patch` | `hardware/libhardware` | `modules/gralloc/gralloc.cpp`：为 `HW_FB` 缓冲上报 kernel 的 `line_length` 步幅（mdss 把 1080 宽的 RGBA 行补齐到 1088；按 align-4 上报 1080 会让每一行被剪切成平行四边形） |
| `frameworks-base-systemui-wallpaper-canvas-fallback.patch` | `frameworks/base` | `packages/SystemUI/.../ImageWallpaper.java`：EGL 没有 ES2 config 时回退到 canvas 壁纸而不是抛异常（无 glrenderd 的纯软件 GLES；该崩溃让 systemui 循环崩溃，并留下一个吞掉所有触摸的僵尸 KeyguardScrim） |
| _（预计还有更多）_ | — | init/vold/adbd/HAL 加固，待 maple 上实测后加入（参照 `patches/donut/` 先例）。注意：原先预计需要的 mkbootimg `Image.gz-dtb`/base-0 回移并不需要（几何已验证） |

说明：

- `files/` 是以 AOSP 根为基准的纯复制 overlay
  （`cp -a files/* aosp-kitkat/`）。它携带 `git diff` 无法承载的
  整文件新增：
  `device/generic/goldfish/opengl/system/OpenglSystemCommon/RenderdStream.{cpp,h}`
  —— `device-generic-goldfish-glrenderd.patch` 在 `Android.mk` 与
  `SocketStream` 中引用、但从不创建的 guest 侧重连流；
  没有该 overlay，干净的树无法构建打过补丁的 guest 库。
- Patch 对应的是产出经启动验证的 maple zip 的那棵树；
  它们是纯 diff（无 commit 元数据），因此能经受重复 sync。
- 绝不要提交 blob 或完整 AOSP 树；`aosp-kitkat/` 已 gitignore。
