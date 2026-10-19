# Poplar KitKat GPU 修复 —— `glrenderd` 参考（maple / poplar）

> 中文译文。英文原文见 [poplar-kitkat-gpu-fixes.md](poplar-kitkat-gpu-fixes.md)。技术名词、代码、路径、命令与日志一律保留原文。

yoshino MSM8998 上 `glrenderd` 工作的姊妹移植参考 —— 在 `poplar` 上开发，由 `maple` 采用。
参见 [glrenderd](software/glrenderd.zh-CN.md)（权威记录）、
[KitKat 移植笔记](porting-notes/kitkat.zh-CN.md)、
[maple 怪癖](../devices/maple/quirks.zh-CN.md)、
[poplar 怪癖](../devices/poplar/quirks.zh-CN.md)。

在 yoshino MSM8998 设备上、KitKat 4.4.4 之下，是什么让硬件 GL 跑起来的 ——
[maple](../devices/maple/README.zh-CN.md)（XZ Premium）与
[poplar](../devices/poplar/README.zh-CN.md)（XZ1）。同 SoC、同一个 4.4 内核、同一个
Adreno 540，所以**每个修复都是共享的**；它们是在 poplar 上开发出来的。

KitKat 没有 Adreno 540 驱动，而 `libagl` 只支持 ES1，因此 UI 跑在 goldfish 模拟器 GL 库上，
指向的不是 qemu 管道而是一个守护进程：

```
guest libEGL/libGLESv1_CM/libGLESv2  ->  @glrenderd abstract socket
  ->  glrenderd (Lineage userspace chroot, 32-bit)  ->  Adreno 540
  ->  readback  ->  fb0 pan
```

**`fb0` 只归一个翻页者** —— 第二个呈现者会卡死 mdss overlay 启动（`EBUSY`）。

| 症状 | 原因 | 修复 |
| --- | --- | --- |
| 撕裂 / 画面异常，随应用而变 | emugl 的 `HostConnection` 是线程局部的，于是每个 zygote fork 出来的应用都留着 **zygote 的**套接字 —— 两个进程共用一条 GL 流 | `HostConnection::get()` 跟踪静态 `s_ownerPid`，pid 变化时重建 |
| UI 冻结，合成器卡住 | 没有上界的 `while (glGetError() != GL_NO_ERROR)` —— 每次迭代都是一次阻塞的套接字往返，而且跑在合成器线程上 | 限到 8 次迭代 |
| UI 冻结，输入失效（`DispatchFrozen: 1`） | 冻结分发分支返回时没设置 `*nextWakeupTime` | 10 s 自解冻 |
| 重连时 `GLClientState::setActiveTextureUnit` 里 `SIGSEGV`（fault `0x1a0`） | free / 重建 `HostConnection` 与 encoder 属于 use-after-free | **原地**重连 |
| SurfaceFlinger 直接被 kill | `::send(..., 0)` 触发 `SIGPIPE` | `MSG_NOSIGNAL` |
| 帧推送中途停滞 | `net.core.rmem_max`（208 KB）把 8 MB 的 `SO_RCVBUF` 截断；AF_UNIX 发送端在队列填满时会阻塞，于是每推一帧 8.3 MB 就把 guest 卡住一次 | `glrenderd` 里的 `raise_socket_limits()` |

在**已死的流**上写必须返回成功（0）—— `alloc()` 把失败当成 NULL，预编译的 encoder 随后
就往里 `memcpy`。标记该流已死并丢弃；绝不要阻塞。

## 不变量

- 绝不给 `HostConnection` 加成员 —— 它的内联 `flush()`/`alloc()` 把成员偏移写死了。也不要
  挪动 `IOStream` 的成员。
- 不要随手重建 `glrenderd`：它的构建会重新生成 codec 表，与 guest 库不再匹配的守护进程会
  让面板花屏。把已知可用的二进制留着。
- `persist.glr.replytimeout`（默认 20 s）= guest 等多久之后判定守护进程已死。

## 状态 —— 尚未进入 `patches/kitkat/`

那里只有更早的脚手架（`device-generic-goldfish-glrenderd`、
`frameworks-native-egl-glrenderd`、`sdk-glrenderd`、
`system-core-glrenderd-fs-config`）。下面这些修复只存在于 poplar 的工作树里，所以在它们被
正式化之前，**GPU 行为无法从仓库复现**：

| 修复 | 文件 |
| --- | --- |
| fork 安全连接 | `device/generic/goldfish/opengl/system/OpenglSystemCommon/HostConnection.cpp` |
| 已死的流、`MSG_NOSIGNAL` | `device/generic/goldfish/opengl/shared/OpenglCodecCommon/SocketStream.cpp` |
| 原地重连 | `device/generic/goldfish/opengl/system/OpenglSystemCommon/RenderdStream.cpp`（`.h`） |
| 有界 `glGetError` | `frameworks/native/libs/gui/GLConsumer.cpp` |
| 分发自解冻 | `frameworks/base/services/input/InputDispatcher.cpp`（`.h`） |
| 套接字上限 | `tools/glrenderd/src/glrenderd.cpp`（`raise_socket_limits`） |

前两个扩展 `device-generic-goldfish-glrenderd.patch`；GLConsumer 与 InputDispatcher 两个是
新的 `frameworks` 补丁。
