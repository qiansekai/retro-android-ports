LOCAL_PATH := $(call my-dir)

# Minimal HWC 1.1 so SurfaceFlinger does not require fbdev on raphael.
# Named hwcomposer.raphael so hw_get_module() picks it via
# ro.board.platform=raphael; no hwcomposer.default is shipped.
include $(CLEAR_VARS)
LOCAL_MODULE := hwcomposer.raphael
LOCAL_MODULE_PATH := $(TARGET_OUT_SHARED_LIBRARIES)/hw
LOCAL_MODULE_TAGS := optional
LOCAL_SRC_FILES := hwcomposer.cpp
LOCAL_SHARED_LIBRARIES := liblog libcutils libEGL libhardware
LOCAL_C_INCLUDES := hardware/libhardware/include
LOCAL_CFLAGS := -Wno-unused-parameter
include $(BUILD_SHARED_LIBRARY)
