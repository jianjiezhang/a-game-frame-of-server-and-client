using UnityEngine;

public class GameStart : MonoBehaviour
{
    void Awake()
    {
        var go = new GameObject("Main");
        go.AddComponent<Main>();
    }
}
