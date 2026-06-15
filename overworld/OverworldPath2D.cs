using Godot;

namespace KaijuBreakdown.Overworld;

public partial class OverworldPath2D : Path2D
{
    public override void _Ready()
    {
        var line = GetNodeOrNull<Line2D>("highlight_display");
        if (line != null && Curve != null)
        {
            line.Points = Curve.GetBakedPoints();
            line.Width = 10;
            line.DefaultColor = Colors.Yellow;
        }
    }
}
