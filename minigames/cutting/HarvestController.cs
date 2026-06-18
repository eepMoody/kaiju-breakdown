using Godot;
using KaijuBreakdown.Core;

namespace KaijuBreakdown.Minigames.Cutting;

// Intentionally left max size and duration exposed for upgrades.
public partial class HarvestController : Node2D
{
    [Signal]
    public delegate void HarvestedEventHandler(float area);

    public float MaxSize { get; set; } = CuttingConfig.HarvestMaxSize;
    public float Duration { get; set; } = CuttingConfig.HarvestDuration;

    private static readonly Vector2 IndicatorTopLeft = new(-360, -270);

    public override void _Ready() => ZIndex = CuttingConfig.InterfaceZIndex;

    public override void _Process(double delta)
    {
        RefreshHighlights();
        QueueRedraw();
    }

    public override void _Draw()
    {
        var rect = new Rect2(IndicatorTopLeft, new Vector2(MaxSize, MaxSize));
        Color color = CuttingConfig.HarvestableHighlight;
        DrawRect(rect, new Color(color, 0.12f));
        DrawRect(rect, color, filled: false, width: 2.0f);

        Font font = ThemeDB.FallbackFont;
        if (font != null)
        {
            DrawString(font, IndicatorTopLeft + new Vector2(0, MaxSize + 18),
                "Harvestable size", HorizontalAlignment.Left, -1, ThemeDB.FallbackFontSize, color);
        }
    }

    public bool IsHarvestable(Polygon2D polygon) =>
        polygon.Polygon.Length >= 3 &&
        PolygonSlicePlugin.GetPolygonArea(polygon.Polygon) <= MaxSize * MaxSize;

    public void Harvest(Polygon2D polygon)
    {
        float area = PolygonSlicePlugin.GetPolygonArea(polygon.Polygon);
        (polygon.GetParent() as RigidBody2D ?? (Node2D)polygon).QueueFree();
        EmitSignal(SignalName.Harvested, area);
    }

    private void RefreshHighlights()
    {
        foreach (Node child in GetParent().GetChildren())
        {
            Polygon2D? polygon = Piece(child);
            if (polygon != null)
            {
                polygon.Modulate = IsHarvestable(polygon)
                    ? CuttingConfig.HarvestableHighlight
                    : Colors.White;
            }
        }
    }

    private static Polygon2D? Piece(Node node)
    {
        if (node is Polygon2D polygon)
        {
            return polygon;
        }
        if (node is RigidBody2D body)
        {
            foreach (Node child in body.GetChildren())
            {
                if (child is Polygon2D wrapped)
                {
                    return wrapped;
                }
            }
        }
        return null;
    }
}
