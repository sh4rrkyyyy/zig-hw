const std = @import("std");

pub const MyAllocator = struct {
    allocator: std.mem.Allocator = std.heap.page_allocator,
    free_blocks: ?*Block = null,
    allocated_chunks: std.ArrayList([]u8) = .empty,
    pub fn get_allocator(self: *MyAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{
            .alloc = alloc,
            .resize = resize,
            .remap = remap,
            .free = free,
        } };
    }
    const Block = struct {
        next: ?*Block,
        sz: usize,
    };
    fn init(allocator: std.mem.Allocator) MyAllocator {
        return .{ .allocator = allocator };
    }
    fn deinit(self: *MyAllocator) void {
        for (self.allocated_chunks.items) |chunk| {
            self.allocator.free(chunk);
        }
        self.allocated_chunks.deinit(self.allocator);
    }
    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, _: usize) ?[*]u8 {
        const self: *MyAllocator = @ptrCast(@alignCast(ctx));
        var cur = self.free_blocks;
        const block_info_sz = std.mem.alignForward(usize, @sizeOf(Block), alignment.toByteUnits());
        const total_sz = std.mem.alignForward(usize, len + block_info_sz, @alignOf(Block));
        var prev: ?*Block = null;
        while (cur) |node| {
            if (node.sz >= total_sz) {
                if (prev) |p| {
                    p.next = node.next;
                } else {
                    self.free_blocks = node.next;
                }
                if (node.sz - total_sz >= @sizeOf(Block)) {
                    const new_ptr = @as([*]u8, @ptrCast(node)) + total_sz;
                    const new_block: *Block = @ptrCast(@alignCast(new_ptr));
                    new_block.sz = node.sz - total_sz;
                    new_block.next = self.free_blocks;
                    self.free_blocks = new_block;
                    node.sz = total_sz;
                }
                const res = @as([*]u8, @ptrCast(node)) + block_info_sz;
                std.debug.print("New block has address {*}, block info started at {*}\n", .{ res, res - block_info_sz });
                return res;
            }
            prev = cur;
            cur = node.next;
        }
        const chunk = self.allocator.alloc(u8, 4096 * 4) catch return null;
        self.allocated_chunks.append(self.allocator, chunk) catch return null;
        std.debug.print("Page allocator returns new block with address {*}\n", .{chunk.ptr});
        const new_block: *Block = @ptrCast(@alignCast(chunk.ptr));
        new_block.next = self.free_blocks;
        new_block.sz = chunk.len;
        self.free_blocks = new_block;
        return alloc(ctx, len, alignment, 0);
    }
    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, _: usize) void {
        const self: *MyAllocator = @ptrCast(@alignCast(ctx));
        const block_info_sz = std.mem.alignForward(usize, @sizeOf(Block), alignment.toByteUnits());
        const total_sz = std.mem.alignForward(usize, memory.len + block_info_sz, @alignOf(Block));
        const block: *Block = @ptrCast(@alignCast(memory.ptr - block_info_sz));
        block.sz = total_sz;
        block.next = self.free_blocks;
        self.free_blocks = block;
        std.debug.print("Block started at .{*} was freed\n", .{memory.ptr});
    }
    fn resize(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
        return false;
    }
    fn remap(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
        return null;
    }
};
pub fn main(_: std.process.Init) !void {
    var alloc = MyAllocator.init(std.heap.page_allocator);
    defer alloc.deinit();
    const allocator = alloc.get_allocator();
    const mem = try allocator.alloc(u8, 4096 * 3);
    const mem1 = try allocator.alloc(u8, 4096);
    const mem2 = try allocator.alloc(u8, 4096 * 4 - 16);
    defer allocator.free(mem2);
    defer allocator.free(mem1);
    defer allocator.free(mem);
}
