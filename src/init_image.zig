const std = @import("std");

const LvglImage = extern struct {
    header: Header,
    len: u32,
    data: [*]const u8,

    const Header = packed struct {
        cf: i5 = 5, // LV_IMG_CF_TRUE_COLOR_ALPHA
        zero: i3 = 0,
        reserved: i2 = 0,
        w: i11,
        h: i11,
    };
};

pub fn init(comptime raw: [:0]const u8) LvglImage {
    std.debug.assert(raw.len % 4 == 0 and raw.len >= 8);
    const num_pixels = raw.len / 4 - 1;
    const width = std.mem.bytesAsValue(u32, raw[raw.len - 4 ..]).*;
    std.debug.assert(width > 0 and num_pixels % width == 0);
    const height = num_pixels / width;
    return LvglImage{ .header = .{ .w = width, .h = height }, .len = raw.len - 4, .data = raw.ptr };
}
