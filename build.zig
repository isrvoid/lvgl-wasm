const std = @import("std");
const mem = std.mem;
const heap = std.heap;
const fs = std.fs;
const zpng = @import("zpng/zpng.zig");

pub fn build(b: *std.build.Builder) !void {
    const wasm_target = std.zig.CrossTarget.parse(.{ .arch_os_abi = "wasm32-freestanding" }) catch unreachable;
    try maybeGenerateImageBitmaps();

    const gui = b.addStaticLibrary(.{
        .name = "lvgl_gui",
        .root_source_file = .{ .path = "src/lvgl_gui.c" },
        .target = wasm_target,
        .optimize = .ReleaseFast,
    });
    gui.addCSourceFile("src/libc/lvgl_libc.c", &.{});
    gui.addCSourceFile("src/lvgl_init.c", &.{});
    gui.addCSourceFile("src/example/basic_power_supply.c", &.{});
    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    const lvgl_sources = try getLvglSources(arena.allocator());
    gui.addCSourceFiles(lvgl_sources, &.{});
    gui.addIncludePath("src/libc/include");
    gui.addIncludePath("lvgl/src");
    gui.addAnonymousModule("init_image", .{ .source_file = .{ .path = "src/init_image.zig" } });
    gui.addObjectFile("images/images.zig");

    const bind = b.addSharedLibrary(.{
        .name = "webfb",
        .root_source_file = .{ .path = "src/webfb_bind.zig" },
        .target = wasm_target,
        .optimize = .ReleaseFast,
    });
    bind.linkLibrary(gui);
    bind.rdynamic = true;
    bind.strip = true;
    bind.install();
}

fn maybeGenerateImageBitmaps() !void {
    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();
    const png_names = try getPngNames(arena.allocator());
    for (png_names) |name|
        try maybeGenerateBitmap(name);
}

fn getPngNames(allocator: mem.Allocator) ![]const []const u8 {
    return getFilesWithEnding(allocator, ".png", "images");
}

fn maybeGenerateBitmap(png_path: []const u8) !void {
    var path_buf: [fs.MAX_PATH_BYTES]u8 = undefined;
    const bmp_path = replaceEnding(png_path, ".raw", &path_buf);
    const cwd = fs.cwd();
    const png_file = try cwd.openFile(png_path, .{});
    defer png_file.close();
    const png_mod_time = (try png_file.metadata()).modified();
    const should_generate = res: {
        const bmp_ = cwd.openFile(bmp_path, .{}) catch null;
        if (bmp_ == null) break :res true;
        const bmp = bmp_.?;
        defer bmp.close();
        break :res (try bmp.metadata()).modified() < png_mod_time;
    };
    if (!should_generate) return;
    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();
    const bitmap = try decodePng(arena.allocator(), png_file);
    const bmp_file = try cwd.createFile(bmp_path, .{});
    defer bmp_file.close();
    try writeBitmap(bitmap, bmp_file);
}

fn replaceEnding(src: []const u8, ending: []const u8, buf: []u8) []const u8 {
    const res = buf[0..src.len];
    mem.copy(u8, res, src);
    mem.copy(u8, res[res.len - ending.len ..], ending);
    return res;
}

fn decodePng(allocator: mem.Allocator, file: fs.File) !zpng.Image {
    var buf = std.io.bufferedReader(file.reader());
    return try zpng.Image.read(allocator, buf.reader());
}

fn writeBitmap(bmp: zpng.Image, file: fs.File) !void {
    std.debug.assert(bmp.pixels.len % bmp.width == 0);
    var buf = std.io.bufferedWriter(file.writer());
    var wr = buf.writer();
    var pix8: [4]u8 = undefined;
    for (bmp.pixels) |pix| {
        pix8[0] = @truncate(u8, pix[0] >> 8);
        pix8[1] = @truncate(u8, pix[1] >> 8);
        pix8[2] = @truncate(u8, pix[2] >> 8);
        pix8[3] = @truncate(u8, pix[3] >> 8);
        try wr.writeAll(&pix8);
    }
    try wr.writeAll(mem.asBytes(&bmp.width));
    try buf.flush();
}

fn getLvglSources(allocator: mem.Allocator) ![]const []const u8 {
    return getFilesWithEnding(allocator, ".c", "lvgl/src");
}

fn getFilesWithEnding(allocator: mem.Allocator, ending: []const u8, sub_path: []const u8) ![]const []const u8 {
    var res = std.ArrayList([]const u8).initCapacity(allocator, 0x100) catch unreachable;
    var dir = try fs.cwd().openIterableDir(sub_path, .{});
    defer dir.close();
    var walker = try dir.walk(allocator);
    defer walker.deinit();
    while (try walker.next()) |e| {
        if (!mem.endsWith(u8, e.basename, ending)) continue;
        const path_parts = [3][]const u8{ sub_path, "/", e.path };
        (res.addOne() catch unreachable).* = mem.concat(allocator, u8, &path_parts) catch unreachable;
    }
    return res.toOwnedSlice() catch unreachable;
}
