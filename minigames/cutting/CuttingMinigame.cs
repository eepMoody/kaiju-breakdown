using Godot;
using System.Collections.Generic;
using KaijuBreakdown.Overworld;

namespace KaijuBreakdown.Minigames.Cutting;

public partial class CuttingMinigame : Node2D
{
    [Signal]
    public delegate void MinigameCompletedEventHandler();

    private enum State
    {
        Idle,
        Dragging,
        Oscillating,
        Cutting,
        Paused,
    }

    private State _currentState = State.Idle;

    private Vector2 _clickStartPosition;
    private Vector2 _dragCurrentPosition;
    private float _baseDirectionAngle;
    private float _lockedCutAngle;

    private Line2D _directionPreviewLine = null!;
    private ArcDisplay _arcDisplay = null!;
    private Cutter _cutter = null!;

    private Polygon2D _partPolygon = null!;

    private string _partSvgPath = "";
    private Texture2D? _partTexture;
    private float _sliceShake;

    private Camera2D _camera = null!;

    private static readonly Texture2D CursorAvailable =
        GD.Load<Texture2D>("res://assets/cursor-dot.png");
    private static readonly Texture2D CursorBlocked =
        GD.Load<Texture2D>("res://assets/cursor-x.png");
    private static readonly Texture2D CursorTrigger =
        GD.Load<Texture2D>("res://assets/cursor-trigger.png");

    private SoftwareCursor _cursor = null!;

    private HarvestController _harvest = null!;

    // Invoked by name from ModalContainer via Call("ConfigureFromArea", ...).
    public void ConfigureFromArea(InteractableArea area)
    {
        _partSvgPath = area.PartSvgPath;
        _partTexture = area.PartTexture;
    }

    public override void _Ready()
    {
        _camera = GetNode<Camera2D>("Camera2D");

        _partPolygon = CreatePartPolygon();
        _partPolygon.ZIndex = CuttingConfig.KaijuZIndex;
        AddChild(_partPolygon);

        _directionPreviewLine = new Line2D
        {
            Width = CuttingConfig.DirectionLineWidth,
            DefaultColor = CuttingConfig.DirectionLineColor,
            Visible = false,
            ZIndex = CuttingConfig.InterfaceZIndex,
        };
        AddChild(_directionPreviewLine);

        _arcDisplay = new ArcDisplay();
        AddChild(_arcDisplay);

        _cutter = new Cutter();
        AddChild(_cutter);
        _cutter.SliceImpact += OnCutterSliceImpact;

        _harvest = new HarvestController();
        AddChild(_harvest);

        _cursor = new SoftwareCursor { Texture = CursorAvailable };
        // scale cursor to match camera zoom
        _cursor.Scale = Vector2.One / _camera.Zoom;
        AddChild(_cursor);
    }

    private Polygon2D CreatePartPolygon()
    {
        if (_partSvgPath != "" && _partTexture != null)
        {
            Polygon2D loaded = SvgLoader.LoadPolygon(_partSvgPath, _partTexture);
            SvgLoader.CenterPolygon(loaded);
            return loaded;
        }

        return new Polygon2D
        {
            Polygon = new[]
            {
                new Vector2(-200, -200), new Vector2(200, -200),
                new Vector2(200, 200), new Vector2(-200, 200),
            },
            Color = new Color(0.6f, 0.3f, 0.3f),
        };
    }

    public override void _Process(double delta)
    {
        float fdelta = (float)delta;
        _sliceShake = Mathf.MoveToward(_sliceShake, 0.0f, fdelta * CuttingConfig.SliceShakeDecay);
        if (_camera != null)
        {
            if (_sliceShake > 0.01f)
            {
                _camera.Offset = new Vector2(
                    (float)GD.RandRange(-1.0, 1.0),
                    (float)GD.RandRange(-1.0, 1.0)) * _sliceShake;
            }
            else
            {
                _camera.Offset = Vector2.Zero;
            }
        }

        UpdateHoverCursor();

        if (_currentState == State.Dragging)
        {
            _dragCurrentPosition = GetGlobalMousePosition();
            Vector2 directionVector = _dragCurrentPosition - _clickStartPosition;
            float previewLength = Mathf.Min(directionVector.Length(), 150);
            Vector2 previewEnd = _clickStartPosition + (directionVector.Normalized() * previewLength);
            _directionPreviewLine.ClearPoints();
            _directionPreviewLine.AddPoint(_clickStartPosition);
            _directionPreviewLine.AddPoint(previewEnd);
        }
        else if (_currentState == State.Cutting)
        {
            _cutter.UpdateCutting(delta);
        }
    }

    public override void _Input(InputEvent @event)
    {
        if (@event is InputEventMouseButton mouseEvent)
        {
            if (mouseEvent.ButtonIndex == MouseButton.Left)
            {
                if (mouseEvent.Pressed)
                {
                    OnLeftClickPressed();
                }
                else
                {
                    OnLeftClickReleased();
                }
            }
            else if (mouseEvent.ButtonIndex == MouseButton.Right)
            {
                if (mouseEvent.Pressed && _currentState == State.Oscillating)
                {
                    ExitOscillation();
                    GetViewport().SetInputAsHandled();
                }
            }
        }
        else if (@event.IsActionPressed("ui_cancel"))
        {
            if (_currentState == State.Oscillating)
            {
                ExitOscillation();
                GetViewport().SetInputAsHandled();
            }
            else if (_currentState == State.Idle)
            {
                EmitSignal(SignalName.MinigameCompleted);
                GetViewport().SetInputAsHandled();
            }
        }
    }

