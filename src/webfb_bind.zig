const std = @import("std");
const mem = std.mem;

extern fn js_log_int(i32) void;
extern fn js_assert_failure(u32, u32, u32) void;

extern fn create_lvgl_gui() void;
extern fn init_lvgl(fb: *void, w: u32, h: u32) void;
extern fn lvgl_frame_count() u32;
extern fn lv_tick_inc(u32) void;
extern fn lv_timer_handler() u32;
extern var input_device_data: extern struct {
    x: i32,
    y: i32,
    encoder_pos: i32,
    is_pressed: bool,
    is_encoder_pressed: bool,
};

export fn init() void {
    initMemory();
    init_lvgl(@ptrCast(*void, frame_buf.ptr), image_width, image_height);
    create_lvgl_gui();
}

fn initMemory() void {
    const pa = std.heap.page_allocator;
    debug_page = pa.create([mem.page_size]u8) catch unreachable;
    frame_buf = pa.alloc(u32, image_width * image_height) catch unreachable;
}

const image_width = 800;
const image_height = 480;

var debug_page: *[mem.page_size]u8 = undefined;
var frame_buf: []u32 = undefined;

export fn _assert_failure(filename: [*:0]const u8, line: u32) void {
    const len = mem.indexOfSentinel(u8, 0, filename);
    mem.copy(u8, debug_page, filename[0..len]);
    js_assert_failure(@ptrToInt(debug_page), len, line);
}

export fn bufferAddress() u32 {
    return @intCast(u32, @ptrToInt(frame_buf.ptr));
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

export fn setInputPosition(x: i32, y: i32) void {
    input_device_data.x = x;
    input_device_data.y = y;
}

export fn setInputPressed(state: bool) void {
    input_device_data.is_pressed = state;
}

export fn setWheelDelta(val: i32) void {
    // convert potentially large pixel value to encoder increment
    // invert y: scrolling the wheel forward should increase a value
    const inc = @as(i32, @boolToInt(val < 0)) - @as(i32, @boolToInt(val > 0));
    input_device_data.encoder_pos +%= inc;
}

export fn setWheelPressed(state: bool) void {
    input_device_data.is_encoder_pressed = state;
}
