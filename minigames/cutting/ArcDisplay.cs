using Godot;

namespace KaijuBreakdown.Minigames.Cutting;

public partial class ArcDisplay : Node2D
{
    public bool IsOscillating { get; private set; }

    private float _oscillationTime;
    private float _baseAngle;
    private Vector2 _originPosition = Vector2.Zero;

    private float _transitionElapsed;
    private float _transitionDuration;
    private Vector2 _transitionFrom = Vector2.Zero;
    private Vector2 _transitionTo = Vector2.Zero;
    private bool _transitionActive;

    private Line2D _arcLine = null!;
    private Sprite2D _bladePreview = null!;

    private static readonly Texture2D BladeTexture =
        GD.Load<Texture2D>("res://assets/cutter-knife-base.png");

    public override void _Ready()
    {
        _arcLine = new Line2D
        {
            Width = CuttingConfig.ArcLineWidth,
            DefaultColor = CuttingConfig.ArcLineColor,
            Visible = false,
            ZIndex = CuttingConfig.InterfaceZIndex,
        };
        AddChild(_arcLine);

        _bladePreview = new Sprite2D
        {
            Texture = BladeTexture,
            Visible = false,
            ZIndex = CuttingConfig.InterfaceZIndex,
        };
        AddChild(_bladePreview);
    }

    public void StartOscillation(
        Vector2 startPos,
        float directionAngle,
        Vector2 transitionFrom = default,
        float transitionDuration = 0.0f)
    {
        _baseAngle = directionAngle;
        IsOscillating = true;
        _oscillationTime = 0.0f;

        if (transitionDuration > 0.0f)
        {
            _transitionActive = true;
            _transitionElapsed = 0.0f;
            _transitionDuration = transitionDuration;
            _transitionFrom = transitionFrom;
            _transitionTo = startPos;
            _originPosition = transitionFrom;
        }
        else
        {
            _transitionActive = false;
            _originPosition = startPos;
        }

        UpdateArcVisual();

        _arcLine.Visible = true;
        _bladePreview.Visible = true;
    }

    public void StopOscillation()
    {
        IsOscillating = false;
        _transitionActive = false;
        _arcLine.Visible = false;
        _bladePreview.Visible = false;
    }

    public float GetCurrentAngle()
    {
        float swing = Mathf.Sin(_oscillationTime * CuttingConfig.OscillationFrequency)
            * Mathf.DegToRad(CuttingConfig.ArcWidthDegrees / 2);
        return _baseAngle + swing;
    }

    public override void _Process(double delta)
    {
        if (!IsOscillating)
        {
            return;
        }

        float fdelta = (float)delta;

        if (_transitionActive)
        {
            _transitionElapsed += fdelta;
            float tLinear = Mathf.Clamp(_transitionElapsed / _transitionDuration, 0.0f, 1.0f);
            float tEased = Mathf.Ease(tLinear, -2.0f);
            _originPosition = _transitionFrom.Lerp(_transitionTo, tEased);
            if (_transitionElapsed >= _transitionDuration)
            {
                _transitionActive = false;
            }
        }
        else
        {
            _oscillationTime += fdelta;
        }

        UpdateArcVisual();

        float currentAngle = GetCurrentAngle();
        float pivotOffset = CuttingConfig.BladeWidth / 2.0f;
        _bladePreview.Position = _originPosition
            + (new Vector2(Mathf.Cos(currentAngle), Mathf.Sin(currentAngle))
                * ((CuttingConfig.BladeLength / 2.0f) - pivotOffset));
        _bladePreview.Rotation = currentAngle + Mathf.Pi;

        if (_bladePreview.Texture != null)
        {
            Vector2 textureSize = _bladePreview.Texture.GetSize();
            var baseScale = new Vector2(
                CuttingConfig.BladeLength / textureSize.X,
                CuttingConfig.BladeWidth / textureSize.Y);
            float lift = 1.0f;
            if (_transitionActive)
            {
                float tLift = Mathf.Clamp(_transitionElapsed / _transitionDuration, 0.0f, 1.0f);
                float peak = 1.0f - (Mathf.Abs(tLift - 0.5f) * 2.0f);
                lift = Mathf.Lerp(1.0f, CuttingConfig.CursorTransitionLiftScale, peak);
            }
            _bladePreview.Scale = baseScale * lift;
        }
    }

    private void UpdateArcVisual()
    {
        float leftAngle = _baseAngle - Mathf.DegToRad(CuttingConfig.ArcWidthDegrees / 2);
        float rightAngle = _baseAngle + Mathf.DegToRad(CuttingConfig.ArcWidthDegrees / 2);

        Vector2 leftPoint = _originPosition
            + (new Vector2(Mathf.Cos(leftAngle), Mathf.Sin(leftAngle)) * CuttingConfig.ArcRadius);
        Vector2 rightPoint = _originPosition
            + (new Vector2(Mathf.Cos(rightAngle), Mathf.Sin(rightAngle)) * CuttingConfig.ArcRadius);

        _arcLine.ClearPoints();
        _arcLine.AddPoint(leftPoint);
        _arcLine.AddPoint(_originPosition);
        _arcLine.AddPoint(rightPoint);
    }
}
