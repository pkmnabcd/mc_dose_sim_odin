package sim

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
sampleConeField :: proc(length, width :f32, M: matrix[4,4]f32) -> [3]f32 {
}
