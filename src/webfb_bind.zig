const std = @import("std");
const mem = std.mem;

extern fn js_log(i32) void;
extern fn js_assert_failure(u32, u32, u32) void;

extern fn create_lvgl_gui() void;
extern fn init_lvgl(w: u32, h: u32, fb_adr: u32) void;
extern fn lvgl_frame_count() u32;
extern fn lv_tick_inc(u32) void;
extern fn lv_timer_handler() u32;

export fn init() void {
    initMemory();
    init_lvgl(image_width, image_height, buffer_adr);
    create_lvgl_gui();
}

fn initMemory() void {
    const num_pages_required = debug_tail_page_i + 1;
    const num_pages = @wasmMemorySize(0);
    if (num_pages < num_pages_required)
        if (@wasmMemoryGrow(0, num_pages_required - num_pages) == -1)
            @panic("Failed to increase memory");
}

// global_base is set to page 8 in build.zig
const lvgl_mem_page = 24; // FIXME issue with smaller offset
const buffer_adr = std.mem.page_size * (lvgl_mem_page + 1);
const image_width = 800;
const image_height = 480;
const debug_tail_page_i = (buffer_adr + bufferSize()) / std.mem.page_size + 1;
const debug_tail_page = @intToPtr(*[std.mem.page_size]u8, debug_tail_page_i * std.mem.page_size);

export fn _assert_failure(filename: [*:0]const u8, line: u32) void {
    const len = mem.indexOfSentinel(u8, 0, filename);
    mem.copy(u8, debug_tail_page, filename[0..len]);
    js_assert_failure(@ptrToInt(debug_tail_page), len, line);
}

export fn bufferAddress() u32 {
    return buffer_adr;
}

export fn bufferSize() u32 {
    return image_width * image_height * 4;
}

export fn imageWidth() u32 {
    return image_width;
}

export fn imageHeight() u32 {
    return image_height;
}

var prev_monotime: u32 = 0;
export fn update(monotime_ms: u32) void {
    lv_tick_inc(monotime_ms -% prev_monotime);
    prev_monotime = monotime_ms;
    _ = lv_timer_handler();
}

var prev_frame_count: u32 = 0;
export fn popShouldDraw() bool {
    const frame_count = lvgl_frame_count();
    defer prev_frame_count = frame_count;
    return frame_count != prev_frame_count;
}
