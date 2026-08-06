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
    return f64(grid.voxels[index]) / f64(grid.scale_factor)
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
