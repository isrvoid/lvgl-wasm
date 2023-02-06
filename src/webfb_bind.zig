const std = @import("std");
const mem = std.mem;
const gui = @cImport({@cInclude("lvgl_gui.h");});

extern fn js_log_int(i32) void;
extern fn js_assert_fail(u32, u32, u32, u32, i32, u32, u32) void;

export fn init() void {
    initMemory();
    gui.init_lvgl(@ptrCast(*void, frame_buf.ptr), image_width, image_height);
    gui.create_lvgl_gui();
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

fn assert_fail(expr: [*:0]const u8, file: [*:0]const u8, line: i32, func: [*:0]const u8) callconv(.C) void {
    const expr_adr = @ptrToInt(debug_page);
    const expr_len = mem.indexOfSentinel(u8, 0, expr);
    const file_adr = expr_adr + expr_len;
    const file_len = mem.indexOfSentinel(u8, 0, file);
    const func_adr = file_adr + file_len;
    const func_len = mem.indexOfSentinel(u8, 0, func);
    mem.copy(u8, @intToPtr([*]u8, expr_adr)[0..expr_len], expr[0..expr_len]);
    mem.copy(u8, @intToPtr([*]u8, file_adr)[0..file_len], file[0..file_len]);
    mem.copy(u8, @intToPtr([*]u8, func_adr)[0..func_len], func[0..func_len]);
    js_assert_fail(expr_adr, expr_len, file_adr, file_len, line, func_adr, func_len);
}

fn stack_check_fail() callconv(.C) void {
    @panic("stack check failed");
}

comptime {
    @export(assert_fail, .{ .name = "__assert_fail", .visibility = .hidden });
    @export(stack_check_fail, .{ .name = "__stack_chk_fail", .visibility = .hidden });
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
    gui.lv_tick_inc(monotime_ms -% prev_monotime);
    prev_monotime = monotime_ms;
    _ = gui.lv_timer_handler();
}

var prev_frame_count: u32 = 0;
export fn popShouldDraw() bool {
    const frame_count = gui.lvgl_frame_count();
    defer prev_frame_count = frame_count;
    return frame_count != prev_frame_count;
}

export fn setInputPosition(x: i32, y: i32) void {
    gui.input_device_data.x = x;
    gui.input_device_data.y = y;
}

export fn setInputPressed(state: bool) void {
    gui.input_device_data.is_pressed = state;
}

export fn setWheelDelta(val: i32) void {
    // convert potentially large pixel value to encoder increment
    // invert y: scrolling the wheel forward should increase a value
    const inc = @as(i32, @boolToInt(val < 0)) - @as(i32, @boolToInt(val > 0));
    gui.input_device_data.encoder_pos +%= inc;
}

export fn setWheelPressed(state: bool) void {
    gui.input_device_data.is_encoder_pressed = state;
}
