package sim

import "core:fmt"
import "core:container/queue"

Photon :: struct {
    energy: f32,       // Current photon energy in MeV.
    position: [3]f32,  // Position in world coords.
    direction: [3]f32, // Direction vector in world coords. Should be normalized.
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
}
