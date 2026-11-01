#pragma once
#include "Mode.h"

namespace cuLenia {
    class DeviceHeadlessMode : public Mode {
    public:
        DeviceHeadlessMode(int size, int T, int nbChannels, int nbRules, float channels[][4], float rules[][11]);
        ~DeviceHeadlessMode();
        void compute(bool render, bool batchFFT);
        void render(int w, int h) {} // no-op
        void getChannelData(int channel, float* outHost);
        void getComposited(float* outRGBA);
        int getSize() { return lw.size; }
        float* getRenderBuffer() { return renderBuffer; }
        int getNbChannels() { return lw.nbChannels; }
    private:
    float* channelBuffer;
    float* renderBuffer;
    float* devRenderBuffer;
    int size;
    int nbChannels;
public:
    int lastError;
    char errorMsg[256];
    };
}
