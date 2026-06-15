using Godot;

namespace KaijuBreakdown.Minigames.Cutting;

public partial class ModalContainer : CanvasLayer
{
    [Signal]
    public delegate void ModalClosedEventHandler();

    private Control _modalControl = null!;
    private SubViewport _viewport = null!;

    private Node? _minigameInstance;

    public override void _Ready()
    {
        _modalControl = GetNode<Control>("ModalControl");
        _viewport = GetNode<SubViewport>("ModalControl/ContentContainer/ViewportContainer/SubViewport");
        _modalControl.Visible = false;
    }

    public void ShowModal(PackedScene minigameScene, Overworld.InteractableArea? interactArea = null)
    {
        if (_minigameInstance != null)
        {
            _minigameInstance.QueueFree();
        }

        _minigameInstance = minigameScene.Instantiate();

        if (interactArea != null && _minigameInstance.HasMethod("ConfigureFromArea"))
        {
            _minigameInstance.Call("ConfigureFromArea", interactArea);
        }

        _viewport.AddChild(_minigameInstance);

        if (_minigameInstance.HasSignal("MinigameCompleted"))
        {
            _minigameInstance.Connect("MinigameCompleted", Callable.From(OnMinigameCompleted));
        }

        _modalControl.Visible = true;
    }

    public void HideModal()
    {
        if (_minigameInstance != null)
        {
            _minigameInstance.QueueFree();
            _minigameInstance = null;
        }

        _modalControl.Visible = false;
        EmitSignal(SignalName.ModalClosed);
    }

    private void OnMinigameCompleted()
    {
        HideModal();
    }

    public override void _Input(InputEvent @event)
    {
        if (Visible && @event.IsActionPressed("ui_cancel"))
        {
            HideModal();
            GetViewport().SetInputAsHandled();
        }
    }
}
