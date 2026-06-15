using Godot;

namespace KaijuBreakdown.Overworld;

public partial class DeadKaiju : Node2D
{
    private static readonly PackedScene ModalScene =
        GD.Load<PackedScene>("res://minigames/cutting/modal_container.tscn");

    private static readonly PackedScene CuttingMinigameScene =
        GD.Load<PackedScene>("res://minigames/cutting/cutting_minigame.tscn");

    private InteractableArea? _currentArea;
    private CanvasLayer? _modalContainer;

    public override void _Ready()
    {
        AddToGroup("kaiju_manager");
    }

    public void NotifyAreaEntered(InteractableArea area)
    {
        if (_currentArea != null && _currentArea != area)
        {
            _currentArea.HideHighlight();
        }

        _currentArea = area;
        _currentArea.ShowHighlight();
    }

    public void NotifyAreaExited(InteractableArea area)
    {
        if (_currentArea == area)
        {
            _currentArea.HideHighlight();
            _currentArea = null;
        }
    }

    public void NotifyInteraction(InteractableArea area)
    {
        if (_modalContainer == null)
        {
            _modalContainer = ModalScene.Instantiate<CanvasLayer>();
            _modalContainer.Connect("ModalClosed", Callable.From(OnModalClosed));
            GetTree().Root.AddChild(_modalContainer);
        }

        _modalContainer.Call("ShowModal", CuttingMinigameScene, area);
    }

    private void OnModalClosed()
    {
    }
}
