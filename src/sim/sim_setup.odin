package sim

import "core:math/linalg"

import "../util"

SetupData :: struct {
    // General Setup
    voxel_len: f64,                           // length of the sides of the cube that make a voxel in m
    photon_sim_count: u64,                    // the number of photons to simulate
    material_to_world_coords: matrix[4,4]f64, // the matrix to transform material coords to world coords
    world_to_material_coords: matrix[4,4]f64, // the matrix to transform world coords to material coords
    photon_queue_capacity: int,               // the maximum capacity of the photon queue
    scale_factor: f64,                        // the fixed-point scale factor for the voxels
    photon_cycle_count: u32,                  // the number of interactions to simulate before adding photon to queue again

    // Material stuff
    material_density: f64,             // density of the irradiated material in g/cm^3
    voxel_count_per_dim: u32,          // the number of voxels in each dimension of the array
    attenuation_data: [dynamic][5]f64, // the linear attenuation data for your material in MeV for col 0 and prob/cm for the other cols.

    // Beam stuff
    isocenter_pos: [3]f64, // position in world space of isocenter
    source_pos:    [3]f64, // position in world space of cone beam source
    photon_energy: f64,    // energy of monoenergetic photons in MeV
    photon_cutoff: f64,    // the energy at which photons stop getting simulated

    // Cone beam specific
    cb_length: f64,                     // length of one side of cone beam surface in m
    cb_width: f64,                      // length of other side of cone beam surface in m
    cb_center: [3]f64,                  // position in world space of the center of cone beam surface
    cb_coords_to_world: matrix[4,4]f64, // the matrix needed to transform the field surface coords to world coords
}

/*
Gather the simulation parameters and precompute some useful things.
For now these values are hardcoded, but they will later be obtained from data and config files.

Returns:
- data: struct containing the simulation parameters
- success: flag saying whether everything succeeded
*/
setupSim :: proc() -> (data: SetupData, success: bool) {
    data.voxel_len = 1e-3
    data.photon_sim_count = 10_000_000
    data.photon_queue_capacity = 1000
    data.scale_factor = 1e12
    data.photon_cycle_count = 15

    data.material_density = 1. // water
    data.voxel_count_per_dim = 1000 // voxels should take about 8 gb of memory (1000^3 * 8 byte uint)

    data.isocenter_pos = [3]f64{0.5, 0.5, 0.5}
    data.source_pos = [3]f64{-1., 0.5, 0.5}
    data.photon_energy = 1. // MeV
    data.photon_cutoff = 0.001

    data.cb_length = 0.2
    data.cb_width = 0.3

    // Determine field center
    field_normal: [3]f64 = [3]f64{1,0,0}// hitting the yz plane
    plane_pt: [3]f64 = [3]f64{-1*data.voxel_len/2, 0, 0} // account for the depth of the voxel center
    line_vec: [3]f64 = linalg.normalize(data.isocenter_pos - data.source_pos)
    data.cb_center = util.plane_line_intersect_point(plane_pt, data.source_pos, line_vec, field_normal)

    // For now, material has same coordinate system as world except on mm scale instead of m.
    data.material_to_world_coords = matrix[4,4]f64{
        data.voxel_len, 0, 0, 0,
        0, data.voxel_len, 0, 0,
        0, 0, data.voxel_len, 0,
        0, 0, 0, 1,
    }
    data.world_to_material_coords = linalg.inverse(data.material_to_world_coords)

    // For now, this will have same coordinate system as world except displaced with beam center at 0,0
    data.cb_coords_to_world = matrix[4,4]f64{
        1, 0, 0, data.cb_center.x,
        0, 1, 0, data.cb_center.y,
        0, 0, 1, data.cb_center.z,
        0, 0, 0, 1,
    }

    xcom_data, read_incomplete := util.parse_xcom_data("data/water_xcom.txt")
    data.attenuation_data = xcom_data
    success = !read_incomplete
    if success {
        // Convert the mass cross section coefficients from xcom to
        // linear attenuation coefficients by multiplying by density
        // also convert to m instead of cm
        for &row in data.attenuation_data {
            for i := 1; i < 5; i += 1 { // skip the photon energy that is in MeV
                row[i] *= data.material_density
                row[i] /= 100.
            }
        }
    }
    return
}
