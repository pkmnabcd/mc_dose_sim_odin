package util

import "core:math"
import "core:math/linalg"
import "core:fmt"

interpolatef32 :: proc(x1, x2, y1, y2, x: f32) -> (y: f32) {
    y = (y2-y1) / (x2-x1) * (x-x1) + y1
    return
}

/*
This function will interpolate between the given xcom data and get the best
matching mass cross sections.

Inputs:
- xcom_data: the mass cross section data from xcom that needs to be interpolated
- photon_energy: the energy of the photon in question

Returns:
- out: all of the interpolated mass cross section values. [incoherent scattering, photoelectric, pp nuclear, pp electron]
*/
interpolate_xcom :: proc(xcom_data: [dynamic][5]f32, photon_energy: f32) -> (out: [4]f32) {
    upper_index := 0
    // NOTE: data starts with lower energies and increases from there.
    for row, i in xcom_data {
        if row[0] > photon_energy {
            upper_index = i
            break
        }
    }
    assert(upper_index > 0, "Upper index should always be found and energy should never be below 0.001 MeV")
    lower_index := upper_index - 1
    for i := 0; i < 4; i += 1 {
        data1 := xcom_data[lower_index]
        data2 := xcom_data[upper_index]
        out[i] = interpolatef32(x1=data1[0], x2=data2[0], y1=data1[i+1], y2=data2[i+1], x=photon_energy)
    }
    return
}

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

/*
Rotate the incoming direction vector by the scattering (polar) angle theta
and the azimuthal angle phi to get the new direction in world coords.

Inputs:
- v0: the initial direction vector in world coords
- theta: the scattering/polar angle in radians
- phi: the azimuthal angle in radians

Returns:
- v1: the rotated direction vector in world coords
*/
rotate_direction :: proc(v0: [3]f32, theta, phi: f32) -> (v1: [3]f32) {
    sin_theta: f32 = math.sin(theta)
    sin_phi: f32 = math.sin(phi)
    cos_theta: f32 = math.cos(theta)
    cos_phi: f32 = math.cos(phi)

    // NOTE: local coordinate system has the v0 direction be in the direction of
    // the z-axis. Scattering in this frame is simply applying spherical coords.
    v_local := [3]f32{sin_theta*cos_phi, sin_theta*sin_phi, cos_theta}

    // To assemble the matrix needed for change of basis, we need to come up with
    // two vectors perpendicular to v0 in world coords. We'll use {1,0,0} unless
    // cross({1,0,0}, v0) is close to 0, in which case we'll use {0,1,0} to get
    // the first perpendicular vector.
    ref_vector := [3]f32{1,0,0}
    cross1 := linalg.cross(ref_vector, v0)
    if linalg.length(cross1) < 1e-8 {
        ref_vector = [3]f32{0,1,0}
        cross1 = linalg.cross(ref_vector, v0)
    }
    cross1 = linalg.normalize(cross1)
    cross2 := linalg.normalize(linalg.cross(v0, cross1))

    // The columns of the change of basis matrix are the three vectors that make
    // up the vector's local coordinate system in world coordinates.
    change_of_basis := matrix[3,3]f32{
        cross1.x, cross2.x, v0.x,
        cross1.y, cross2.y, v0.y,
        cross1.z, cross2.z, v0.z,
    }
    v1 = linalg.normalize(change_of_basis * v_local)
    return
}
