package sim

import "../util"

import "core:math"
import "core:math/rand"

/*
Get grid indexes and check to make sure that it isn't out of the bounds of the voxels.
*/
get_grid_indexes :: proc(photon_pos: [3]f64, setup: ^SetupData) -> (indexes: [3]int, in_bounds: bool) {
    photon_pos4 := [4]f64{photon_pos.x, photon_pos.y, photon_pos.z, 1}
    photon_pos_grid := setup.world_to_material_coords * photon_pos4
    in_bounds = true
    for i in 0..<3 {
        pos := int(math.round(photon_pos_grid[i]))
        if pos >= int(setup.voxel_count_per_dim) || pos < 0 { // skip photons that have escaped the bounds of the simulation
            in_bounds = false
            break
        }

        indexes[i] = pos
    }
    return
}

simulate_photon :: proc(photon: ^Photon, simdata: ^SimData, setup: ^SetupData) -> (finished: bool) {
    finished = false
    grid: ^Grid = simdata.grid
    for _ in 0..<setup.photon_cycle_count {
        // Get the distance to next interaction
        // and check for when the photon leaves the medium
        interp_data: [4]f64 = util.interpolate_attenuation(setup.attenuation_data, photon.energy)
        total_attenuation: f64 = 0
        for i in 0..<4 {
            total_attenuation += interp_data[i]
        }
        distance := -1. * math.log(rand.float64(), math.E) / total_attenuation // distance should be in m
        photon_pos := photon.position + distance * photon.direction

        photon_indexes, in_bounds := get_grid_indexes(photon_pos, setup)
        if !in_bounds { // get the next photon
            finished = true
            return
        }

        // Choose the interaction and handle it
        rand_num := rand.float64()
        interaction: Interaction
        compton_atten := interp_data[0]
        photo_atten := interp_data[1]

        if rand_num < photo_atten / total_attenuation {
            interaction = Interaction.Photoelectric
        } else if rand_num < (photo_atten + compton_atten) / photo_atten {
            interaction = Interaction.Compton_Scatter
        } else {
            interaction = Interaction.Pair_Production
        }

        new_photon: Photon = photon^
        switch interaction {
            case .Photoelectric:
                handle_photoelectric(photon, photon_indexes.x, photon_indexes.y, photon_indexes.z, grid)
                finished = true
            case .Compton_Scatter:
                new_photon = handle_compton_scatter(photon, photon_indexes.x, photon_indexes.y, photon_indexes.z, grid)
                if new_photon.energy < setup.photon_cutoff {
                    grid_add(grid, photon_indexes.x, photon_indexes.y, photon_indexes.z, new_photon.energy)
                    finished = true
                }
            case .Pair_Production:
                handle_pair_production(photon, photon_indexes.x, photon_indexes.y, photon_indexes.z, grid)
                finished = true
        }
        if finished do return

        // update photon
        photon.energy = new_photon.energy
        photon.direction = new_photon.direction
        photon.position = photon_pos
    }
    // If here, finished will still be false and photon will be added back to queue
    return
}
