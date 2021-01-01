using System;
using System.Collections;
using System.Collections.Generic;
using System.Security.Cryptography;
using UnityEngine;
using UnityEngine.Video;

[RequireComponent(typeof(Camera))]
public class CRTImageEffect : MonoBehaviour
{
    public Material material;

    
    void Start()
    {
        if (material == null)
        {
                Destroy(this);
        }
    }

    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        material.SetFloat("_ScanlineNumbers", Screen.height);
        material.SetFloat("_frameCount", Time.frameCount);
        Graphics.Blit(src, dest, material);
    }
}
