using Godot;

namespace KaijuBreakdown;

public partial class Main : Node2D
{
    private const string IntroScene = "res://narrative/IntroDialogue.tscn";

    private Sprite2D _pressAny = null!;

    private Tween? _floatTween;
    private Tween? _fadeTween;

    public override void _Ready()
    {
        _pressAny = GetNode<Sprite2D>("PressAny");
        StartAnimations();
    }

    private void StartAnimations()
    {
        Vector2 startPos = _pressAny.Position;

        _floatTween = CreateTween();
        _floatTween.SetLoops();
        _floatTween.SetParallel(true);
        _floatTween.TweenProperty(_pressAny, "position:y", startPos.Y - 10, 1.5)
            .SetEase(Tween.EaseType.InOut).SetTrans(Tween.TransitionType.Sine);
        _floatTween.TweenProperty(_pressAny, "position:x", startPos.X + 5, 2.0)
            .SetEase(Tween.EaseType.InOut).SetTrans(Tween.TransitionType.Sine);

        var modulate = _pressAny.Modulate;
        modulate.A = 1.0f;
        _pressAny.Modulate = modulate;

        _fadeTween = CreateTween();
        _fadeTween.SetLoops();
        _fadeTween.TweenProperty(_pressAny, "modulate:a", 0.3, 1.0)
            .SetEase(Tween.EaseType.InOut).SetTrans(Tween.TransitionType.Sine);
        _fadeTween.TweenProperty(_pressAny, "modulate:a", 1.0, 1.0)
            .SetEase(Tween.EaseType.InOut).SetTrans(Tween.TransitionType.Sine);
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event is InputEventKey { Pressed: true })
        {
            GetTree().ChangeSceneToFile(IntroScene);
        }
    }
}
