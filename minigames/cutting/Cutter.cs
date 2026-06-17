using Godot;
using System.Collections.Generic;
using KaijuBreakdown.Core;

namespace KaijuBreakdown.Minigames.Cutting;

public partial class Cutter : Node2D
{
    [Signal]
    public delegate void SliceImpactEventHandler();

    public bool IsCutting { get; private set; }

    private Vector2 _cutStartPosition;
    private float _cutDirection;
    private Vector2 _currentPosition;

    private Line2D _cutPathLine = null!;
    private Sprite2D _cutterBlade = null!;

    private float _nextSliceTick;
    private float _bladeJitterTime;

    private readonly List<Polygon2D> _targets = new();

    private const string ParticlesScenePath = "res://minigames/cutting/cpu_particles_2d.tscn";

    private static readonly Texture2D BladeTexture =
        GD.Load<Texture2D>("res://assets/cutter-knife-base.png");

    private PackedScene? _particles;

    public override void _Ready()
    {
        _cutPathLine = new Line2D
        {
            Width = CuttingConfig.CutPathWidth,
            DefaultColor = CuttingConfig.CutPathColor,
            Visible = false,
            ZIndex = CuttingConfig.InterfaceZIndex,
        };
        AddChild(_cutPathLine);

        _cutterBlade = new Sprite2D
        {
            Texture = BladeTexture,
            Visible = false,
            ZIndex = CuttingConfig.InterfaceZIndex,
        };
        AddChild(_cutterBlade);

        _particles = GD.Load<PackedScene>(ParticlesScenePath);
        if (_particles == null)
        {
            GD.PushError($"Cutter: failed to load slice-particle scene '{ParticlesScenePath}'; slices will spawn no particles.");
        }
    }

    public void StartCutting(Vector2 startPos, float angle)
    {
        _cutStartPosition = startPos;
        _cutDirection = angle;
        _currentPosition = startPos;

        IsCutting = true;
        _nextSliceTick = CuttingConfig.SliceInterval;

        _cutPathLine.ClearPoints();
        _cutPathLine.AddPoint(_currentPosition);

        UpdateBladeVisual();
        _cutterBlade.Visible = true;

        FindTargets();
    }

    public void StopCutting()
    {
        if (IsCutting)
        {
            PerformSlice();

            float pivotOffset = CuttingConfig.BladeWidth / 2.0f;
            var forwardDirection = new Vector2(Mathf.Cos(_cutDirection), Mathf.Sin(_cutDirection));
            _currentPosition += forwardDirection * (CuttingConfig.BladeLength - pivotOffset);
        }

        IsCutting = false;
        _cutterBlade.Visible = false;
    }

    public void UpdateCutting(double delta)
    {
        if (!IsCutting)
        {
            return;
        }

        float fdelta = (float)delta;
        _bladeJitterTime += fdelta;

        var directionVector = new Vector2(Mathf.Cos(_cutDirection), Mathf.Sin(_cutDirection));
        _currentPosition += directionVector * CuttingConfig.CutterSpeed * fdelta;

        Vector2[] points = _cutPathLine.Points;
        if (points.Length == 0 || _currentPosition.DistanceTo(points[^1]) > 5.0f)
        {
            _cutPathLine.AddPoint(_currentPosition);
        }

        UpdateBladeVisual();

        _nextSliceTick -= fdelta;
        if (_nextSliceTick <= 0)
        {
            PerformSlice();
            _nextSliceTick = CuttingConfig.SliceInterval;
        }
    }

    private void UpdateBladeVisual()
    {
        float pivotOffset = CuttingConfig.BladeWidth / 2.0f;
        Vector2 jitter = Vector2.Zero;
        if (IsCutting)
        {
            jitter = new Vector2(
                Mathf.Sin(_bladeJitterTime * 53.0f),
                Mathf.Cos(_bladeJitterTime * 47.0f)) * CuttingConfig.CuttingJitterPx;
        }
        _cutterBlade.Position = _currentPosition
            + (new Vector2(Mathf.Cos(_cutDirection), Mathf.Sin(_cutDirection))
                * ((CuttingConfig.BladeLength / 2.0f) - pivotOffset))
            + jitter;
        _cutterBlade.Rotation = _cutDirection + Mathf.Pi;

        if (_cutterBlade.Texture != null)
        {
            Vector2 textureSize = _cutterBlade.Texture.GetSize();
            _cutterBlade.Scale = new Vector2(
                CuttingConfig.BladeLength / textureSize.X,
                CuttingConfig.BladeWidth / textureSize.Y);
        }
    }

