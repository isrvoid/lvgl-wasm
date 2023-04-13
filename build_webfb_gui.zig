const std = @import("std");
const fs = std.fs;
const heap = std.heap;
const mem = std.mem;
const Build = std.Build;
const zpng = @import("zpng/zpng.zig");

const repo_dir = "lvgl-wasm/"; // relative to project's build.zig

const GuiBuildOptions = struct {
    name: []const u8 = "webfb",
    src_dir: []const u8 = "src",
    img_dir: ?[]const u8 = null,
};

pub fn addWebfbGui(b: *Build, opt: GuiBuildOptions) *Build.CompileStep {
    const wasm = wasmBinary(b, opt.name);
    addLvgl(wasm);
    addGui(wasm, opt.src_dir);
    if (opt.img_dir) |dir|
        addImages(b, wasm, dir);

    return wasm;
}

pub fn wasmBinary(b: *Build, name: []const u8) *Build.CompileStep {
    const res = b.addSharedLibrary(.{
        .name = name,
        .root_source_file = .{ .path = repo_dir ++ "src/webfb_bind.zig" },
        .target = wasm_target,
        .optimize = .ReleaseFast,
    });
    res.rdynamic = true;
    res.strip = true;
    return res;
}

pub fn addLvgl(a: *Build.CompileStep) void {
    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();
    const lvgl_src_dir = repo_dir ++ "lvgl/src";
    const lvgl_src = getFilesWithEnding(arena.allocator(), ".c", lvgl_src_dir) catch @panic("LVGL src");
    a.addCSourceFiles(lvgl_src, &.{});
    a.addIncludePath(lvgl_src_dir);
    a.linkLibC();
    a.addCSourceFile(repo_dir ++ "src/lvgl_libc.c", &.{});
    a.addCSourceFile(repo_dir ++ "src/lvgl_webfb.c", &.{});
}

pub fn addGui(a: *Build.CompileStep, src_dir: []const u8) void {
    // TODO search and add project's gui sources
    var buf: [fs.MAX_PATH_BYTES]u8 = undefined;
    const gui_src = concatPath(src_dir, "lvgl_gui.c", &buf);
    a.addCSourceFile(gui_src, &.{});
    a.addIncludePath(repo_dir ++ "src");
    // lv_conf.h is expected at the top of gui source directory
    const lv_conf_path = res: {
        var rel_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const rel_path = concatPath(src_dir, "lv_conf.h", &rel_buf);
        break :res fs.cwd().realpath(rel_path, &buf) catch @panic("lv_conf.h path");
    };
    a.defineCMacro("LV_CONF_PATH", lv_conf_path);
}

pub fn addImages(b: *Build, cs: *Build.CompileStep, dir: []const u8) void {
    maybeGenerateImageBitmaps(dir) catch @panic("bitmap");
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const o = b.addObject(.{
        .name = "images",
        .root_source_file = .{ .path = concatPath(dir, "images.zig", &buf) },
        .target = wasm_target,
        .optimize = .ReleaseFast,
    });
    o.addAnonymousModule("init_image", .{ .source_file = .{ .path = repo_dir ++ "src/init_image.zig" } });
    cs.addObject(o);
}

const wasm_target = res: {
    @setEvalBranchQuota(2100);
    break :res std.zig.CrossTarget.parse(.{ .arch_os_abi = "wasm32-freestanding" }) catch unreachable;
};

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

fn maybeGenerateImageBitmaps(dir: []const u8) !void {
    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();
    const png_names = try getPngNames(arena.allocator(), dir);
    for (png_names) |name|
        try maybeGenerateBitmap(name);
}

fn getPngNames(allocator: mem.Allocator, dir: []const u8) ![]const []const u8 {
    return getFilesWithEnding(allocator, ".png", dir);
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

fn concatPath(a: []const u8, b: []const u8, buf: *[fs.MAX_PATH_BYTES]u8) []const u8 {
    mem.copy(u8, buf, a);
    buf[a.len] = '/';
    mem.copy(u8, buf[a.len + 1 ..], b);
    return buf[0 .. a.len + 1 + b.len];
}
