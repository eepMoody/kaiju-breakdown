using System.Collections.Generic;
using Godot;

namespace KaijuBreakdown.Core;

public static class PolygonSlicePlugin
{
    private static GodotObject? _plugin;

    private static GodotObject Singleton =>
        _plugin ??= ClassDB.Instantiate("godot_polygon_slice_plugin").AsGodotObject();

    public static Vector2[] RamerDouglasPeucker(Vector2[] points, int epsilon) =>
        Singleton.Call("ramer_douglas_peucker", points, epsilon).AsVector2Array();

    public static float GetPolygonArea(Vector2[] polygon) =>
        Singleton.Call("get_polygon_area", polygon).AsSingle();

    public static Polygon2D CreatePolyline(Vector2[] points, int width) =>
        Singleton.Call("create_polyline", points, width).As<Polygon2D>();

    public static List<Polygon2D> FindPolygonMatches(List<Polygon2D> targets, Polygon2D polyline)
    {
        var godotTargets = new Godot.Collections.Array<Polygon2D>();
        foreach (Polygon2D t in targets)
        {
            godotTargets.Add(t);
        }

        var matches = Singleton.Call("find_polygon_matches", godotTargets, polyline)
            .As<Godot.Collections.Array<Polygon2D>>();

        var result = new List<Polygon2D>();
        foreach (Polygon2D m in matches)
        {
            result.Add(m);
        }
        return result;
    }
}
