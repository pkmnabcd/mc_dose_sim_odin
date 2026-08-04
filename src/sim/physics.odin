package sim

import "core:math"
import "core:math/rand"

ELECTRON_REST_MASS_ENERGY:f64 : 0.511 // MeV

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
    photon_pos := [4]f64{photon.position.x, photon.position.y, photon.position.z, 1}
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
    photon_pos := [4]f64{photon.position.x, photon.position.y, photon.position.z, 1}
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

sample_scatter :: proc(k: f64) -> (new_k: f64, theta: f64) {
    // If k < 3, use Kahn's Rejection Method, else use Koblinger's Direct Method.
    b: f64 = 1. + 2. * k
    mu: f64
    if k < 3. {
        // Kahn's rejection
        t := b / (b+8.)
        x: f64
        for ;; {
            if rand.float64() < t {
                r := rand.float64_range(0., 2.)
                x = 1. + k * r
                if rand.float64() < 4. / x * (1. - 1. / x) {
                    mu = 1 - r
                    break
                }
            } else {
                x = b / (1. + 2. * k * rand.float64())
                mu = 1. + (1. - x) / k
                if rand.float64() < 0.5 * (mu * mu + 1. / x) {
                    break
                }
            }
        }
        new_k = k / x
    } else {
        // Koblinger's direct
        gamma := 1. - math.pow(b, -2.)
        s := rand.float64()
        s *= 4. / k + 0.5 * gamma + (1. - (1. + b) / (k*k)) * math.log(b, base=math.E)
        if s <= 2. / k {
            new_k = k / (1. + 2. * k * rand.float64())
        } else if s <= 4. / k {
            new_k = k * (1. + 2. * k * rand.float64()) / b
        } else if s <= 4. / k + 0.5 * gamma {
            new_k = k * math.sqrt(1. - gamma * rand.float64())
        } else {
            new_k = k / math.pow(b, rand.float64())
        }
        mu = 1. + 1. / k - 1. / new_k
    }
    theta = math.acos(mu)
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
    new_k, theta := sample_scatter(k)
}
