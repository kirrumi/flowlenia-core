using System;
using System.Runtime.InteropServices;
using UnityEngine;

public static class LeniaPlugin
{
    [DllImport("LeniaUnityBridge")]
    public static extern IntPtr Lenia_Create(int size, int T, int nbChannels, int nbRules,
        float[] channelData, float[] ruleData);

    [DllImport("LeniaUnityBridge")]
    public static extern void Lenia_Destroy(IntPtr handle);

    [DllImport("LeniaUnityBridge")]
    public static extern void Lenia_Tick(IntPtr handle);

    [DllImport("LeniaUnityBridge")]
    public static extern void Lenia_TickAndRender(IntPtr handle, float[] outputRGBA);

    [DllImport("LeniaUnityBridge")]
    public static extern void Lenia_GetChannelData(IntPtr handle, int channel, float[] output);

    [DllImport("LeniaUnityBridge")]
    public static extern void Lenia_GetRenderData(IntPtr handle, float[] outputRGBA);

    [DllImport("LeniaUnityBridge")]
    public static extern int Lenia_GetSize(IntPtr handle);

    [DllImport("LeniaUnityBridge")]
    public static extern int Lenia_GetNbChannels(IntPtr handle);

    [DllImport("LeniaUnityBridge")]
    public static extern int Lenia_GetT(IntPtr handle);

    [DllImport("LeniaUnityBridge")]
    public static extern void Lenia_SetCell(IntPtr handle, int channel, int x, int y, float value);

    [DllImport("LeniaUnityBridge")]
    public static extern void Lenia_SeedChannel(IntPtr handle, int channel, float[] data);

    [DllImport("LeniaUnityBridge")]
    public static extern void Lenia_DebugFill(float[] buf, int count);

    [DllImport("LeniaUnityBridge", CharSet = CharSet.Ansi)]
    public static extern void Lenia_GetErrorMsg(System.IntPtr handle, System.Text.StringBuilder outBuf, int maxLen);
}
