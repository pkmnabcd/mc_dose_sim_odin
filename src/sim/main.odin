package sim

import "../util"

import "core:container/queue"
import "core:fmt"
import "core:math/linalg"
import "core:mem"
import "core:os"
import "core:slice"
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
- max_count: the maximum number to enqueue
- setup: setup data to reference in the process

Returns:
- n: the number of photons actually enqueued
*/
sample_fill_queue :: proc(q: ^queue.Queue(Photon), max_count: u64, setup: ^SetupData) -> (n: u64) {
    n = 0
    if queue.space(q^) == 0 do return

    length, width, trans_mat := setup.cb_length, setup.cb_width, setup.cb_coords_to_world
    source_pos := setup.source_pos
    photon_energy := setup.photon_energy

    // Fill with photons until full or reach count
    for ; n < max_count && queue.space(q^) != 0 ; n += 1 {
        // Sample photon and enqueue
        position := sampleConeField(length, width, trans_mat)
        direction := linalg.normalize(position - source_pos)
        photon := Photon{photon_energy, position, direction}
        queue.enqueue(q, photon)
    }
    return
}

/*
The execution done by the thread that periodicly and atomically fills the photon queue

Inputs:
- q: the photon queue that it fills
- q_mut: the queue mutex
- initial_count: the initial fill of the queue
- setup: the config data that needs to be referenced
*/
run_queue_fill_thread :: proc(q: ^queue.Queue(Photon), q_mut: ^sync.Mutex, initial_count: u64, setup: ^SetupData) {
    // TODO: generate photons in a local queue before locking and updating the global photon queue
    // so you don't have to block while generating the photons
    // TODO: also, use conditional variable to know when to take take the lock
    // TODO: also fix some deadlock that occasionally happens. Figure out what's up with that.
    // It might have to do with how the program checks for being finished or how this thread waits
    photon_sim_count: u64 = setup.photon_sim_count
    fill_level: int = setup.photon_queue_capacity / 2
    capacity: int = setup.photon_queue_capacity
    photon_enqueue_count: u64 = initial_count // this queue was filled before being managed by the thread

    local_q: queue.Queue(Photon)
    queue.init(&local_q, setup.photon_queue_capacity)

    // TODO: while I've implemented pretty well the local buffer to global queue thing, there
    // is a problem where the added_count doesn't actually say how many photons were processed,
    // only how many were put into the local queue. added_count may be useless now and now it's
    // to_add_count that is the useful info?
    // TODO: and there is still an occasional deadlock issue somewhere
    for ; photon_enqueue_count < photon_sim_count ; {
        remaining_count: u64 = photon_sim_count - photon_enqueue_count
        added_count := sample_fill_queue(&local_q, remaining_count, setup)
        photon_enqueue_count += added_count
        for ;; { // wait until good time to take lock
            sync.lock(q_mut)
            space := queue.space(q^)
            if space > fill_level || remaining_count <= u64(space) {
                to_add_count: int = min(space, queue.len(local_q))
                for i in 0..<to_add_count {
                    queue.enqueue(q, queue.dequeue(&local_q))
                }
                sync.unlock(q_mut)
                break
            } else {
                sync.unlock(q_mut)
                time.sleep(50*time.Microsecond)
            }
        }
    }
}

/*
The execution done by the threads that simulate the photon interactions

Inputs:
- simdata: the simulation data that will be used and updated like the photon queue and the grid
- setup: the config data that needs to be referenced
*/
run_simulation_thread :: proc(simdata: ^SimData, setup: ^SetupData) {
    q: ^queue.Queue(Photon) = simdata.q
    q_mut: ^sync.Mutex = simdata.q_mut
    finish_flag: ^bool = simdata.finish_flag

    already_have_photon := false
    photon: Photon
    for ; !finish_flag^ ; {
        // Get photon from queue
        count: u32 = 0
        if !already_have_photon {
            sync.lock(q_mut)
            if queue.len(q^) > 0 {
                photon = queue.dequeue(q)
                sync.unlock(q_mut)
            } else {
                sync.unlock(q_mut)
                time.sleep(100*time.Microsecond)
                continue
            }
        } else do already_have_photon = false

        photon_finished := simulate_photon(&photon, simdata, setup)
        if photon_finished do continue

        // photon not finished after 'photon_cycle_count' cycles. enqueue when safe
        LOCK_LIMIT :: 30
        lock_count := 0
        sync.lock(q_mut)
        for ; queue.space(q^) <= 0 && lock_count < LOCK_LIMIT ; lock_count += 1 {
            sync.unlock(q_mut)
            time.sleep(2*time.Millisecond)
            sync.lock(q_mut)
        }

        if queue.space(q^) <= 0 && lock_count == LOCK_LIMIT {
            // Dequeue next photon before trying to enqueue this one to prevent deadlock
            new_photon := queue.dequeue(q)
            queue.enqueue(q, photon)
            photon = new_photon
            already_have_photon = true
            fmt.println("Avoiding deadlock")
        } else {
            queue.enqueue(q, photon)
        }
        sync.unlock(q_mut)
    }
}

