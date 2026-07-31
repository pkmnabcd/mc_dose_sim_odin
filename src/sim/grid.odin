package sim

Grid :: struct {
    voxels: []f32,
    size: int,
}

make_grid :: proc(size: int) -> Grid {
    return Grid{
        voxels = make([]f32, size*size*size),
        size = size,
    }
}

destroy_grid :: proc(grid: ^Grid) {
    delete(grid.voxels)
}

grid_get :: proc(grid: ^Grid, x, y, z: int) -> f32 {
    index := (x * grid.size * grid.size) + (y * grid.size) + z
    return grid.voxels[index]
}

grid_add :: proc(grid: ^Grid, x, y, z: int, val: f32) {
    index := (x * grid.size * grid.size) + (y * grid.size) + z
    grid.voxels[index] += val
}
