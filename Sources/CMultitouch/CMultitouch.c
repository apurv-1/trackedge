#include "CMultitouch.h"

#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <os/lock.h>

typedef void *MTDeviceRef;
typedef CFTypeRef MTActuatorRef;
typedef int (*MTContactCallback)(MTDeviceRef, const LMTTouch *, int32_t, double, int32_t);

static CFArrayRef (*MTDeviceCreateList)(void);
static void (*MTRegisterContactFrameCallback)(MTDeviceRef, MTContactCallback);
static void (*MTUnregisterContactFrameCallback)(MTDeviceRef, MTContactCallback);
static int32_t (*MTDeviceStart)(MTDeviceRef, int32_t);
static int32_t (*MTDeviceStop)(MTDeviceRef);
static int32_t (*MTDeviceGetFamilyID)(MTDeviceRef, int32_t *);
static bool (*MTDeviceIsBuiltIn)(MTDeviceRef);
static int32_t (*MTDeviceGetDeviceID)(MTDeviceRef, uint64_t *);
static MTActuatorRef (*MTActuatorCreateFromDeviceID)(uint64_t);
static int32_t (*MTActuatorOpen)(MTActuatorRef);
static int32_t (*MTActuatorClose)(MTActuatorRef);
static int32_t (*MTActuatorActuate)(MTActuatorRef, int32_t, uint32_t, float, float);

enum { kMaxDevices = 8 };

typedef struct {
    MTDeviceRef device;
    int32_t family;
    bool builtIn;
    MTActuatorRef actuator;
} Slot;

static os_unfair_lock gLock = OS_UNFAIR_LOCK_INIT;
static CFArrayRef gList;
static Slot gSlots[kMaxDevices];
static int32_t gCount;
static LMTFrameHandler gHandler;
static void *gContext;

bool LMTLoad(void) {
    static bool loaded;
    if (loaded) return true;

    void *mt = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW);
    if (!mt) return false;

    MTDeviceCreateList = dlsym(mt, "MTDeviceCreateList");
    MTRegisterContactFrameCallback = dlsym(mt, "MTRegisterContactFrameCallback");
    MTUnregisterContactFrameCallback = dlsym(mt, "MTUnregisterContactFrameCallback");
    MTDeviceStart = dlsym(mt, "MTDeviceStart");
    MTDeviceStop = dlsym(mt, "MTDeviceStop");
    MTDeviceGetFamilyID = dlsym(mt, "MTDeviceGetFamilyID");
    MTDeviceIsBuiltIn = dlsym(mt, "MTDeviceIsBuiltIn");
    // Haptics are optional: a missing actuator API only disables the tick.
    MTDeviceGetDeviceID = dlsym(mt, "MTDeviceGetDeviceID");
    MTActuatorCreateFromDeviceID = dlsym(mt, "MTActuatorCreateFromDeviceID");
    MTActuatorOpen = dlsym(mt, "MTActuatorOpen");
    MTActuatorClose = dlsym(mt, "MTActuatorClose");
    MTActuatorActuate = dlsym(mt, "MTActuatorActuate");

    loaded = MTDeviceCreateList && MTRegisterContactFrameCallback && MTUnregisterContactFrameCallback
        && MTDeviceStart && MTDeviceStop && MTDeviceGetFamilyID && MTDeviceIsBuiltIn;
    return loaded;
}

static int contactCallback(MTDeviceRef device, const LMTTouch *touches, int32_t count, double timestamp, int32_t frame) {
    (void)frame;
    os_unfair_lock_lock(&gLock);
    int32_t index = -1;
    for (int32_t i = 0; i < gCount; i++) {
        if (gSlots[i].device == device) { index = i; break; }
    }
    LMTFrameHandler handler = gHandler;
    void *context = gContext;
    os_unfair_lock_unlock(&gLock);

    if (index >= 0 && handler) handler(index, touches, count, timestamp, context);
    return 0;
}

