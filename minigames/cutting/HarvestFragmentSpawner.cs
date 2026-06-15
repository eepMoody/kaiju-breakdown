using Godot;
using System.Collections.Generic;
using KaijuBreakdown.Core;

namespace KaijuBreakdown.Minigames.Cutting;

public static class HarvestFragmentSpawner
{
    public static Vector2[] InterpolateUvsForSlicedPolygon(
        Vector2[] slicedVertices,
        Vector2[] originalWorldVertices,
        Vector2[] originalUvs)
    {
        
        var uvs = new Vector2[slicedVertices.Length];
        if (TryFitAffine(originalWorldVertices, originalUvs,
                out float au, out float bu, out float cu, out float av, out float bv, out float cv))
        {
            for (int i = 0; i < slicedVertices.Length; i++)
            {
                Vector2 p = slicedVertices[i];
                uvs[i] = new Vector2((au * p.X) + (bu * p.Y) + cu, (av * p.X) + (bv * p.Y) + cv);
            }
            return uvs;
        }

        // Degenerate (collinear) source: copy the nearest vertex's uv.
        for (int i = 0; i < slicedVertices.Length; i++)
        {
            int nearest = 0;
            float best = float.MaxValue;
            for (int j = 0; j < originalWorldVertices.Length; j++)
            {
                float d = slicedVertices[i].DistanceSquaredTo(originalWorldVertices[j]);
                if (d < best)
                {
                    best = d;
                    nearest = j;
                }
            }
            uvs[i] = originalUvs[nearest];
        }
        return uvs;
    }

    // Least-squares fit of uv = (a*x + b*y + c) per channel over the source vertices.
    private static bool TryFitAffine(Vector2[] pos, Vector2[] uv,
        out float au, out float bu, out float cu, out float av, out float bv, out float cv)
    {
        au = bu = cu = av = bv = cv = 0f;
        if (pos.Length < 3)
        {
            return false;
        }

        double sxx = 0, sxy = 0, sx = 0, syy = 0, sy = 0, n = pos.Length;
        double sxu = 0, syu = 0, su = 0, sxv = 0, syv = 0, sv = 0;
        for (int i = 0; i < pos.Length; i++)
        {
            double x = pos[i].X, y = pos[i].Y, u = uv[i].X, v = uv[i].Y;
            sxx += x * x; sxy += x * y; sx += x; syy += y * y; sy += y;
            sxu += x * u; syu += y * u; su += u; sxv += x * v; syv += y * v; sv += v;
        }

        if (!Solve3(sxx, sxy, sx, sxy, syy, sy, sx, sy, n, sxu, syu, su, out double a1, out double b1, out double c1) ||
            !Solve3(sxx, sxy, sx, sxy, syy, sy, sx, sy, n, sxv, syv, sv, out double a2, out double b2, out double c2))
        {
            return false;
        }

        au = (float)a1; bu = (float)b1; cu = (float)c1;
        av = (float)a2; bv = (float)b2; cv = (float)c2;
        return true;
    }

    private static bool Solve3(
        double a11, double a12, double a13, double a21, double a22, double a23,
        double a31, double a32, double a33, double r1, double r2, double r3,
        out double x, out double y, out double z)
    {
        double det = (a11 * ((a22 * a33) - (a23 * a32)))
            - (a12 * ((a21 * a33) - (a23 * a31)))
            + (a13 * ((a21 * a32) - (a22 * a31)));
        x = y = z = 0;
        if (Mathf.Abs((float)det) < 1e-6f)
        {
            return false;
        }
        x = ((r1 * ((a22 * a33) - (a23 * a32))) - (a12 * ((r2 * a33) - (a23 * r3))) + (a13 * ((r2 * a32) - (a22 * r3)))) / det;
        y = ((a11 * ((r2 * a33) - (a23 * r3))) - (r1 * ((a21 * a33) - (a23 * a31))) + (a13 * ((a21 * r3) - (r2 * a31)))) / det;
        z = ((a11 * ((a22 * r3) - (r2 * a32))) - (a12 * ((a21 * r3) - (r2 * a31))) + (r1 * ((a21 * a32) - (a22 * a31)))) / det;
        return true;
    }

    public static bool SpawnSlicedFragments(
        Node2D parent,
        List<Polygon2D> matchedTargets,
        Polygon2D polyline,
        List<Polygon2D> targets)
    {
        bool spawnedAny = false;

        foreach (Polygon2D matchedTarget in matchedTargets)
        {
            Vector2[] targetWorld = TransformPolygon(matchedTarget.GlobalTransform, matchedTarget.Polygon);
            Vector2[] polylineWorld = TransformPolygon(polyline.GlobalTransform, polyline.Polygon);

            Godot.Collections.Array<Vector2[]> slicedPolygons =
                Geometry2D.ClipPolygons(targetWorld, polylineWorld);

            Vector2[] originalWorldVerts = targetWorld;
            Vector2[] originalUvs = matchedTarget.UV;

            foreach (Vector2[] worldPolygon in slicedPolygons)
            {
                spawnedAny = true;

                Vector2 centroid = Vector2.Zero;
                foreach (Vector2 vertex in worldPolygon)
                {
                    centroid += vertex;
                }
                centroid /= worldPolygon.Length;

                var rigidbody = new RigidBody2D
                {
                    Position = parent.ToLocal(centroid),
                };

                var localPolygon = new Vector2[worldPolygon.Length];
                for (int i = 0; i < worldPolygon.Length; i++)
                {
                    localPolygon[i] = parent.ToLocal(worldPolygon[i]) - rigidbody.Position;
                }

                var polygon = new Polygon2D
                {
                    Polygon = localPolygon,
                };

                float surfaceArea = PolygonSlicePlugin.GetPolygonArea(localPolygon) / 1000.0f;
                bool isHarvestable = surfaceArea < CuttingConfig.HarvestableAreaThreshold;

                if (isHarvestable)
                {
                    var collider = new CollisionPolygon2D
                    {
                        Polygon = localPolygon,
                    };
                    polygon.AddChild(collider);
                    rigidbody.Freeze = false;
                    polygon.Modulate = CuttingConfig.HarvestableHighlight;
                }
                else
                {
                    rigidbody.Freeze = true;
                }

                if (matchedTarget.Texture != null && originalUvs.Length >= 3)
                {
                    polygon.UV = InterpolateUvsForSlicedPolygon(
                        worldPolygon,
                        originalWorldVerts,
                        originalUvs);
                }

                polygon.Texture = matchedTarget.Texture;
                polygon.Color = matchedTarget.Color;

                rigidbody.AddChild(polygon);
                parent.AddChild(rigidbody);
                targets.Add(polygon);
            }

            Node parentRigidbody = matchedTarget.GetParent();
            if (parentRigidbody is RigidBody2D)
            {
                parentRigidbody.QueueFree();
            }
            else
            {
                matchedTarget.QueueFree();
            }
            targets.Remove(matchedTarget);
        }

        return spawnedAny;
    }

    private static Vector2[] TransformPolygon(Transform2D transform, Vector2[] polygon)
    {
        var result = new Vector2[polygon.Length];
        for (int i = 0; i < polygon.Length; i++)
        {
            result[i] = transform * polygon[i];
        }
        return result;
    }
}