    private void FindTargets()
    {
        _targets.Clear();

        Node parent = GetParent();
        if (parent != null)
        {
            foreach (Node child in parent.GetChildren())
            {
                if (child is Polygon2D polygonChild && child != this)
                {
                    _targets.Add(polygonChild);
                }
                else if (child is RigidBody2D)
                {
                    foreach (Node rigidbodyChild in child.GetChildren())
                    {
                        if (rigidbodyChild is Polygon2D rbPolygon)
                        {
                            _targets.Add(rbPolygon);
                        }
                    }
                }
            }
        }
    }

    private void PerformSlice()
    {
        Vector2[] pathPoints = _cutPathLine.Points;
        if (pathPoints.Length < 2)
        {
            return;
        }

        Vector2[] simplifiedPoints = PolygonSlicePlugin.RamerDouglasPeucker(pathPoints, 10);
        Vector2[] extendedPoints = ExtendPathEnds(simplifiedPoints);
        Polygon2D polyline = PolygonSlicePlugin.CreatePolyline(extendedPoints, CuttingConfig.BladeWidth);

        List<Polygon2D> matchedTargets = PolygonSlicePlugin.FindPolygonMatches(_targets, polyline);
        if (matchedTargets.Count == 0)
        {
            return;
        }

        if (GetParent() is not Node2D parentNode)
        {
            return;
        }

        if (!HarvestFragmentSpawner.SpawnSlicedFragments(parentNode, matchedTargets, polyline, _targets))
        {
            return;
        }

        SpawnSliceParticles();
        EmitSignal(SignalName.SliceImpact);
    }

    public Vector2 GetCurrentPosition() => _currentPosition;

    public float GetCurrentDirection() => _cutDirection;

    public Vector2 GetBladeCenterInParentSpace()
    {
        float pivotOffset = CuttingConfig.BladeWidth / 2.0f;
        return Position + _currentPosition
            + (new Vector2(Mathf.Cos(_cutDirection), Mathf.Sin(_cutDirection))
                * ((CuttingConfig.BladeLength / 2.0f) - pivotOffset));
    }

    // Returns the blade's four corners in global space, used to check footprint
    public Vector2[] GetBladeFootprintGlobal()
    {
        float pivotOffset = CuttingConfig.BladeWidth / 2.0f;
        var forward = new Vector2(Mathf.Cos(_cutDirection), Mathf.Sin(_cutDirection));
        var perpendicular = new Vector2(-forward.Y, forward.X);
        Vector2 center = _currentPosition
            + (forward * ((CuttingConfig.BladeLength / 2.0f) - pivotOffset));

        float halfLength = CuttingConfig.BladeLength / 2.0f;
        float halfWidth = CuttingConfig.BladeWidth / 2.0f;
        var corners = new[]
        {
            center + (forward * halfLength) + (perpendicular * halfWidth),
            center + (forward * halfLength) - (perpendicular * halfWidth),
            center - (forward * halfLength) - (perpendicular * halfWidth),
            center - (forward * halfLength) + (perpendicular * halfWidth),
        };
        for (int i = 0; i < corners.Length; i++)
        {
            corners[i] = ToGlobal(corners[i]);
        }
        return corners;
    }

    private void SpawnSliceParticles()
    {
        Node parentNode = GetParent();
        if (parentNode == null)
        {
            return;
        }
        if (_particles == null)
        {
            return;
        }
        var p = _particles.Instantiate<CpuParticles2D>();
        parentNode.AddChild(p);
        p.ZIndex = CuttingConfig.InterfaceZIndex + 1;
        p.Position = GetBladeCenterInParentSpace();
        p.Emitting = true;
        GetTree().CreateTimer(2.0).Timeout += () => p.QueueFree();
    }

    private static Vector2[] ExtendPathEnds(Vector2[] points)
    {
        if (points.Length < 2)
        {
            return points;
        }

        var extendedPoints = new List<Vector2>(points);

        Vector2 endDirection = (points[^1] - points[^2]).Normalized();
        Vector2 extendedEnd = points[^1] + (endDirection * CuttingConfig.BladeExtension);
        extendedPoints.Add(extendedEnd);

        return extendedPoints.ToArray();
    }
}
