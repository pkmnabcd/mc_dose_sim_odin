package sim

import "../util"

import "core:container/queue"
import "core:fmt"
import "core:math"
import "core:math/linalg"

Photon :: struct {
    energy: f32,       // Current photon energy in MeV.
    position: [3]f32,  // Position in world coords.
    direction: [3]f32, // Direction vector in world coords. Should be normalized.
}

sample_fill_queue :: proc(q: ^queue.Queue(Photon), setup: ^SetupData) {
    if queue.space(q^) == 0 do return

    length, width, trans_mat := setup.cb_length, setup.cb_width, setup.cb_coords_to_world
    source_pos := setup.source_pos
    photon_energy := setup.photon_energy

    // Fill with photons until full
    for ; queue.space(q^) != 0 ; {
        // Sample photon
        position := sampleConeField(length, width, trans_mat)
        direction := linalg.normalize(position - source_pos)
        photon := Photon{photon_energy, position, direction}
        queue.enqueue(q, photon)
    }
}

main :: proc() {
    setup, success := setupSim()
    defer delete(setup.xcom_data)

    fmt.println("Beam Center: ", setup.cb_center)
    fmt.printfln("y range: [%v,%v]", setup.cb_center.y - setup.cb_length/2, setup.cb_center.y + setup.cb_length/2)
    fmt.printfln("z range: [%v,%v]", setup.cb_center.z - setup.cb_width/2, setup.cb_center.z + setup.cb_width/2)

    voxels: Grid = make_grid(int(setup.voxel_count_per_dim))
    defer destroy_grid(&voxels)

    photon_q: queue.Queue(Photon)
    queue.init(&photon_q, 400)
    defer queue.destroy(&photon_q)
    sample_fill_queue(&photon_q, &setup)

    old_vec := [3]f32{1,0,0}
    new_vec := util.rotate_direction(old_vec, math.PI/2, 0)
    fmt.println("Old vec: ", old_vec, "\nNew vec: ", new_vec)
    old_vec = [3]f32{1,0,0}
    new_vec = util.rotate_direction(old_vec, math.PI/2, math.PI)
    fmt.println("Old vec: ", old_vec, "\nNew vec: ", new_vec)
    old_vec = [3]f32{1,0,0}
    new_vec = util.rotate_direction(old_vec, math.PI/2, math.PI/2)
    fmt.println("Old vec: ", old_vec, "\nNew vec: ", new_vec)
    old_vec = [3]f32{1,0,0}
    new_vec = util.rotate_direction(old_vec, math.PI/2, 3*math.PI/2)
    fmt.println("Old vec: ", old_vec, "\nNew vec: ", new_vec)
}
