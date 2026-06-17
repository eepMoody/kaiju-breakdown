using Godot;

namespace KaijuBreakdown.Minigames.Cutting;

public partial class SoftwareCursor : Sprite2D
{
    public override void _Ready()
    {
        ZIndex = (int)RenderingServer.CanvasItemZMax;
        ZAsRelative = false;
        Input.MouseMode = Input.MouseModeEnum.Hidden;
    }

    public override void _Process(double delta)
    {
        GlobalPosition = GetGlobalMousePosition();
    }

    public override void _ExitTree()
    {
        Input.MouseMode = Input.MouseModeEnum.Visible;
    }
}
