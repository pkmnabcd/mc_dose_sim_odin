package sim

import "core:math/rand"

/*
Randomly sample the cone beam surface field for a point in the field
for a photon to start the simulation from. It starts by sampling from
[-length/2, length/2] and [-width/2, width/2] for the y and z coordinates
and then applying the transformation matrix M to put it in world coords.

As of now, it assumes the field is hitting the a surface parallel to
the yz plane

Inputs:
- length: length of the field
- width: width of the field
- M: the transformation matrix to convert to world coords

Returns:
- the randomly sampled point in world coords
*/
sampleConeField :: proc(length, width :f64, M: matrix[4,4]f64) -> [3]f64 {
    y_coord := rand.float64_range(-1*length / 2, length / 2)
    z_coord := rand.float64_range(-1*width / 2, width / 2)
    self_coords := [4]f64{0, y_coord, z_coord, 1}
    return (M * self_coords).xyz
}
