using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class BuildGraph : MonoBehaviour
{
    [SerializeField]
    Transform pointPrefab;
    
    [SerializeField, Range(10, 100)]
    int resolution = 10;

    [SerializeField]
    FunctionLibrary.FunctionName function;

    Transform[] points;

    private void Awake()
    {
        float step = 2f / resolution;
        Vector3 position = default;
        var scale = Vector3.one* step;
        points = new Transform[resolution];
        for (int i = 0; i < points.Length; i++)
        {
            Transform point = points[i] = Instantiate(pointPrefab);
            point.SetParent(transform, false);
            position.x = (i + 0.5f) * step - 1f;
            //position.y = position.x * position.x * position.x;
            point.localPosition = position;
            point.localScale = scale;
        }
    }

    void Update()
    {
        float time = Time.time;
        for (int i = 0; i < points.Length; i++)
        {
            Transform point = points[i];
            Vector3 position = point.localPosition;
            position.y = FunctionLibrary.GetFunction(function)(position.x, time);
            point.localPosition = position;
        }
    }
}
