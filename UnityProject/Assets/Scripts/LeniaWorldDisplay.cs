using UnityEngine;

public class LeniaWorldDisplay : MonoBehaviour
{
    [Header("Lenia Parameters")]
    public int worldSize = 256;
    public int T = 8;
    public bool useOrbium = false;

    private System.IntPtr leniaHandle;
    private float[] renderBuffer;
    private Color32[] colorBuffer;
    private Texture2D displayTexture;
    private bool ready = false;

    void Start()
    {
        int nbChannels, nbRules;
        float[] channels, rules;

        if (useOrbium)
        {
            nbChannels = 1; nbRules = 1;
            channels = new float[] { 0f, 1f, 0f, 0.2f };
            rules = new float[] { 0, 0, 15, 1f, 1, 4f, 1f, 0f, 0.14f, 0.014f, 1f };
        }
        else
        {
            nbChannels = 3; nbRules = 15;
            channels = new float[] { 1f,0f,0f,0.5f, 0f,1f,0f,0.5f, 0f,0f,1f,0.5f };
            rules = new float[]
            {
                0,0,12,0.91f,1,4f,1f,0f,0.272f,0.0595f,0.19f,
                0,0,12,0.62f,1,4f,1f,0f,0.349f,0.1585f,0.66f,
                0,0,12,0.5f,2,4f,1f,0.25f,0.2f,0.0332f,0.39f,
                1,1,12,0.97f,2,4f,0f,1f,0.114f,0.0528f,0.38f,
                1,1,12,0.72f,1,4f,1f,0f,0.447f,0.0777f,0.74f,
                1,1,12,0.8f,2,4f,0.833f,1f,0.247f,0.0342f,0.92f,
                2,2,12,0.96f,1,4f,1f,0f,0.21f,0.0617f,0.59f,
                2,2,12,0.56f,1,4f,1f,0f,0.462f,0.1192f,0.37f,
                2,2,12,0.78f,1,4f,1f,0f,0.446f,0.1793f,0.94f,
                0,1,12,0.79f,2,4f,0.917f,1f,0.327f,0.1408f,0.51f,
                0,2,12,0.5f,2,4f,0.75f,1f,0.476f,0.0995f,0.77f,
                1,0,12,0.72f,2,4f,0.917f,1f,0.379f,0.0697f,0.92f,
                1,2,12,0.68f,1,4f,1f,0f,0.262f,0.0877f,0.71f,
                2,0,12,0.55f,2,4f,0.167f,1f,0.412f,0.1101f,0.59f,
                2,1,12,0.82f,1,4f,1f,0f,0.201f,0.0786f,0.41f
            };
        }

        leniaHandle = LeniaPlugin.Lenia_Create(worldSize, T, nbChannels, nbRules, channels, rules);
        if (leniaHandle == System.IntPtr.Zero)
        {
            Debug.LogError("Lenia creation failed!");
            return;
        }

        worldSize = LeniaPlugin.Lenia_GetSize(leniaHandle);
        renderBuffer = new float[worldSize * worldSize * 4];

        // read diagnostic from DLL
        var sb = new System.Text.StringBuilder(256);
        LeniaPlugin.Lenia_GetErrorMsg(leniaHandle, sb, sb.Capacity);
        Debug.Log("DLL diag: " + sb.ToString());
        colorBuffer = new Color32[worldSize * worldSize];
        displayTexture = new Texture2D(worldSize, worldSize, TextureFormat.RGBA32, false);
        displayTexture.filterMode = FilterMode.Point;
        displayTexture.wrapMode = TextureWrapMode.Clamp;
        ready = true;

        Debug.Log($"Lenia {worldSize}x{worldSize} ready");
    }

    int debugFrames = 0;

    void Update()
    {
        if (!ready) return;
        LeniaPlugin.Lenia_TickAndRender(leniaHandle, renderBuffer);

        int total = worldSize * worldSize;

        // debug: log first frame values
        if (debugFrames < 10)
        {
            debugFrames++;
            string log = $"Frame {debugFrames}: ";
            for (int i = 0; i < 5; i++)
                log += $" [{renderBuffer[i*4]:F3},{renderBuffer[i*4+1]:F3},{renderBuffer[i*4+2]:F3}]";
            Debug.Log(log);
        }

        for (int i = 0; i < total; i++)
        {
            int idx = i * 4;
            colorBuffer[i] = new Color32(
                (byte)Mathf.Clamp(renderBuffer[idx] * 255f, 0, 255),
                (byte)Mathf.Clamp(renderBuffer[idx + 1] * 255f, 0, 255),
                (byte)Mathf.Clamp(renderBuffer[idx + 2] * 255f, 0, 255),
                255
            );
        }
        displayTexture.SetPixels32(colorBuffer);
        displayTexture.Apply(false);
    }

    void OnGUI()
    {
        if (!ready || displayTexture == null) return;
        float size = Mathf.Min(Screen.width, Screen.height);
        float x = (Screen.width - size) * 0.5f;
        float y = (Screen.height - size) * 0.5f;
        GUI.DrawTexture(new Rect(x, y, size, size), displayTexture);
    }

    void OnDestroy()
    {
        if (leniaHandle != System.IntPtr.Zero)
        {
            LeniaPlugin.Lenia_Destroy(leniaHandle);
            leniaHandle = System.IntPtr.Zero;
        }
    }
}
