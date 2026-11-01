#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <cuda_runtime.h>
#include <math.h>

#include "DeviceHeadlessMode.h"
using namespace cuLenia;

__global__ void testKernelSimple(int* outVal)
{
    *outVal = 42;
}

__global__ void fillRenderKernel(float* buf, int size)
{
    int i = threadIdx.y + blockIdx.y * blockDim.y;
    int j = threadIdx.x + blockIdx.x * blockDim.x;
    if (i < size && j < size) {
        int idx = (i * size + j) * 4;
        buf[idx] = 1.0f;
        buf[idx + 1] = 0.0f;
        buf[idx + 2] = 0.0f;
        buf[idx + 3] = 1.0f;
    }
}

DeviceHeadlessMode::DeviceHeadlessMode(int size, int T, int nbChannels, int nbRules, float channels[][4], float rules[][11])
{
    lastError = 0;
    errorMsg[0] = 0;

    // DIAG: check CUDA device
    int deviceCount = 0;
    cudaError_t ce = cudaGetDeviceCount(&deviceCount);
    sprintf(errorMsg, "cudaGetDeviceCount=%d, count=%d", ce, deviceCount);
    if (ce != cudaSuccess || deviceCount == 0) {
        lastError = -1;
    }

    if (deviceCount > 0) {
        cudaDeviceProp prop;
        cudaGetDeviceProperties(&prop, 0);
        char tmp[128];
        sprintf(tmp, "; GPU=%s, CC=%d.%d", prop.name, prop.major, prop.minor);
        strcat(errorMsg, tmp);
    }

    lw.toGridB = true;
    lw.nbChannels = nbChannels;
    lw.nbRules = nbRules;
    lw.size = size;
    lw.T = T;

    srand(time(NULL));

    for (int i = 0; i < lw.nbChannels; i++)
    {
        lw.color[i] = make_float4(channels[i][0], channels[i][1], channels[i][2], 1.0f);
        lw.gridA[i] = randomGrid(lw.size, channels[i][3]);
        lw.gridB[i] = (float*)calloc(lw.size * lw.size, sizeof(float));
        lw.gridA64[i] = 0;
        lw.gridB64[i] = 0;
        lw.gridA16[i] = 0;
        lw.gridB16[i] = 0;
    }

    for (int i = 0; i < lw.nbRules; i++)
    {
        lw.rule[i].source = (int)rules[i][0];
        lw.rule[i].destination = (int)rules[i][1];
        lw.rule[i].radius = (int)rules[i][2];
        lw.rule[i].mu = rules[i][8];
        lw.rule[i].sigma2 = 2 * rules[i][9] * rules[i][9];
        lw.rule[i].weight = rules[i][10];
        float b[MAX_RANK];
        b[0] = rules[i][6]; b[1] = rules[i][7];
        lw.kernel[i] = initKernel((int)rules[i][2], rules[i][3], (int)rules[i][4], rules[i][5], b);
        lw.kernel64[i] = 0;
        lw.kernel16[i] = 0;
    }

    this->size = lw.size;
    this->nbChannels = lw.nbChannels;

    cudaMemcpyToSymbol(constantRule, lw.rule, MAX_RULES * sizeof(Rule));
    cudaMemcpyToSymbol(constantColor, lw.color, MAX_CHANNELS * sizeof(float4));

    for (int i = 0; i < lw.nbChannels; i++)
    {
        float* dA, * dB;
        checkCudaErrors(cudaMalloc((void**)&dA, lw.size * lw.size * sizeof(float)));
        checkCudaErrors(cudaMalloc((void**)&dB, lw.size * lw.size * sizeof(float)));
        checkCudaErrors(cudaMemcpy(dA, lw.gridA[i], lw.size * lw.size * sizeof(float), cudaMemcpyHostToDevice));
        checkCudaErrors(cudaMemset(dB, 0, lw.size * lw.size * sizeof(float)));
        free(lw.gridA[i]);
        free(lw.gridB[i]);
        lw.gridA[i] = dA;
        lw.gridB[i] = dB;
    }

    for (int i = 0; i < lw.nbRules; i++)
    {
        int w = 2 * lw.rule[i].radius + 1;
        float* dK;
        checkCudaErrors(cudaMalloc((void**)&dK, w * w * sizeof(float)));
        checkCudaErrors(cudaMemcpy(dK, lw.kernel[i], w * w * sizeof(float), cudaMemcpyHostToDevice));
        free(lw.kernel[i]);
        lw.kernel[i] = dK;
    }

    int total = lw.size * lw.size;
    cudaMallocHost((void**)&channelBuffer, total * nbChannels * sizeof(float));
    cudaMallocHost((void**)&renderBuffer, total * 4 * sizeof(float));
    cudaMalloc(&devRenderBuffer, total * 4 * sizeof(float));
}

void DeviceHeadlessMode::compute(bool render, bool batchFFT)
{
    int total = size * size;
    lastError = 0;
    errorMsg[0] = 0;

    // === DIAG 1: test simple kernel ===
    int* devVal = 0;
    cudaMalloc(&devVal, sizeof(int));
    cudaMemset(devVal, 0, sizeof(int));
    testKernelSimple << <1, 1 >> > (devVal);
    cudaError_t err = cudaDeviceSynchronize();
    int hostVal = 0;
    cudaMemcpy(&hostVal, devVal, sizeof(int), cudaMemcpyDeviceToHost);
    cudaFree(devVal);
    sprintf(errorMsg, "simpleKernel returned %d (syncErr=%d)", hostVal, err);

    if (err != cudaSuccess) {
        return; // kernel launch failed, leave renderBuffer as-is
    }

    // === DIAG 2: write to cudaMalloc devRenderBuffer, then cudaMemcpy to renderBuffer ===
    cudaError_t err2;
    dim3 dimBlock16(16, 16);
    dim3 dimGrid16((size + 15) / 16, (size + 15) / 16);

    fillRenderKernel << <dimGrid16, dimBlock16 >> > (devRenderBuffer, size);
    err2 = cudaDeviceSynchronize();
    sprintf(errorMsg + strlen(errorMsg), " | fillDev syncErr=%d", err2);

    if (err2 == cudaSuccess) {
        cudaMemcpy(renderBuffer, devRenderBuffer, size * size * 4 * sizeof(float), cudaMemcpyDeviceToHost);
    }
}

void DeviceHeadlessMode::getChannelData(int channel, float* outHost)
{
    int total = size * size;
    float* src;
    if (lw.toGridB)
        src = lw.gridA[channel];
    else
        src = lw.gridB[channel];
    cudaMemcpy(outHost, src, total * sizeof(float), cudaMemcpyDeviceToHost);
}

void DeviceHeadlessMode::getComposited(float* outRGBA)
{
    int total = size * size;
    memcpy(outRGBA, renderBuffer, total * 4 * sizeof(float));
}

DeviceHeadlessMode::~DeviceHeadlessMode()
{
    for (int i = 0; i < lw.nbRules; i++)
        cudaFree(lw.kernel[i]);

    for (int i = 0; i < lw.nbChannels; i++) {
        cudaFree(lw.gridA[i]);
        cudaFree(lw.gridB[i]);
    }
    cudaFreeHost(channelBuffer);
    cudaFreeHost(renderBuffer);
    cudaFree(devRenderBuffer);
}
