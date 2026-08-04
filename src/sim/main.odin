package sim

import "../util"

import "core:container/queue"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:os"
import "core:sync"
import "core:thread"

Photon :: struct {
    energy: f64,       // Current photon energy in MeV.
    position: [3]f64,  // Position in world coords.
    direction: [3]f64, // Direction vector in world coords. Should be normalized.
}

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

    // TMP Initialize threads
    thread_count := os.get_processor_core_count()
    threads := make([]^thread.Thread, thread_count)
    defer delete(threads)
    threads[0] = thread.create_and_start_with_poly_data3(&photon_q, &q_mut, &setup, run_queue_fill_thread)
    for t in threads {
        thread.destroy(t)
    }
}
