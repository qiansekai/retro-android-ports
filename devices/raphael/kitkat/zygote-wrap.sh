#!/system/bin/sh
# Wrapper so init-launched zygote stderr lands in /cache.
# init sets ANDROID_SOCKET_zygote and passes the socket fd to this
# service; exec keeps both, so app_process sees the normal environment.
exec /system/bin/app_process -Xzygote /system/bin --zygote --start-system-server 2>/cache/zygote.log
