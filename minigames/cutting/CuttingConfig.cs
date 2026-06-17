using Godot;

namespace KaijuBreakdown.Minigames.Cutting;

public static class CuttingConfig
{
    public const int BladeWidth = 10;
    public const int BladeExtension = 30;
    public const int BladeLength = 40;

    public const int CutterSpeed = 100;
    public const float SliceInterval = 0.1f;
    public const float CursorTransitionDuration = 0.18f;
    public const float CursorTransitionLiftScale = 1.15f;

    public const float SliceShakeStrength = 3.0f;
    public const float SliceShakeDecay = 24.0f;

    public const float CuttingJitterPx = 1.25f;

    public const float ArcWidthDegrees = 45f;
    public const float OscillationFrequency = 2.0f;
    public const float ArcRadius = 100.0f;

    public const int InterfaceZIndex = 100;
    public const int KaijuZIndex = 0;

    public const float CutPathWidth = 4.0f;
    public static readonly Color CutPathColor = new(1, 0.2f, 0.2f, 0.8f);

    public const float ArcLineWidth = 3.0f;
    public static readonly Color ArcLineColor = new(1, 1, 1, 0.7f);

    public const float DirectionLineWidth = 1.0f;
    public static readonly Color DirectionLineColor = new(1, 1, 1, 0.9f);

    public const float HarvestableAreaThreshold = 50.0f;
    public static readonly Color HarvestableHighlight = new(0.55f, 1.0f, 0.65f, 1.0f);
}
