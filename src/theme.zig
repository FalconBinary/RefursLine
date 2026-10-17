// Copyright (c) 2026 Denys (FalconBinary)
// SPDX-License-Identifier: GPL-3.0-or-later

//! Тема: две вкомпилированные палитры (config.zig) и то, что сообщает RefursWM — тёмная или
//! светлая, и цвет активной рамки окна (акцент). Никаких файлов и inotify: бар узнаёт о смене
//! темы событием протокола, меню получают её аргументом при запуске (`d89b4faff` / `l1e66f5ff`).

const std = @import("std");
const cfg = @import("config.zig");

pub var t: cfg.Theme = cfg.dark;
pub var dark = true;
/// 0xAARRGGBB, 0 — не задан
pub var accent: u32 = 0;

pub fn set(is_dark: bool, wm_accent: u32) void {
    dark = is_dark;
    accent = wm_accent;
    t = if (is_dark) cfg.dark else cfg.light;
    if (cfg.follow_wm_accent and wm_accent >> 24 != 0) {
        t.ws_active = wm_accent;
        t.bt_connected = wm_accent;
        t.menu_accent = wm_accent;
    }
}

/// 0xRRGGBBAA (протокол) → 0xAARRGGBB (отрисовка).
pub fn fromRgba(v: u32) u32 {
    return (v >> 8) | (v << 24);
}

/// Аргумент для меню: 'd' или 'l' и акцент 8 hex-цифрами (RRGGBBAA).
pub fn encode(buf: *[10]u8) [:0]const u8 {
    buf[0] = if (dark) 'd' else 'l';
    const v = (accent << 8) | (accent >> 24);
    const digits = "0123456789abcdef";
    for (0..8) |i| buf[1 + i] = digits[(v >> @intCast(28 - 4 * i)) & 0xf];
    buf[9] = 0;
    return buf[0..9 :0];
}

/// Разбор аргумента меню; что угодно другое — тёмная тема без акцента.
pub fn decode(arg: ?[]const u8) void {
    const a = arg orelse return set(true, 0);
    if (a.len != 9 or (a[0] != 'd' and a[0] != 'l')) return set(true, 0);
    const v = std.fmt.parseInt(u32, a[1..], 16) catch return set(a[0] == 'd', 0);
    set(a[0] == 'd', fromRgba(v));
}

/// Цвет фона непрозрачен: компоновщику не нужно рисовать то, что под ним.
pub fn solid(c: u32) bool {
    return c >> 24 == 0xff;
}

test "тема для меню: туда и обратно" {
    set(false, 0xff1e66f5);
    var b: [10]u8 = undefined;
    const s = encode(&b);
    try std.testing.expectEqualStrings("l1e66f5ff", s);
    set(true, 0);
    decode(s);
    try std.testing.expect(!dark);
    try std.testing.expectEqual(@as(u32, 0xff1e66f5), accent);
    decode("d../../x");
    try std.testing.expect(dark);
    try std.testing.expectEqual(@as(u32, 0), accent);
}
