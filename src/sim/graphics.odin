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
