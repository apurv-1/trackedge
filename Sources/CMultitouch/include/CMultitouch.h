#ifndef CMULTITOUCH_H
#define CMULTITOUCH_H

#include <stdbool.h>
#include <stdint.h>

/// One finger as reported by MultitouchSupport. The layout mirrors the private
/// framework's struct, so it must not be reordered.
typedef struct {
    float x;
    float y;
} LMTPoint;

typedef struct {
    LMTPoint position;
    LMTPoint velocity;
} LMTVector;

typedef struct {
    int32_t frame;
    double timestamp;
    int32_t identifier;
    int32_t state;
    int32_t fingerID;
    int32_t handID;
    LMTVector normalized;
    float size;
    int32_t reserved1;
    float angle;
    float majorAxis;
    float minorAxis;
    LMTVector millimeters;
    int32_t reserved2[2];
    float density;
} LMTTouch;

/// Called on a MultitouchSupport thread for every frame of every started device.
typedef void (*LMTFrameHandler)(int32_t deviceIndex, const LMTTouch *touches, int32_t count, double timestamp, void *context);

/// Loads the private framework. Returns false when it or a required symbol is missing.
bool LMTLoad(void);

/// Starts every multitouch device and routes frames to `handler`.
/// Any running session is stopped first. Returns the number of started devices.
int32_t LMTStart(LMTFrameHandler handler, void *context);

/// Stops and releases every device started by `LMTStart`.
void LMTStop(void);

/// Family ID of a started device, or -1 when unknown. Magic Mouse reports 112 or 113.
int32_t LMTDeviceFamily(int32_t deviceIndex);

bool LMTDeviceIsBuiltIn(int32_t deviceIndex);

/// Plays a haptic click on a Force Touch trackpad. `actuationID` picks the waveform.
/// Returns false when the device has no actuator.
bool LMTActuate(int32_t deviceIndex, int32_t actuationID);

#endif
