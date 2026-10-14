const std = @import("std");
const Allocator = std.mem.Allocator;

const c = @import("jemalloc");

/// An allocator based on [jemalloc](https://jemalloc.net/jemalloc.3.html)
pub const allocator = std.mem.Allocator{
    // `ptr` not used
    .ptr = undefined,
    .vtable = &.{
        .alloc = alloc,
        .resize = resize,
        .free = free,
        .remap = remap,
    },
};

/// Collect stats info into writer.
/// When opts contains `J`, stats is in JSON format.
pub fn collectMallocStats(wtr: anytype, opts: ?[:0]const u8) void {
    const context = @constCast(&wtr);
    c.je_malloc_stats_print(struct {
        fn cb(ctx: ?*anyopaque, msg: [*c]const u8) callconv(.c) void {
            const p: *@TypeOf(wtr) = @ptrCast(@alignCast(ctx));
            p.writeAll(std.mem.span(msg)) catch |e| {
                std.log.err("call malloc_stats_print cb failed, err:{any}", .{e});
            };
        }
    }.cb, context, if (opts) |v| v else null);
}

fn alloc(_: *anyopaque, n: usize, align_: std.mem.Alignment, return_address: usize) ?[*]u8 {
    _ = return_address;

    const alignment = align_.toByteUnits();
    const ptr = c.je_mallocx(n, c.MALLOCX_ALIGN(alignment)) orelse return null;
    return @ptrCast(ptr);
}

fn resize(
    _: *anyopaque,
    buf_unaligned: []u8,
    align_: std.mem.Alignment,
    new_size: usize,
    return_address: usize,
) bool {
    _ = align_;
    _ = return_address;
    return c.je_malloc_usable_size(buf_unaligned.ptr) >= new_size;
}

fn free(_: *anyopaque, slice: []u8, align_: std.mem.Alignment, return_address: usize) void {
    _ = return_address;
    c.je_dallocx(slice.ptr, c.MALLOCX_ALIGN(align_.toByteUnits()));
}

fn remap(
    _: *anyopaque,
    slice: []u8,
    align_: std.mem.Alignment,
    new_size: usize,
    return_address: usize,
) ?[*]u8 {
    _ = return_address;
    const ptr = c.je_rallocx(slice.ptr, new_size, c.MALLOCX_ALIGN(align_.toByteUnits()));
    return @ptrCast(ptr);
}

test "basic alloc" {
    const ptr = try allocator.create(struct { a: i8, b: u64 });
    ptr.* = .{ .a = 12, .b = 32 };
    try std.testing.expect(ptr.a == 12);
    allocator.destroy(ptr);

    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(allocator);
    const alloc_wtr = std.Io.Writer.Allocating.fromArrayList(allocator, &buf);
    const wtr = alloc_wtr.writer;

    collectMallocStats(wtr, "J");

    const Stats = struct {
        jemalloc: struct {
            version: []const u8,
            config: struct {
                debug: bool,
                malloc_conf: []const u8,
            },
            opt: struct {
                abort: bool,
                abort_conf: bool,
            },
        },
    };
    const parsed = try std.json.parseFromSlice(Stats, allocator, buf.items, .{
        .ignore_unknown_fields = true,
    });

    try std.testing.expectEqualDeep(parsed.value, Stats{
        .jemalloc = .{
            .version = "5.3.0",
            .config = .{
                .debug = true,
                .malloc_conf = "",
            },
            .opt = .{
                .abort = true,
                .abort_conf = true,
            },
        },
    });
}

test "alloc ArrayList" {
    var lst = std.ArrayList(usize).empty;
    defer lst.deinit(allocator);

    for (0..100_000) |i| {
        try lst.append(allocator, i);
    }
}

test "realloc" {
    const size = 5;
    const ptr: [*]u8 = @ptrCast(c.je_realloc(null, size).?);
    std.mem.copyForwards(u8, ptr[0..size], "hello");
    try std.testing.expectEqualStrings("hello", ptr[0..size]);

    // in-place realloc
    const usable_size = c.je_malloc_usable_size(ptr);
    const ptr2: [*]u8 = @ptrCast(c.je_realloc(ptr, usable_size).?);
    try std.testing.expectEqual(ptr2, ptr);

    // out-of-place realloc
    const ptr3: [*]u8 = @ptrCast(c.je_realloc(ptr2, usable_size + 1).?);
    try std.testing.expectEqualStrings("hello", ptr3[0..size]);
    try std.testing.expect(ptr3 != ptr2);
}
