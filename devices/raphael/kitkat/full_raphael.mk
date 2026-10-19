# Product definition: full_raphael (Redmi K20 Pro, KitKat 4.4.4)
# MVP: boot to Launcher, touch, USB adb, Adreno 640 via glrenderd.
# No audio/wifi/camera/telephony yet.

PRODUCT_PACKAGES := \
    AlarmClock \
    Calendar \
    Camera \
    LatinIME \
    Music \
    Settings

$(call inherit-product, $(SRC_TARGET_DIR)/product/core.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/generic.mk)

# 7.6 GB RAM, 1080x2340 panel -> the 2048 Dalvik bucket. Without this
# system_server OOMs verifying framework-res on first boot.
$(call inherit-product, frameworks/native/build/phone-xhdpi-2048-dalvik-heap.mk)

DEVICE_PACKAGE_OVERLAYS := vendor/xiaomi/raphael/overlay

PRODUCT_NAME := full_raphael
PRODUCT_DEVICE := raphael
PRODUCT_MODEL := Redmi K20 Pro
PRODUCT_BRAND := Xiaomi
PRODUCT_MANUFACTURER := Xiaomi

PRODUCT_COPY_FILES += \
    vendor/xiaomi/raphael/system.prop:system/build.prop \
    vendor/xiaomi/raphael/fstab.raphael:root/fstab.raphael \
    vendor/xiaomi/raphael/init.rc:root/init.rc \
    vendor/xiaomi/raphael/init.raphael.rc:root/init.raphael.rc \
    vendor/xiaomi/raphael/init.raphael.usb.rc:root/init.raphael.usb.rc \
    vendor/xiaomi/raphael/usbudc.sh:root/sbin/usbudc.sh \
    vendor/xiaomi/raphael/ueventd.raphael.rc:root/ueventd.raphael.rc \
    vendor/xiaomi/raphael/autowinch.sh:root/sbin/autowinch.sh \
    vendor/xiaomi/raphael/dump-boot-log.sh:system/bin/dump-boot-log.sh \
    vendor/xiaomi/raphael/glrenderd.sh:root/sbin/glrenderd.sh \
    vendor/xiaomi/raphael/bindermount.sh:root/sbin/bindermount.sh \
    vendor/xiaomi/raphael/bootstage.sh:root/sbin/bootstage.sh \
    vendor/xiaomi/raphael/zygote-wrap.sh:root/sbin/zygote-wrap.sh \
    vendor/xiaomi/raphael/touchscreen.idc:system/usr/idc/touchscreen.idc

# glrenderd's guest side. gralloc.raphael and the egl loader fall back to gralloc.default and
# libagl whenever glrenderd isn't there
PRODUCT_PACKAGES += \
    libEGL_emulation \
    libGLESv1_CM_emulation \
    libGLESv2_emulation \
    gralloc.raphael \
    gralloc.default \
    hwcomposer.raphael

# glrenderd's chroot from tools/glrenderd/stage.py. It lives outside
# vendor/xiaomi/raphael so sync-device-tree.sh's rsync --delete leaves it
# alone. The Adreno firmware also goes where KitKat's kernel firmware
# loader looks (/vendor/firmware -> /system/vendor/firmware).
GLR_DIR := vendor/xiaomi/raphael-glr
ifneq ($(wildcard $(GLR_DIR)/root/glrenderd),)
PRODUCT_COPY_FILES += \
    $(foreach f,$(shell cd $(GLR_DIR) && find . -type f -printf '%P\n'),$(GLR_DIR)/$(f):system/glr/$(f)) \
    $(foreach f,$(shell cd $(GLR_DIR)/root/vendor/firmware && ls),$(GLR_DIR)/root/vendor/firmware/$(f):system/vendor/firmware/$(f))
endif
