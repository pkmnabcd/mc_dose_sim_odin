package sim

import "core:sync"

Grid :: struct {
    voxels: []u64,
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

grid_get :: proc(grid: ^Grid, x, y, z: int) -> f32 {
    index := (x * grid.size * grid.size) + (y * grid.size) + z
    return f32(grid.voxels[index]) / f32(grid.scale_factor)
}

grid_add :: proc(grid: ^Grid, x, y, z: int, val: f32) {
    index := (x * grid.size * grid.size) + (y * grid.size) + z
    scaled_val := u64(f64(val) * grid.scale_factor)
    sync.atomic_add(&grid.voxels[index], scaled_val) // prevent multiple threads from writing to same voxel
}
