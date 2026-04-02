const std = @import("std");
const jemalloc = @import("jemalloc");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const MAX: usize = 1_000_000_000 / 4;

fn run(loop_count: usize, name: []const u8, allocator: Allocator, io: std.Io) !void {
    var lst = ArrayList(usize).empty;
    defer lst.deinit(allocator);

    const start = std.Io.Timestamp.now(io, .awake).toNanoseconds();
    var s: usize = 0;
    for (0..loop_count) |i| {
        try lst.append(allocator, i);
        s += lst.items[lst.items.len - 1];
    }
    const end = std.Io.Timestamp.now(io, .awake).toNanoseconds();

    std.debug.print("{s} {}, cost: {d}ms\n", .{
        name,
        s,
        @as(f64, @floatFromInt(end - start)) / @as(f64, @floatFromInt(MAX * std.time.ns_per_ms)),
    });
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    try run(MAX, "heap", std.heap.page_allocator, io);
    try run(MAX, "jemalloc", jemalloc.allocator, io);
    try run(MAX, "GPA", init.gpa, io);
}
