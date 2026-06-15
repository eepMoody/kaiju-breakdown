using Godot;
using System.Collections.Generic;
using KaijuBreakdown.Core;

namespace KaijuBreakdown;

[GlobalClass]
public partial class SvgLoader : Node
{
    [Export] public string SvgPath { get; set; } = "res://polygon_solver/textures/paw-vector.svg";
    [Export] public Texture2D? Texture { get; set; }
    [Export] public Node? TargetParent { get; set; }

    // Node, not the concrete type, to avoid a cross-language dependency on the GDScript PolygonSolver.
    [Export] public Node? PolygonSolverNode { get; set; }

    public override void _Ready()
    {
        if (string.IsNullOrEmpty(SvgPath) || Texture == null)
        {
            return;
        }

        Polygon2D polygon = LoadPolygon(SvgPath, Texture);
        TargetParent?.CallDeferred(Node.MethodName.AddChild, polygon);
        PolygonSolverNode?.CallDeferred("reset_targets");
    }

    public static Polygon2D LoadPolygon(string path, Texture2D partTexture, float scale = 0.25f)
    {
        var polygon = new Polygon2D();

        var parser = new XmlParser();
        parser.Open(path);

        while (parser.Read() != Error.FileEof)
        {
            if (parser.GetNodeType() == XmlParser.NodeType.Element)
            {
                if (parser.HasAttribute("id"))
                {
                    string nodeId = parser.GetNamedAttributeValue("id");

                    if (nodeId == "outline")
                    {
                        string d = parser.GetNamedAttributeValue("d");
                        Vector2[] points = ParsePathIntoPoints(d);

                        points = PolygonSlicePlugin.RamerDouglasPeucker(points, 200);
                        polygon.Polygon = points;
                        polygon.UV = points;
                        polygon.Texture = partTexture;
                        polygon.Color = Colors.White;
                        polygon.Scale = Vector2.One * scale;
                    }
                }
            }
        }

        return polygon;
    }

    public static Vector2[] ParsePathIntoPoints(string pathData)
    {
        var points = new List<Vector2>();
        Vector2 cursor = Vector2.Zero;

        var regex = new RegEx();
        regex.Compile("([a-zA-Z])|(-?[0-9.]+)");

        var tokens = new List<string>();
        foreach (RegExMatch m in regex.SearchAll(pathData))
        {
            string s = m.GetString();
            if (s != "")
            {
                tokens.Add(s);
            }
        }

        int index = 0;
        string cmd = "";
        while (index < tokens.Count)
        {
            string t = tokens[index++].ToUpper();

            if (t.Length == 1 && t[0] >= 'A' && t[0] <= 'Z')
            {
                cmd = t;
                if (cmd == "Z" && points.Count > 0)
                {
                    points.Add(points[0]);
                }
                continue;
            }

            switch (cmd)
            {
                case "M":
                case "L":
                    cursor = new Vector2(
                        t.ToFloat(),
                        tokens[index++].ToFloat());
                    points.Add(cursor);
                    if (cmd == "M")
                    {
                        cmd = "L";
                    }
                    break;
                case "C":
                    var cp1 = new Vector2(t.ToFloat(), tokens[index++].ToFloat());
                    var cp2 = new Vector2(tokens[index++].ToFloat(), tokens[index++].ToFloat());
                    var dest = new Vector2(tokens[index++].ToFloat(), tokens[index++].ToFloat());

                    const int segments = 12;
                    for (int i = 1; i <= segments; i++)
                    {
                        float weight = i / (float)segments;
                        Vector2 curvePt = cursor.BezierInterpolate(cp1, cp2, dest, weight);
                        points.Add(curvePt);
                    }

                    cursor = dest;
                    break;
            }
        }

        return points.ToArray();
    }

    public static void CenterPolygon(Polygon2D polygon)
    {
        if (polygon.Polygon.Length == 0)
        {
            return;
        }

        Vector2 minVertex = polygon.Polygon[0];
        Vector2 maxVertex = polygon.Polygon[0];

        foreach (Vector2 vertex in polygon.Polygon)
        {
            minVertex = minVertex.Min(vertex);
            maxVertex = maxVertex.Max(vertex);
        }

        Vector2 localCenter = (minVertex + maxVertex) / 2.0f;
        polygon.Position = -localCenter * polygon.Scale;
    }
}
