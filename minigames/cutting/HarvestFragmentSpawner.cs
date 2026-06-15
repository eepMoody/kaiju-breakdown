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
        if (TryBuildPositionToUvTransform(originalWorldVertices, originalUvs, out Transform2D positionToUv))
        {
            for (int i = 0; i < slicedVertices.Length; i++)
            {
                uvs[i] = positionToUv * slicedVertices[i];
            }
            return uvs;
        }

        // No triangle could be built (collinear source); fall back to nearest vertex's uv.
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

    // A flat textured polygon's uv is an affine function of position, so position->uv is
    // a Transform2D defined exactly by any three non-collinear vertices.
    private static bool TryBuildPositionToUvTransform(
        Vector2[] pos, Vector2[] uv, out Transform2D positionToUv)
    {
        positionToUv = Transform2D.Identity;
        if (pos.Length < 3)
        {
            return false;
        }

        // Avoid using sliver triangles that would throw off the uv mapping
        int i0 = 0;
        int i1 = FarthestFrom(pos, i0);
        int i2 = FarthestFromLine(pos, i0, i1);
        if (i1 < 0 || i2 < 0)
        {
            return false;
        }

        // Map the corners of the unit square to the triangle
        var srcTriangle = new Transform2D(pos[i1] - pos[i0], pos[i2] - pos[i0], pos[i0]);
        var uvTriangle = new Transform2D(uv[i1] - uv[i0], uv[i2] - uv[i0], uv[i0]);
        positionToUv = uvTriangle * srcTriangle.AffineInverse();
        return true;
    }

    private static int FarthestFrom(Vector2[] pos, int anchor)
    {
        int best = -1;
        float bestDist = 1e-6f;
        for (int i = 0; i < pos.Length; i++)
        {
            if (i == anchor)
            {
                continue;
            }
            float d = pos[i].DistanceSquaredTo(pos[anchor]);
            if (d > bestDist)
            {
                bestDist = d;
                best = i;
            }
        }
        return best;
    }

    // Find the best triangle that is not collinear with the line a-b
    private static int FarthestFromLine(Vector2[] pos, int a, int b)
    {
        if (a < 0 || b < 0)
        {
            return -1;
        }

        Vector2 edge = pos[b] - pos[a];
        int best = -1;
        float bestArea = 1e-6f;
        for (int i = 0; i < pos.Length; i++)
        {
            if (i == a || i == b)
            {
                continue;
            }
            float area = Mathf.Abs(edge.Cross(pos[i] - pos[a]));
            if (area > bestArea)
            {
                bestArea = area;
                best = i;
            }
        }
        return best;
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
