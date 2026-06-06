const fs = std.fs;
const std = @import("std");
const print = std.debug.print;

pub fn main() !void {
    const file = try fs.cwd().openFile("in.txt", .{});
    defer file.close();

    var file_buffer: [4096]u8 = undefined;
    var reader = file.reader(&file_buffer);
    var cnt: usize = 50;
    var res: usize = 0;
    while (try reader.interface.takeDelimiter('\n')) |line| {
        const first = line[0];
        const rest = line[1..];
        const num = try std.fmt.parseInt(usize, rest, 10);
        const numMod = num % 100;
        if (first == 'R') {
            cnt = (cnt + numMod) % 100;
            if (cnt == 0) {
                res += 1;
            }
        } else {
            if (numMod > cnt) {
                cnt = 100 - (numMod - cnt);
            } else {
                cnt -= numMod;
                if (cnt == 0) {
                    res += 1;
                }
            }
        }
    }
    print("{d}\n", .{res});
}
