package util

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

parse_xcom_data :: proc(filepath: string) -> ([dynamic][5]f32, bool) {
    out := [dynamic][5]f32{}
    incomplete = true

    data, err := os.read_entire_file_from_path(filepath, context.allocator)
    if err != nil {
        fmt.println("Error reading the xcom data file: %v\n\tError: %v", filepath, err)
        return out, incomplete
    }

    all_file: string = string(data)
    fmt.println("NOTE: This program expects all 7 cols of XCOM data, but skips cols (0 based indexing) 1, 6, and 7.")
    for line in strings.split_lines_iterator(&all_file) {
        line_data := [5]f32{}
        col_num := 0
        data_index := 0
        for str_val in strings.fields_iterator(&line) {
            if !(col_num == 1 || col_num == 6 || col_num == 7) {
                val, ok := strconv.parse_f32(str_val)
                if !ok {
                    fmt.println("ERROR: the following string couldn't be converted to a f32:", str_val)
                    return out, incomplete
                }
                line_data[data_index] = val
                data_index += 1
            }
            col_num += 1
        }
        append(&out, line_data)
    }
    incomplete = false
    return out, incomplete
}
