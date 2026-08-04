package sim

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
