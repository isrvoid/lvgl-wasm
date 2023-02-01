const std = @import("std");
const mem = std.mem;

fn getLvglSources(allocator: std.mem.Allocator) ![]const []const u8 {
    var res = allocator.alloc([]const u8, 200) catch unreachable;
    const dir = try std.fs.cwd().openIterableDir("lvgl/src", .{});
    var walker = try dir.walk(allocator);
    defer walker.deinit();
    var src_i: usize = 0;
    while (try walker.next()) |e| {
        if (mem.endsWith(u8, e.basename, ".c")) {
            const sep_path = [2][]const u8{ "lvgl/src/", e.path };
            res[src_i] = std.mem.concat(allocator, u8, &sep_path) catch unreachable;
            src_i += 1;
        }
    }
    return res[0..src_i];
}

pub fn build(b: *std.build.Builder) !void {
    const wasm_target = std.zig.CrossTarget.parse(.{ .arch_os_abi = "wasm32-freestanding" }) catch unreachable;

    const gui = b.addStaticLibrary(.{
        .name = "lvgl_gui",
        .root_source_file = .{ .path = "src/lvgl_gui.c" },
        .target = wasm_target,
        .optimize = .ReleaseFast,
    });
    gui.addCSourceFile("src/libc/lvgl_libc.c", &[0][]u8{});
    gui.addCSourceFile("src/lvgl_init.c", &[0][]u8{});
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const lvgl_sources = try getLvglSources(arena.allocator());
    gui.addCSourceFiles(lvgl_sources, &[0][]u8{});
    gui.addIncludePath("src/libc/include");
    gui.addIncludePath("lvgl/src");

    const bind = b.addSharedLibrary(.{
        .name = "webfb",
        .root_source_file = .{ .path = "src/webfb_bind.zig" },
        .target = wasm_target,
        .optimize = .ReleaseFast,
    });
    bind.linkLibrary(gui);
    bind.rdynamic = true;
    bind.strip = true;
    const wasm_page_size = 1 << 16;
    bind.global_base = 8 * wasm_page_size;
    bind.install();
}
