using Godot;

namespace KaijuBreakdown.Overworld;

[GlobalClass]
public partial class InteractableArea : Area2D
{
    [Signal]
    public delegate void InteractedEventHandler(InteractableArea area);

    [Export] public string PartId { get; set; } = "";
    [Export] public string PartSvgPath { get; set; } = "";
    [Export] public Texture2D? PartTexture { get; set; }
    [Export] public PackedScene? InteractionScene { get; set; }

    [ExportGroup("Highlight")]
    [Export] public Color HighlightColor { get; set; } = Colors.Yellow;
    [Export] public float HighlightWidth { get; set; } = 10.0f;

    private Path2D? _highlight;

    public bool IsActive { get; private set; }

    public override void _Ready()
    {
        _highlight = GetNode<Path2D>("HighlightPath");

        CollisionLayer = 2;
        CollisionMask = 1;
        BodyEntered += OnBodyEntered;
        BodyExited += OnBodyExited;
        PartId = Name;
        if (_highlight != null)
        {
            _highlight.Visible = false;
        }
    }

    private void OnBodyEntered(Node2D body)
    {
        IsActive = true;
        GetTree().CallGroup("kaiju_manager", "NotifyAreaEntered", this);
    }

    private void OnBodyExited(Node2D body)
    {
        IsActive = false;
        GetTree().CallGroup("kaiju_manager", "NotifyAreaExited", this);
    }

    public override void _Input(InputEvent @event)
    {
        if (IsActive && @event.IsActionPressed("interact"))
        {
            GetTree().CallGroup("kaiju_manager", "NotifyInteraction", this);
        }
    }

    public void ShowHighlight()
    {
        if (_highlight != null)
        {
            _highlight.Visible = true;
        }
    }

    public void HideHighlight()
    {
        if (_highlight != null)
        {
            _highlight.Visible = false;
        }
    }
}