    private void OnLeftClickPressed()
    {
        switch (_currentState)
        {
            case State.Idle:
                {
                    Vector2 start = GetGlobalMousePosition();
                    if (TryHarvestAt(start))
                    {
                        break;
                    }
                    if (IsPointInsideCuttable(start))
                    {
                        break;
                    }
                    _clickStartPosition = start;
                    _dragCurrentPosition = _clickStartPosition;
                    _directionPreviewLine.Visible = true;
                    _currentState = State.Dragging;
                    break;
                }

            case State.Oscillating:
                _lockedCutAngle = _arcDisplay.GetCurrentAngle();
                _arcDisplay.StopOscillation();
                _cutter.StartCutting(_clickStartPosition, _lockedCutAngle);
                _currentState = State.Cutting;
                break;
        }
    }

    private void OnLeftClickReleased()
    {
        switch (_currentState)
        {
            case State.Dragging:
                {
                    Vector2 directionVector = _dragCurrentPosition - _clickStartPosition;
                    if (directionVector.Length() > 10)
                    {
                        _baseDirectionAngle = directionVector.Angle();
                        _directionPreviewLine.Visible = false;
                        _arcDisplay.StartOscillation(_clickStartPosition, _baseDirectionAngle);
                        _currentState = State.Oscillating;
                    }
                    else
                    {
                        _directionPreviewLine.Visible = false;
                        _currentState = State.Idle;
                    }
                    break;
                }

            case State.Cutting:
                {
                    Vector2 bladeCenter = _cutter.GetBladeCenterInParentSpace();
                    _cutter.StopCutting();
                    if (IsBladeOutsideCuttable())
                    {
                        _currentState = State.Idle;
                        break;
                    }
                    _clickStartPosition = _cutter.GetCurrentPosition();
                    _baseDirectionAngle = _cutter.GetCurrentDirection();
                    _arcDisplay.StartOscillation(
                        _clickStartPosition,
                        _baseDirectionAngle,
                        bladeCenter,
                        CuttingConfig.CursorTransitionDuration);
                    _currentState = State.Oscillating;
                    break;
                }
        }
    }

    private void ExitOscillation()
    {
        _arcDisplay.StopOscillation();
        _currentState = State.Idle;
    }

    private void UpdateHoverCursor()
    {
        _cursor.Texture = _currentState switch
        {
            State.Oscillating or State.Cutting or State.Paused => CursorTrigger,
            State.Idle when IsPointInsideCuttable(GetGlobalMousePosition()) => CursorBlocked,
            _ => CursorAvailable,
        };
    }

    private bool TryHarvestAt(Vector2 globalPoint)
    {
        foreach (Polygon2D polygon in GetCuttablePolygons())
        {
            if (_harvest.IsHarvestable(polygon) &&
                Geometry2D.IsPointInPolygon(globalPoint, ToGlobalPolygon(polygon)))
            {
                _harvest.Harvest(polygon);
                return true;
            }
        }
        return false;
    }

    private bool IsPointInsideCuttable(Vector2 globalPoint)
    {
        foreach (Polygon2D polygon in GetCuttablePolygons())
        {
            if (_harvest.IsHarvestable(polygon))
            {
                continue;
            }
            if (Geometry2D.IsPointInPolygon(globalPoint, ToGlobalPolygon(polygon)))
            {
                return true;
            }
        }
        return false;
    }

    private bool IsBladeOutsideCuttable()
    {
        Vector2[] blade = _cutter.GetBladeFootprintGlobal();
        foreach (Polygon2D polygon in GetCuttablePolygons())
        {
            if (Geometry2D.IntersectPolygons(blade, ToGlobalPolygon(polygon)).Count > 0)
            {
                return false;
            }
        }
        return true;
    }

    private IEnumerable<Polygon2D> GetCuttablePolygons()
    {
        foreach (Node child in GetChildren())
        {
            if (child is Polygon2D polygon)
            {
                yield return polygon;
            }
            else if (child is RigidBody2D rigidbody)
            {
                foreach (Node rigidbodyChild in rigidbody.GetChildren())
                {
                    if (rigidbodyChild is Polygon2D rbPolygon)
                    {
                        yield return rbPolygon;
                    }
                }
            }
        }
    }

    private static Vector2[] ToGlobalPolygon(Polygon2D polygon)
    {
        Vector2[] points = polygon.Polygon;
        Transform2D transform = polygon.GlobalTransform;
        var result = new Vector2[points.Length];
        for (int i = 0; i < points.Length; i++)
        {
            result[i] = transform * points[i];
        }
        return result;
    }

    private void OnCutterSliceImpact()
    {
        _sliceShake = CuttingConfig.SliceShakeStrength;
        Input.VibrateHandheld(40);
        foreach (int joy in Input.GetConnectedJoypads())
        {
            Input.StartJoyVibration(joy, 0.28f, 0.55f, 0.11f);
        }
    }
}
