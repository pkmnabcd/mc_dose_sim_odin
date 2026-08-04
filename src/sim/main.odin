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

        for n in 0..<photon_cycle_count {
            // Get the distance to next interaction
            // and check for when the photon leaves the medium
            interp_data: [4]f64 = util.interpolate_attenuation(attenuation_data, photon.energy)
            total_attenuation: f64 = 0
            for i in 0..<4 {
                total_attenuation += interp_data[i]
            }
            distance := -1. * math.log(rand.float64(), math.E) / total_attenuation
            // TODO: get the new position, convert to material coords, check them

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

            photon_finished := false
            switch interaction {
                case .Photoelectric:
                    handle_photoelectric(&photon, grid, setup)
                    photon_finished = true
                case .Compton_Scatter:
                    new_photon := handle_compton_scatter(&photon, grid, setup)
                    if new_photon.energy < setup.photon_energy {
                        // TODO: assign energy to current voxel
                        photon_finished = true
                    }
                case .Pair_Production:
                    handle_pair_production(&photon, grid, setup)
                    photon_finished = true
            }
            if photon_finished do break

            // update photon
        }
        // photon not done but through the count. enqueue
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
    sync.lock(&q_mut)
    sync.unlock(&q_mut)

    finish_flag: bool = false

    // TMP Initialize threads
    thread_count := os.get_processor_core_count()
    threads := make([]^thread.Thread, thread_count)
    defer delete(threads)
    threads[0] = thread.create_and_start_with_poly_data3(&photon_q, &q_mut, &setup, run_queue_fill_thread)
    for t in threads {
        thread.destroy(t)
    }
}
