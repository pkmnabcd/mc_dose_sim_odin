package sim

SetupData :: struct {
    // General Setup
    voxel_len: f32,              // length of the sides of the cube that make a voxel in m
    photon_sim_count: u64,       // the number of photons to simulate
    material_origin_pos: [3]f32, // the position in world space that represents indexes (0,0,0) of the voxel array

    // Material stuff
    material_density: f32,       // density of the irradiated material in kg/m^3

    // Beam stuff
    cone_beam_length: f32,       // length of one side of cone beam surface
    cone_beam_width: f32,        // length of other side of cone beam surface
    cone_beam_coords: [4][3]f32, // the four positions that make up the cone beam surface
    cone_beam_center: [3]f32,    // position in world space of the center of cone beam surface
    isocenter_pos: [3]f32,       // position in world space of isocenter
    source_pos:    [3]f32,       // position in world space of cone beam source
    photon_energy: f32,          // energy of monoenergetic photons in MeV
}
// TODO: add a document explaining (especially to myself) the coordinate systems.
// How the world coordates exist (probably with units meters), and the origin of the material model
// is placed at some coordinate that is the origin (material_origin_pos), which is the coordinate
// at which the material model's index (0,0,0) represents. I need to decide if I want that to be the
// corner of the model or the middle.
// I should also be ready to do some coordinate transformations to make things easier. For example,
// it's almost certainly easier to sample the rectangular cone beam field from a coord system where
// the coords align with the rectangle edges, then transform those coords back to world coords.
// TODO: I also need a matrix to possibly transform the coordinate system of the material model
// to world coords.

/*
Gather the simulation parameters and precompute some useful things.
For now these values are hardcoded, but they will later be obtained from data and config files.

Returns:
- SetupData struct containing the simulation parameters
*/
setupSim :: proc() -> SetupData {
}
