const std = @import("std");
const jemalloc = @import("jemalloc");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const MAX: usize = 1_000_000_000 / 4;

const Bench = struct {
    name: []const u8,
    time: f64,
    runs: usize,

    fn run(loop_count: usize, name: []const u8, allocator: Allocator, io: std.Io) !Bench {
        var lst = ArrayList(usize).empty;
        defer lst.deinit(allocator);

        const start = std.Io.Timestamp.now(io, .awake).toNanoseconds();
        var s: usize = 0;
        for (0..loop_count) |i| {
            try lst.append(allocator, i);
            s += lst.items[lst.items.len - 1];
        }
        const end = std.Io.Timestamp.now(io, .awake).toNanoseconds();

        const diff = @as(f64, @floatFromInt(end - start));

        return .{
            .name = name,
            .time = diff,
            .runs = s,
        };
    }
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var benches = [_]Bench{
        try .run(MAX, "SMP", std.heap.smp_allocator, io),
        try .run(MAX, "jemalloc", jemalloc.allocator, io),
        try .run(MAX, "Page", std.heap.page_allocator, io),
        try blk: {
            var arena = std.heap.ArenaAllocator.init(std.heap.smp_allocator);
            defer arena.deinit();
            break :blk Bench.run(MAX, "SMP arena", arena.allocator(), io);
        },
        try blk: {
            var arena = std.heap.ArenaAllocator.init(jemalloc.allocator);
            defer arena.deinit();
            break :blk Bench.run(MAX, "Je arena", arena.allocator(), io);
        },
        try blk: {
            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();
            break :blk Bench.run(MAX, "Page arena", arena.allocator(), io);
        },
    };

    std.mem.sort(Bench, &benches, {}, benchCmp);

    for (benches) |bench| {
        std.debug.print("{s} {}\n--------------\ncost: {d}ms\n-------------\n", .{
            bench.name,
            bench.runs,
            bench.time / @as(f64, @floatFromInt(MAX * std.time.ns_per_ms)),
        });
    }
}

fn benchCmp(_: void, a: Bench, b: Bench) bool {
    return a.time < b.time;
}
