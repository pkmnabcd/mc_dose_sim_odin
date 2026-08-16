package sim

import "core:sync"

Grid :: struct {
    voxels: []u64, // the value here should be deposited energy in MeV, then later dose in Gy
    size: int,
    scale_factor: f64,
}

make_grid :: proc(size: int, scale_factor: f64) -> Grid {
    return Grid{
        voxels = make([]u64, size*size*size),
        size = size,
        scale_factor = scale_factor,
    }
}

destroy_grid :: proc(grid: ^Grid) {
    delete(grid.voxels)
}

grid_get :: proc(grid: ^Grid, x, y, z: int) -> f64 {
    index := (x * grid.size * grid.size) + (y * grid.size) + z
    return f64(grid.voxels[index]) / grid.scale_factor
}

grid_add :: proc(grid: ^Grid, x, y, z: int, val: f64) {
    index := (x * grid.size * grid.size) + (y * grid.size) + z
    scaled_val := u64(val * grid.scale_factor)
    sync.atomic_add(&grid.voxels[index], scaled_val) // prevent multiple threads from writing to same voxel
}

grid_mult :: proc(grid: ^Grid, x, y, z: int, val: f64) {
    index := (x * grid.size * grid.size) + (y * grid.size) + z
    data_val := grid_get(grid, x, y, z)
    grid.voxels[index] = u64(data_val * val * grid.scale_factor)
}

grid_x_slice_make :: proc(grid: ^Grid, x: int) -> (out: []f64) {
    out = make([]f64, grid.size*grid.size)
    // NOTE: this is easier than getting slices of constant y or z since
    // all values from (x*size*size, (x+1)*size*size) all are in the same
    // chunk of memory, already correctly ordered.
    start_index: int = x * grid.size * grid.size
    end_index: int = (x+1) * grid.size * grid.size
    tmp_slice: []u64 = grid.voxels[start_index : end_index]
    for i in 0..<len(tmp_slice) {
        out[i] = f64(tmp_slice[i]) / grid.scale_factor
    }
    return
}
