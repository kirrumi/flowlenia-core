#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>
#include <math.h>

#include "../DeviceHeadlessMode.h"
using namespace cuLenia;

#define EXPORT __declspec(dllexport)

typedef struct {
    DeviceHeadlessMode* mode;
    int size;
    int nbChannels;
} LeniaInstance;

extern "C" {

    EXPORT void* Lenia_Create(int size, int T, int nbChannels, int nbRules,
        float* channelData, float* ruleData)
    {
        LeniaInstance* inst = (LeniaInstance*)calloc(1, sizeof(LeniaInstance));

        float(*channels)[4] = (float(*)[4])channelData;
        float(*rules)[11] = (float(*)[11])ruleData;

        inst->mode = new DeviceHeadlessMode(size, T, nbChannels, nbRules, channels, rules);
        inst->size = inst->mode->getSize();
        inst->nbChannels = inst->mode->getNbChannels();

        return (void*)inst;
    }

    EXPORT void Lenia_Destroy(void* handle)
    {
        if (!handle) return;
        LeniaInstance* inst = (LeniaInstance*)handle;
        delete inst->mode;
        free(inst);
    }

    EXPORT void Lenia_Tick(void* handle)
    {
        if (!handle) return;
        LeniaInstance* inst = (LeniaInstance*)handle;
        inst->mode->compute(false, false);
    }

    EXPORT void Lenia_TickAndRender(void* handle, float* outputRGBA)
    {
        if (!handle) return;
        LeniaInstance* inst = (LeniaInstance*)handle;
        inst->mode->compute(true, false);
        if (outputRGBA) {
            int total = inst->size * inst->size;
            memcpy(outputRGBA, inst->mode->getRenderBuffer(), total * 4 * sizeof(float));
        }
    }

    EXPORT void Lenia_GetChannelData(void* handle, int channel, float* output)
    {
        if (!handle || !output) return;
        LeniaInstance* inst = (LeniaInstance*)handle;
        if (channel < 0 || channel >= inst->nbChannels) return;
        inst->mode->getChannelData(channel, output);
    }

    EXPORT void Lenia_GetComposited(void* handle, float* outputRGBA)
    {
        if (!handle || !outputRGBA) return;
        LeniaInstance* inst = (LeniaInstance*)handle;
        int total = inst->size * inst->size;
        memcpy(outputRGBA, inst->mode->getRenderBuffer(), total * 4 * sizeof(float));
    }

    EXPORT int Lenia_GetSize(void* handle)
    {
        if (!handle) return 0;
        return ((LeniaInstance*)handle)->size;
    }

    EXPORT int Lenia_GetNbChannels(void* handle)
    {
        if (!handle) return 0;
        return ((LeniaInstance*)handle)->nbChannels;
    }

    EXPORT int Lenia_GetT(void* handle)
    {
        if (!handle) return 0;
        return ((LeniaInstance*)handle)->mode->lw.T;
    }

    EXPORT void Lenia_SetCell(void* handle, int channel, int x, int y, float value)
    {
        if (!handle) return;
        LeniaInstance* inst = (LeniaInstance*)handle;
        if (channel < 0 || channel >= inst->nbChannels) return;
        if (x < 0 || x >= inst->size || y < 0 || y >= inst->size) return;

        int idx = y * inst->size + x;
        float* dst;
        if (inst->mode->lw.toGridB)
            dst = inst->mode->lw.gridA[channel];
        else
            dst = inst->mode->lw.gridB[channel];
        cudaMemcpy(dst + idx, &value, sizeof(float), cudaMemcpyHostToDevice);
    }

    EXPORT void Lenia_SeedChannel(void* handle, int channel, float* data)
    {
        if (!handle) return;
        LeniaInstance* inst = (LeniaInstance*)handle;
        if (channel < 0 || channel >= inst->nbChannels) return;

        int total = inst->size * inst->size;
        float* dst;
        if (inst->mode->lw.toGridB)
            dst = inst->mode->lw.gridA[channel];
        else
            dst = inst->mode->lw.gridB[channel];
        cudaMemcpy(dst, data, total * sizeof(float), cudaMemcpyHostToDevice);
    }

    EXPORT void Lenia_DebugFill(float* buf, int count)
    {
        for (int i = 0; i < count; i++)
            buf[i] = 0.123f;
    }

    EXPORT void Lenia_GetErrorMsg(void* handle, char* outBuf, int maxLen)
    {
        if (!handle || !outBuf || maxLen <= 0) return;
        LeniaInstance* inst = (LeniaInstance*)handle;
        outBuf[0] = 0;
        strncat_s(outBuf, maxLen, inst->mode->errorMsg, _TRUNCATE);
    }

}
