package sim

import "../util"

import "core:container/queue"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:os"
import "core:sync"
import "core:thread"
import "core:time"

Photon :: struct {
    energy: f64,       // Current photon energy in MeV.
    position: [3]f64,  // Position in world coords.
    direction: [3]f64, // Direction vector in world coords. Should be normalized.
}

SimData :: struct {
    grid: ^Grid,             // The deposited energy grid
    q: ^queue.Queue(Photon), // The photon queue
    q_mut: ^sync.Mutex,      // The mutex for the photon queue
    finish_flag: ^bool,      // The flag to signal that no more photons are coming
}

Interaction :: enum{Compton_Scatter, Pair_Production, Photoelectric}

/*
Randomly sample photons entering the surface from a cone beam and push those
initial photons to the photon queue until the queue is full or count is reached

Inputs:
- q: the photon queue to have photons added to
- count: the maximum number to enqueue
- setup: setup data to reference in the process
*/
sample_fill_queue :: proc(q: ^queue.Queue(Photon), count: u64, setup: ^SetupData) {
    count := count
    if queue.space(q^) == 0 do return

    length, width, trans_mat := setup.cb_length, setup.cb_width, setup.cb_coords_to_world
    source_pos := setup.source_pos
    photon_energy := setup.photon_energy

    // Fill with photons until full or reach count
    for ; count > 0 || queue.space(q^) != 0 ; count -= 1 {
        // Sample photon and enqueue
        position := sampleConeField(length, width, trans_mat)
        direction := linalg.normalize(position - source_pos)
        photon := Photon{photon_energy, position, direction}
        queue.enqueue(q, photon)
    }
}

/*
The execution done by the thread that periodicly and atomically fills the photon queue

Inputs:
- q: the photon queue that it fills
- q_mut: the queue mutex
- setup: the config data that needs to be referenced
*/
run_queue_fill_thread :: proc(q: ^queue.Queue(Photon), q_mut: ^sync.Mutex, setup: ^SetupData) {
    photon_sim_count: u64 = setup.photon_sim_count
    fill_level: int = setup.photon_queue_capacity / 2
    capacity: int = setup.photon_queue_capacity
    photon_enqueue_count: u64 = u64(setup.photon_queue_capacity)

    // Fill the photon queue once it half full until photon_sim_count reached
    for ; photon_enqueue_count <= photon_sim_count ; { // enqueue stops after this reaches setup.photon_sim_count
        if queue.space(q^) > fill_level {
            sync.lock(q_mut)
            to_add: u64 = photon_sim_count - photon_enqueue_count
            sample_fill_queue(q, to_add, setup)
            photon_enqueue_count += to_add
            sync.unlock(q_mut)
        } else {
            thread.yield()
        }
    }
}