static MTActuatorRef openActuator(MTDeviceRef device) {
    if (!MTDeviceGetDeviceID || !MTActuatorCreateFromDeviceID || !MTActuatorOpen || !MTActuatorActuate) return NULL;
    uint64_t deviceID = 0;
    if (MTDeviceGetDeviceID(device, &deviceID) != 0 || deviceID == 0) return NULL;
    MTActuatorRef actuator = MTActuatorCreateFromDeviceID(deviceID);
    if (!actuator) return NULL;
    if (MTActuatorOpen(actuator) != 0) {
        CFRelease(actuator);
        return NULL;
    }
    return actuator;
}

void LMTStop(void) {
    os_unfair_lock_lock(&gLock);
    Slot slots[kMaxDevices];
    int32_t count = gCount;
    for (int32_t i = 0; i < count; i++) slots[i] = gSlots[i];
    CFArrayRef list = gList;
    gCount = 0;
    gList = NULL;
    gHandler = NULL;
    gContext = NULL;
    os_unfair_lock_unlock(&gLock);

    for (int32_t i = 0; i < count; i++) {
        MTUnregisterContactFrameCallback(slots[i].device, contactCallback);
        MTDeviceStop(slots[i].device);
        if (slots[i].actuator) {
            if (MTActuatorClose) MTActuatorClose(slots[i].actuator);
            CFRelease(slots[i].actuator);
        }
    }
    // Releasing the list releases the devices it owns.
    if (list) CFRelease(list);
}

int32_t LMTStart(LMTFrameHandler handler, void *context) {
    if (!LMTLoad()) return 0;
    LMTStop();

    CFArrayRef list = MTDeviceCreateList();
    if (!list) return 0;

    Slot slots[kMaxDevices];
    int32_t count = 0;
    CFIndex total = CFArrayGetCount(list);
    for (CFIndex i = 0; i < total && count < kMaxDevices; i++) {
        MTDeviceRef device = (MTDeviceRef)CFArrayGetValueAtIndex(list, i);
        int32_t family = -1;
        MTDeviceGetFamilyID(device, &family);
        slots[count++] = (Slot){ device, family, MTDeviceIsBuiltIn(device), openActuator(device) };
    }

    // Publish the slots before registering, so the first frame finds its device.
    os_unfair_lock_lock(&gLock);
    for (int32_t i = 0; i < count; i++) gSlots[i] = slots[i];
    gCount = count;
    gList = list;
    gHandler = handler;
    gContext = context;
    os_unfair_lock_unlock(&gLock);

    for (int32_t i = 0; i < count; i++) {
        MTRegisterContactFrameCallback(slots[i].device, contactCallback);
        MTDeviceStart(slots[i].device, 0);
    }
    return count;
}

int32_t LMTDeviceFamily(int32_t deviceIndex) {
    os_unfair_lock_lock(&gLock);
    int32_t family = (deviceIndex >= 0 && deviceIndex < gCount) ? gSlots[deviceIndex].family : -1;
    os_unfair_lock_unlock(&gLock);
    return family;
}

bool LMTDeviceIsBuiltIn(int32_t deviceIndex) {
    os_unfair_lock_lock(&gLock);
    bool builtIn = deviceIndex >= 0 && deviceIndex < gCount && gSlots[deviceIndex].builtIn;
    os_unfair_lock_unlock(&gLock);
    return builtIn;
}

bool LMTActuate(int32_t deviceIndex, int32_t actuationID) {
    os_unfair_lock_lock(&gLock);
    MTActuatorRef actuator = (deviceIndex >= 0 && deviceIndex < gCount) ? gSlots[deviceIndex].actuator : NULL;
    if (actuator) CFRetain(actuator);
    os_unfair_lock_unlock(&gLock);

    if (!actuator) return false;
    bool ok = MTActuatorActuate(actuator, actuationID, 0, 0.0f, 0.0f) == 0;
    CFRelease(actuator);
    return ok;
}
