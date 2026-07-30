package util

interpolatef32 :: proc(x1, x2, y1, y2, x: f32) -> (y: f32) {
    y = (y2-y1) / (x2-x1) * (x-x1) + y1
    return
}

/*
This function will interpolate between the given xcom data and get the best
matching mass cross sections.

Inputs:
- xcom_data: the mass cross section data from xcom that needs to be interpolated
- photon_energy: the energy of the photon in question

Returns:
- out: all of the interpolated mass cross section values. [incoherent scattering, photoelectric, pp nuclear, pp electron]
*/
interpolate_xcom :: proc(xcom_data: [dynamic][5]f32, photon_energy: f32) -> (out: [4]f32) {
    upper_index := 0
    // NOTE: data starts with lower energies and increases from there.
    for row, i in xcom_data {
        if row[0] > photon_energy {
            upper_index = i
            break
        }
    }
    assert(upper_index > 0, "Upper index should always be found and energy should never be below 0.001 MeV")
    lower_index := upper_index - 1
    for i := 0; i < 4; i += 1 {
        data1 := xcom_data[lower_index]
        data2 := xcom_data[upper_index]
        out[i] = interpolatef32(x1=data1[0], x2=data2[0], y1=data1[i+1], y2=data2[i+1], x=photon_energy)
    }
    return
}
