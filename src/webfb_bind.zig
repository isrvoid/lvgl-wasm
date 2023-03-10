const std = @import("std");
const page_size = std.mem.page_size;
const gui = @cImport({ @cInclude("lvgl_gui.h"); });

const frame_width = 800;
const frame_height = 480;

export fn initTempPage() void {
    temp_page = std.heap.page_allocator.create([page_size]u8) catch @panic("alloc failed");
}

export fn tempPageAdr() u32 {
    return @ptrToInt(temp_page);
}
var temp_page: *[page_size]u8 = undefined;

export fn init() void {
    initMemory();
    gui.init_lvgl(@ptrCast(*void, frame_buf.ptr), frame_width, frame_height);
    gui.create_lvgl_gui();
}

export fn initMemory() void {
    const pa = std.heap.page_allocator;
    send_buf = pa.create([page_size]u8) catch @panic("alloc failed");
    recv_buf = pa.create([page_size]u8) catch @panic("alloc failed");
    frame_buf = pa.alloc(u32, frame_width * frame_height) catch @panic("alloc failed");
}
var frame_buf: []u32 = undefined;
var recv_buf: *[page_size]u8 = undefined;
var send_buf: *[page_size]u8 = undefined;

export fn writeBufferAdrLen() i32 {
    const p = @ptrCast(*[6]u32, @alignCast(4, temp_page));
    p[0] = @ptrToInt(frame_buf.ptr);
    p[1] = frame_width * frame_height * 4;
    p[2] = @ptrToInt(recv_buf);
    p[3] = recv_buf.len;
    p[4] = @ptrToInt(send_buf);
    p[5] = send_buf.len;
    return p.len;
}

export fn frameWidth() u32 {
    return frame_width;
}

export fn frameHeight() u32 {
    return frame_height;
}

export fn update(monotime_ms: u32) void {
    gui.lv_tick_inc(monotime_ms -% prev_monotime);
    prev_monotime = monotime_ms;
    _ = gui.lv_timer_handler();
}
var prev_monotime: u32 = 0;

export fn popShouldRender() bool {
    const change_index = gui.lvgl_change_index();
    defer prev_change_index = change_index;
    return change_index != prev_change_index;
}
var prev_change_index: u32 = 0;

export fn setConnected(_: bool) void {}
export fn pushReceived(_: u32) void {}

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

comptime {
    @export(assert_fail, .{ .name = "__assert_fail", .visibility = .hidden });
    @export(stack_check_fail, .{ .name = "__stack_chk_fail", .visibility = .hidden });
}

fn assert_fail(expr: [*:0]const u8, file: [*:0]const u8, line: i32, func: [*:0]const u8) callconv(.C) void {
    const msg = std.fmt.bufPrint(temp_page, "{s}:{}: {s}: Assertion '{s}' failed.", .{file, line, func, expr}) catch unreachable;
    js_assert_fail(msg.len);
}

extern fn js_assert_fail(u32) void;

fn stack_check_fail() callconv(.C) void {
    @panic("stack check failed");
}
