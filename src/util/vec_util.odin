package util

import "core:math/linalg"

/*
Detetermine the point at which a line intersects a plane. This assumes that
it happens.

Inputs:
- p_0: a point on the plane
- l_0: a point on the line
- l: the unit vector pointing along the line
- n: the vector normal to the plane

Returns:
- p: the point where the line and plane intersect
*/
plane_line_intersect_point :: proc(p_0, l_0, l, n: [3]f32) -> (p: [3]f32) {
    line_scalar: f32 = linalg.dot(p_0-l_0, n) / linalg.dot(l, n)
    return l_0 + (line_scalar * l)
}