main :: proc() {
    when ODIN_DEBUG {
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)
        defer {
            if len(track.allocation_map) > 0 {
                fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
                for _, entry in track.allocation_map {
                    fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                }
            }
            if len(track.bad_free_array) > 0 {
                fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
                for entry in track.bad_free_array {
                    fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&track)
        }
    }

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
    initial_count := sample_fill_queue(&photon_q, u64(setup.photon_queue_capacity), &setup)
    q_mut: sync.Mutex

    finish_flag: bool = false

    // Initialize threads
    thread_count := os.get_processor_core_count()
    threads := make([]^thread.Thread, thread_count)
    defer delete(threads)
    simdata := SimData{&voxels, &photon_q, &q_mut, &finish_flag}
    threads[0] = thread.create_and_start_with_poly_data4(&photon_q, &q_mut, initial_count, &setup, run_queue_fill_thread)
    for i in 1..<len(threads) {
        threads[i] = thread.create_and_start_with_poly_data2(&simdata, &setup, run_simulation_thread)
    }
    // wait for the queue thread to finish queueing
    thread.destroy(threads[0])
    fmt.println("Queue thread finished")

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
    fmt.println("Simulation threads finished")

    fmt.println("Energy (MeV): ", grid_get(&voxels, 0,500,498))
    fmt.println("Energy (MeV): ", grid_get(&voxels, 0,500,499))
    fmt.println("Energy (MeV): ", grid_get(&voxels, 0,500,500))
    fmt.println("Energy (MeV): ", grid_get(&voxels, 0,500,501))
    fmt.println("Energy (MeV): ", grid_get(&voxels, 0,500,502))

    // For now, assume a certain number of photons enter field per second
    // and multiply by the preset amount of time field was on to get a
    // factor to scale the dose by
    n_real := setup.photon_rate * setup.beam_on_time
    sim_scale := n_real / f64(setup.photon_sim_count)
    fmt.println("n_real/n_sim: ", sim_scale)

    // Get the dose at each voxel in Gy
    for x in 0..<setup.voxel_count_per_dim {
        for y in 0..<setup.voxel_count_per_dim {
            for z in 0..<setup.voxel_count_per_dim {
                grid_mult(&voxels, int(x), int(y), int(z), 1.6022e-13 / setup.voxel_mass * sim_scale) // convert to J and / by mass and scale to real beam
            }
        }
    }
    fmt.println("Dose calc finished")

    fmt.println("Dose (Gy): ", grid_get(&voxels, 0,500,498))
    fmt.println("Dose (Gy): ", grid_get(&voxels, 0,500,499))
    fmt.println("Dose (Gy): ", grid_get(&voxels, 0,500,500))
    fmt.println("Dose (Gy): ", grid_get(&voxels, 0,500,501))
    fmt.println("Dose (Gy): ", grid_get(&voxels, 0,500,502))

    s := voxels.voxels[500*1000:500*1000+1000]
    fmt.println("First layer through middle with varying z")
    fmt.println(s)
    s = voxels.voxels[500*(1000*1000)+500*1000:500*(1000*1000)+500*1000+1000]
    fmt.println("x=0.5, y=0.5, z=[0,1000]")
    fmt.println(s)

    // Save file
    SAVE_FILE :: false
    if SAVE_FILE {
        fmt.println("Attempting to write the raw dose file")
        success = util.write_dose_to_raw("dose.raw", &voxels.voxels, voxels.scale_factor)
        if !success {
            fmt.println("Error: failed to write dose file")
            return
        }
        fmt.println("Write success")
    }

    // Handle the displaying of the dose results
    DISPLAY_RESULTS :: true
    if !DISPLAY_RESULTS do return

    // Get slice and convert to fraction of max dose
    x_to_show := 500
    x_slice := grid_x_slice_make(&voxels, x_to_show)
    defer delete(x_slice)
    low := slice.min(x_slice)
    high := slice.max(x_slice)
    for i in 0..<len(x_slice) {
        x_slice[i] /= high // convert from raw dose to fraction of max dose
    }

    // Convert to color array for heatmap
    color_slice := x_slice_to_color(x_slice)
    defer delete(color_slice)
    fmt.println(color_slice)
}
