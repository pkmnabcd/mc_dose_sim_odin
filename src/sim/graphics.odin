package sim

import "vendor:raylib"

x_slice_to_color :: proc(x_slice: []f64) -> (heatmap: []raylib.Color) {
    heatmap = make([]raylib.Color, len(x_slice))
    for i in 0..<len(x_slice) {
        t := clamp(x_slice[i], 0.0, 1.0)
        r, g, b: f64

        if t < 0.25 { // blue -> cyan
            r = 0.0
            g = t / 0.25
            b = 1.0
        } else if t < 0.5 { // cyan -> green
            r = 0.0
            g = 1.0
            b = 1.0 - (t - 0.25) / 0.25
        } else if t < 0.75 { // green -> yellow
            r = (t - 0.5) / 0.25
            g = 1.0
            b = 0.0
        } else { // yellow -> red
            r = 1.0
            g = 1.0 - (t - 0.75) / 0.25
            b = 0.0
        }

        heatmap[i] = raylib.Color{
            u8(r * 255.0),
            u8(g * 255.0),
            u8(b * 255.0),
            255 // full opacity
        }
    }
    return
}

display_x_slice_img :: proc(x_slice_heatmap: []raylib.Color, voxel_count_per_dim: u32) {
    raylib.InitWindow(800, 800, "MC Dose Heatmap")
    defer raylib.CloseWindow()
    raylib.SetTargetFPS(60)

    dim := i32(voxel_count_per_dim)
    empty_img := raylib.GenImageColor(dim, dim, raylib.BLACK)
    texture := raylib.LoadTextureFromImage(empty_img)
    raylib.UnloadImage(empty_img)
    defer raylib.UnloadTexture(texture)

    raylib.UpdateTexture(texture, raw_data(x_slice_heatmap))

    for !raylib.WindowShouldClose() {
        // Draw Frame
        raylib.BeginDrawing()
        raylib.ClearBackground(raylib.DARKGRAY)

        // Stretch texture across 800x800 window smoothly
        src_rect := raylib.Rectangle{0, 0, f32(texture.width), f32(texture.height)}
        dest_rect := raylib.Rectangle{0,0,800,800}
        raylib.DrawTexturePro(texture, src_rect, dest_rect, {0,0}, 0.0, raylib.WHITE)
        raylib.EndDrawing()
    }
}
