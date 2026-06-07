const std = @import("std");

fn State(comptime sz: usize) type {
    return struct { visited: [sz]u2 = .{0} ** sz, ordered: [sz]usize = undefined, len: usize = 0 };
}

fn get_idx(comptime Nodes: []const type, comptime T: type) usize {
    inline for (Nodes, 0..) |n, i| {
        if (n == T) {
            return i;
        }
    }
    @compileError("No such type in nodes");
}

fn get_deps(comptime T: type) type {
    return @typeInfo(T).@"struct".fields[0].type;
}

fn dfs(comptime Nodes: []const type, comptime s: State(Nodes.len), comptime i: usize) State(Nodes.len) {
    if (s.visited[i] == 2) {
        return s;
    }
    if (s.visited[i] == 1) {
        @compileError("Cycle was found");
    }
    var t = s;
    t.visited[i] = 1;
    inline for (@typeInfo(get_deps(Nodes[i])).@"struct".fields) |f| {
        t = dfs(Nodes, t, get_idx(Nodes, @typeInfo(f.type).pointer.child));
    }
    t.visited[i] = 2;
    t.ordered[t.len] = i;
    t.len += 1;
    return t;
}

fn get_sorted(comptime Nodes: []const type) [Nodes.len]usize {
    const sz = Nodes.len;
    var s = State(sz){};
    inline for (0..sz) |i| {
        s = dfs(Nodes, s, i);
    }
    return s.ordered;
}

pub fn GraphEvaluator(comptime Nodes: []const type) type {
    const sorted = get_sorted(Nodes);

    return struct {
        const Self = @This();
        nodes: std.meta.Tuple(Nodes),

        pub fn init() Self {
            var self: Self = undefined;
            inline for (Nodes, 0..) |n, i| {
                inline for (@typeInfo(get_deps(n)).@"struct".fields) |f| {
                    @field(self.nodes[i].deps, f.name) = self.get(f.type);
                }
            }
            return self;
        }

        pub fn compute(self: *Self) void {
            inline for (sorted) |i| {
                self.nodes[i].compute();
            }
        }

        pub fn get(self: *Self, comptime NodePtr: type) NodePtr {
            return &self.nodes[comptime get_idx(Nodes, @typeInfo(NodePtr).pointer.child)];
        }
    };
}

const A = struct {
    deps: struct {},
    fn compute(_: *@This()) void {
        std.debug.print("A\n", .{});
    }
};
const B = struct {
    deps: struct {},
    fn compute(_: *@This()) void {
        std.debug.print("B\n", .{});
    }
};
const C = struct {
    deps: struct { a: *A, b: *B },
    fn compute(_: *@This()) void {
        std.debug.print("C\n", .{});
    }
};
const D = struct {
    deps: struct { b: *B },
    fn compute(_: *@This()) void {
        std.debug.print("D\n", .{});
    }
};
const E = struct {
    deps: struct { c: *C, d: *D },
    fn compute(_: *@This()) void {
        std.debug.print("E\n", .{});
    }
};

pub fn main(_: std.process.Init) !void {
    var ev = GraphEvaluator(&.{ A, B, C, D, E }).init();
    ev.compute();
    const d = ev.get(*D);
    _ = d;
}
