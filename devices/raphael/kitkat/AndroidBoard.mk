# AndroidBoard.mk for raphael (KitKat)
LOCAL_PATH := $(call my-dir)

# Prebuilt kernel: Lineage 4.14 Image.gz extracted from boot.img.
# Packed into a header-v2 boot image outside the KitKat build system;
# this target only satisfies the build graph.
file := $(INSTALLED_KERNEL_TARGET)
ALL_PREBUILT += $(file)
$(file): $(TARGET_PREBUILT_KERNEL) | $(ACP)
	$(transform-prebuilt-to-target)
