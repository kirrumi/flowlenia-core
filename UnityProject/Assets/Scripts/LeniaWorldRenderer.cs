using UnityEngine;

[RequireComponent(typeof(Renderer))]
public class LeniaWorldRenderer : MonoBehaviour
{
    public LeniaWorldManager worldManager;

    private MaterialPropertyBlock propBlock;
    private static readonly int MainTex = Shader.PropertyToID("_MainTex");

    void Start()
    {
        propBlock = new MaterialPropertyBlock();
    }

    void Update()
    {
        if (worldManager == null) return;
        if (!worldManager.IsInitialized()) return;

        var tex = worldManager.GetDisplayTexture();
        if (tex == null) return;

        var renderer = GetComponent<Renderer>();
        renderer.GetPropertyBlock(propBlock);
        propBlock.SetTexture(MainTex, tex);
        renderer.SetPropertyBlock(propBlock);
    }
}
