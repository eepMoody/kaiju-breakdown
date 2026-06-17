using Godot;

namespace KaijuBreakdown.Overworld;

public partial class Player : CharacterBody2D
{
    [Export] public float Speed { get; set; } = 400.0f;

    private AnimatedSprite2D _animatedSprite = null!;

    public override void _Ready()
    {
        _animatedSprite = GetNode<AnimatedSprite2D>("AnimatedSprite2D");
    }

    public override void _PhysicsProcess(double delta)
    {
        var direction = new Vector2(
            Input.GetAxis("move_left", "move_right"),
            Input.GetAxis("move_up", "move_down"));

        if (direction.Length() > 0)
        {
            direction = direction.Normalized();
        }

        Velocity = direction * Speed;

        if (direction.Length() > 0)
        {
            if (_animatedSprite.SpriteFrames != null && _animatedSprite.SpriteFrames.HasAnimation("walk"))
            {
                if (_animatedSprite.Animation != "walk")
                {
                    _animatedSprite.Play("walk");
                }
            }

            if (direction.X != 0)
            {
                _animatedSprite.FlipH = direction.X < 0;
            }
        }
        else
        {
            if (_animatedSprite.SpriteFrames != null && _animatedSprite.SpriteFrames.HasAnimation("idle"))
            {
                if (_animatedSprite.Animation != "idle")
                {
                    _animatedSprite.Play("idle");
                }
            }
            else
            {
                _animatedSprite.Stop();
            }
        }

        MoveAndSlide();
    }
}
