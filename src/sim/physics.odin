package sim

ELECTRON_REST_MASS_ENERGY:f32 : 0.511 // MeV

/*
Do the physics and energy deposition associated with the photoelectric
effect. For now, I assume all the photon's energy is deposited in the
voxel it's located in (ignoring the electron's unique physics for now).
Also, it is disregarded if the photon is outisde the bounds of the
material.

Inputs:
- photon: the Photon struct with the needed incident photon info
- grid: the grid of energy deposition where the photon's energy is put into
- setup: the SetupData that has vital parameters
*/
handle_photoelectric :: proc(photon: ^Photon, grid: ^Grid, setup: ^SetupData) {
    voxel_count_per_dim := setup.voxel_count_per_dim

    // Need to convert to grid coordinates to find the best grid position
    photon_pos := [4]f32{photon.position.x, photon.position.y, photon.position.z, 1}
    photon_pos_grid := setup.material_to_world_coords * photon_pos
    photon_pos_grid_round := [3]int{}
    for i in 0..<3 {
        pos := int(photon_pos_grid[i])
        if pos >= int(voxel_count_per_dim) do return // skip photons that have escaped the bounds of the simulation

        photon_pos_grid_round[i] = pos
    }
    grid_add(grid, photon_pos_grid_round.x, photon_pos_grid_round.y, photon_pos_grid_round.z, photon.energy)
    return
}

/*
Do the physics and energy deposition associated with pair production.
For now, I assume all the photon's energy is deposited in the voxel
it's located in (ignoring the electron's and positron's unique physics
for now). Also, it is disregarded if the photon is outisde the bounds
of the material.

Inputs:
- photon: the Photon struct with the needed incident photon info
- grid: the grid of energy deposition where the photon's energy is put into
- setup: the SetupData that has vital parameters
*/
handle_pair_production :: proc(photon: ^Photon, grid: ^Grid, setup: ^SetupData) {
    voxel_count_per_dim := setup.voxel_count_per_dim

    // Need to convert to grid coordinates to find the best grid position
    photon_pos := [4]f32{photon.position.x, photon.position.y, photon.position.z, 1}
    photon_pos_grid := setup.material_to_world_coords * photon_pos
    photon_pos_grid_round := [3]int{}
    for i in 0..<3 {
        pos := int(photon_pos_grid[i])
        if pos >= int(voxel_count_per_dim) do return // skip photons that have escaped the bounds of the simulation

        photon_pos_grid_round[i] = pos
    }
    grid_add(grid, photon_pos_grid_round.x, photon_pos_grid_round.y, photon_pos_grid_round.z, photon.energy)
    return
}

/*
Do the physics for Compton scattering
*/
handle_compton_scatter :: proc(photon: ^Photon, grid: ^Grid, setup: ^SetupData) {
    // NOTE: this code is pretty much just what openMC does, cross-referenced with
    // the following papers.
    // https://www.sciencedirect.com/science/article/pii/S1877705811054865
    // https://www.sciencedirect.com/science/article/pii/S1877705811021552
    k := photon.energy / ELECTRON_REST_MASS_ENERGY // photon energy / electron rest energy
}