run_simulation_thread :: proc(simdata: ^SimData, setup: ^SetupData) {
    grid: ^Grid = simdata.grid
    q: ^queue.Queue(Photon) = simdata.q
    q_mut: ^sync.Mutex = simdata.q_mut
    finish_flag: ^bool = simdata.finish_flag
    photon_cycle_count := setup.photon_cycle_count
    attenuation_data := setup.attenuation_data
    voxel_count_per_dim := setup.voxel_count_per_dim
    world_to_material_coords := setup.world_to_material_coords

    for ; !finish_flag^ ; {
        // Get photon from queue
        count: u32 = 0
        photon: Photon
        sync.lock(q_mut)
        if queue.len(q^) > 0 {
            photon = queue.dequeue(q)
            sync.unlock(q_mut)
        } else {
            thread.yield()
            sync.unlock(q_mut)
            continue
        }

        photon_finished := false
        for _ in 0..<photon_cycle_count {
            // Get the distance to next interaction
            // and check for when the photon leaves the medium
            interp_data: [4]f64 = util.interpolate_attenuation(attenuation_data, photon.energy)
            total_attenuation: f64 = 0
            for i in 0..<4 {
                total_attenuation += interp_data[i]
            }
            distance := -1. * math.log(rand.float64(), math.E) / total_attenuation // distance should be in m
            photon_pos := photon.position + distance * photon.direction

            // Get grid pos and make sure it's in the grid
            // Need to convert to grid coordinates to find the best grid position
            photon_pos4 := [4]f64{photon_pos.x, photon_pos.y, photon_pos.z, 1}
            photon_pos_grid := world_to_material_coords * photon_pos4
            photon_pos_grid_round := [3]int{}
            photon_out_of_bounds := false
            for i in 0..<3 {
                pos := int(math.round(photon_pos_grid[i]))
                if pos >= int(voxel_count_per_dim) { // skip photons that have escaped the bounds of the simulation
                    photon_out_of_bounds = true
                    break
                }

                photon_pos_grid_round[i] = pos
            }
            if photon_out_of_bounds { // get the next photon
                photon_finished = true
                break
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

            new_photon: Photon = photon
            switch interaction {
                case .Photoelectric:
                    handle_photoelectric(&photon, photon_pos_grid_round.x, photon_pos_grid_round.y, photon_pos_grid_round.z, grid)
                    photon_finished = true
                case .Compton_Scatter:
                    new_photon = handle_compton_scatter(&photon, photon_pos_grid_round.x, photon_pos_grid_round.y, photon_pos_grid_round.z, grid)
                    if new_photon.energy < setup.photon_cutoff {
                        grid_add(grid, photon_pos_grid_round.x, photon_pos_grid_round.y, photon_pos_grid_round.z, new_photon.energy)
                        photon_finished = true
                    }
                case .Pair_Production:
                    handle_pair_production(&photon, photon_pos_grid_round.x, photon_pos_grid_round.y, photon_pos_grid_round.z, grid)
                    photon_finished = true
            }
            if photon_finished do break

            // update photon
            photon.energy = new_photon.energy
            photon.direction = new_photon.direction
            photon.position = photon_pos
        }
        if photon_finished do continue

        // photon not finished after 'photon_cycle_count' cycles. enqueue when safe
        sync.lock(q_mut)
        for ; queue.space(q^) <= 0 ; {
            sync.unlock(q_mut)
            thread.yield()
            sync.lock(q_mut)
        }
        queue.enqueue(q, photon)
        sync.unlock(q_mut)
    }
}

main :: proc() {
    setup, success := setupSim()
    defer delete(setup.attenuation_data)

    fmt.println("Beam Center: ", setup.cb_center)
    fmt.printfln("y range: [%v,%v]", setup.cb_center.y - setup.cb_length/2, setup.cb_center.y + setup.cb_length/2)
    fmt.printfln("z range: [%v,%v]", setup.cb_center.z - setup.cb_width/2, setup.cb_center.z + setup.cb_width/2)

    voxels: Grid = make_grid(int(setup.voxel_count_per_dim), setup.scale_factor)
    defer destroy_grid(&voxels)

    // Set up photon queue, queue mutex, and photon count
    photon_q: queue.Queue(Photon)
    queue.init(&photon_q, setup.photon_queue_capacity)
    defer queue.destroy(&photon_q)
    sample_fill_queue(&photon_q, u64(setup.photon_queue_capacity), &setup)
    q_mut: sync.Mutex

    finish_flag: bool = false

    // Initialize threads
    thread_count := os.get_processor_core_count()
    threads := make([]^thread.Thread, thread_count)
    defer delete(threads)
    simdata := SimData{&voxels, &photon_q, &q_mut, &finish_flag}
    threads[0] = thread.create_and_start_with_poly_data3(&photon_q, &q_mut, &setup, run_queue_fill_thread)
    for i in 1..<len(threads) {
        thread.create_and_start_with_poly_data2(&simdata, &setup, run_simulation_thread)
    }
    // wait for the queue thread to finish queueing
    thread.destroy(threads[0])

    // wait to make sure that all threads have finished
    empty_queue_wait: time.Duration = 2 * time.Second
    for ;; {
        if queue.len(photon_q) == 0 {
            time.sleep(empty_queue_wait)
            break
        }
    }
    finish_flag = true
    for i in 1..<len(threads) {
        thread.destroy(threads[i])
    }

    // Divide by the mass of the voxel to get dose

    // Account for the varying number of simulated photons

    // Save file
}
