const std = @import("std");
const my_alloc = @import("my_allocator.zig");
const fmt = std.fmt;
const fs = std.fs;
const print = std.debug.print;

const Binop = enum { PLUS, MINUS };
const Unop = enum { SQRT };

const Context = struct { x: f32 };

const Node = struct {
    ptr: *const anyopaque,
    vtable: *const VTable,
    const VTable = struct {
        eval: *const fn (ptr: *const anyopaque, ctx: *const Context) f32,
    };
    pub fn eval(self: Node, ctx: *const Context) f32 {
        return self.vtable.eval(self.ptr, ctx);
    }
};

const UnopNode = struct {
    child: Node,
    op: Unop,

    const vtable = Node.VTable{ .eval = eval };

    fn eval(ptr: *const anyopaque, ctx: *const Context) f32 {
        const self: *const UnopNode = @ptrCast(@alignCast(ptr));
        const res = self.child.eval(ctx);
        switch (self.op) {
            Unop.SQRT => {
                return @sqrt(res);
            },
        }
    }
};

const BinopNode = struct {
    left: Node,
    right: Node,
    op: Binop,

    const vtable = Node.VTable{ .eval = eval };

    fn eval(ptr: *const anyopaque, ctx: *const Context) f32 {
        const self: *const BinopNode = @ptrCast(@alignCast(ptr));
        const res_left = self.left.eval(ctx);
        const res_right = self.right.eval(ctx);
        switch (self.op) {
            Binop.MINUS => {
                return res_left - res_right;
            },
            Binop.PLUS => {
                return res_left + res_right;
            },
        }
    }
};

const NumberNode = struct {
    value: f32,

    const vtable = Node.VTable{ .eval = eval };

    fn eval(ptr: *const anyopaque, _: *const Context) f32 {
        const self: *const NumberNode = @ptrCast(@alignCast(ptr));
        return self.value;
    }
};

const ContextNode = struct {
    const vtable = Node.VTable{ .eval = eval };

    fn eval(_: *const anyopaque, ctx: *const Context) f32 {
        return ctx.x;
    }
};

pub fn build(it: anytype, alloc: std.mem.Allocator) !Node {
    const tok = it.next() orelse return error.UnexpectedEnd;
    if (std.mem.eql(u8, tok, "sqrt")) {
        const child = try build(it, alloc);
        const node = try alloc.create(UnopNode);
        node.* = UnopNode{ .child = child, .op = Unop.SQRT };
        return Node{ .ptr = node, .vtable = &UnopNode.vtable };
    }
    if (std.mem.eql(u8, tok, "+")) {
        const left = try build(it, alloc);
        const right = try build(it, alloc);
        const node = try alloc.create(BinopNode);
        node.* = BinopNode{ .left = left, .right = right, .op = Binop.PLUS };
        return Node{ .ptr = node, .vtable = &BinopNode.vtable };
    }
    if (std.mem.eql(u8, tok, "-")) {
        const left = try build(it, alloc);
        const right = try build(it, alloc);
        const node = try alloc.create(BinopNode);
        node.* = BinopNode{ .left = left, .right = right, .op = Binop.MINUS };
        return Node{ .ptr = node, .vtable = &BinopNode.vtable };
    }
    if (std.mem.eql(u8, tok, "x")) {
        const node = try alloc.create(ContextNode);
        node.* = ContextNode{};
        return Node{ .ptr = node, .vtable = &ContextNode.vtable };
    }

    const val = try fmt.parseFloat(f32, tok);
    const node = try alloc.create(NumberNode);
    node.* = NumberNode{ .value = val };
    return Node{ .ptr = node, .vtable = &NumberNode.vtable };
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    const file = try std.Io.Dir.cwd().openFile(io, "in.txt", .{});
    defer file.close(io);

    var file_bufer: [4096]u8 = undefined;
    var reader = file.reader(io, &file_bufer);

    const line = (try reader.interface.takeDelimiter('\n')).?;

    var it = std.mem.tokenizeAny(u8, line, " \t\r\n");

    var alloc = my_alloc.MyAllocator.init(std.heap.page_allocator);
    defer alloc.deinit();
    const allocator = alloc.get_allocator();

    const root = try build(&it, allocator);

    const args = try init.minimal.args.toSlice(allocator);
    const x_str = if (args.len > 1) args[1] else "0";
    const x = try fmt.parseFloat(f32, x_str);
    const ctx = Context{ .x = x };
    const res = root.eval(&ctx);
    print("{d}\n", .{res});
}
