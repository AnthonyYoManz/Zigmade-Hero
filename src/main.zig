const std = @import("std");
usingnamespace std.os.windows;
usingnamespace std.os.windows.user32;
const k32 = std.os.windows.kernel32;

// TODO: GetMessageA shouldn't return bool, it should return BOOL

// TODO: Add these to std.os.windows.user32
const WM_ACTIVATEAPP = 0x001c;
const WS_VISIBLE = 0x10000000;
const WS_OVERLAPPEDWINDOW = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
const CW_USEDEFAULT = -2147483648;

const RECT = extern struct {
    left: LONG,
    top: LONG,
    right: LONG,
    bottom: LONG,
};

const PAINTSTRUCT = extern struct {
    hdc: HDC,
    fErase: BOOL,
    rcPaint: RECT,
    fRestore: BOOL,
    fIncUpdate: BOOL,
    rgbReserved: [32]BYTE,
};

extern "user32" fn BeginPaint(wnd: HWND, paint: *PAINTSTRUCT) callconv(.Stdcall) HDC;
extern "user32" fn EndPaint(wnd: HWND, paint: *PAINTSTRUCT) callconv(.Stdcall) BOOL;

// TODO: Add these to std.os.windows.gdi32
extern "gdi32" fn PatBlt(dc: HDC, x: c_int, y: c_int, w: c_int, h: c_int, rop: DWORD) callconv(.Stdcall) BOOL;
const PATCOPY = 0x00F00021;
const PATINVERT = 0x005A0049;
const DSTINVERT = 0x00550009;
const BLACKNESS = 0x00000042;
const WHITENESS = 0x00FF0062;

// Actual code from now on :)
var running = true;

fn wnd_proc(wnd: HWND, msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.Stdcall) LRESULT {
    var result: LRESULT = null;

    switch (msg) {
        WM_PAINT => {
            std.debug.warn("WM_PAINT\n", .{});
            var paint: PAINTSTRUCT = undefined;
            const dc = BeginPaint(wnd, &paint);

            const pad = 32;
            const left = paint.rcPaint.left;
            const top = paint.rcPaint.top;
            const width = paint.rcPaint.right - left;
            const height = paint.rcPaint.bottom - top;
            _ = PatBlt(dc, left, top, width, height, BLACKNESS);

            _ = EndPaint(wnd, &paint);
        },
        WM_SIZE => {
            std.debug.warn("WM_SIZE\n", .{});
        },
        WM_DESTROY => {
            std.debug.warn("WM_DESTROY\n", .{});
            running = false;
        },
        WM_CLOSE => {
            std.debug.warn("WM_CLOSE\n", .{});
            running = false;
        },
        WM_ACTIVATEAPP => {
            std.debug.warn("WM_ACTIVATEAPP\n", .{});
        },
        else => {
            result = DefWindowProcA(wnd, msg, wParam, lParam);
        },
    }

    return result;
}

fn win_error_exit() void {
    const err = k32.GetLastError();
    var buf16: [256]u16 = undefined;
    var buf8: [256]u8 = undefined;

    const len = k32.FormatMessageW(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, null, err, (1 << 10) | 0, &buf16, buf16.len / @sizeOf(TCHAR), null);
    _ = std.unicode.utf16leToUtf8(&buf8, buf16[0..len]) catch unreachable;

    std.debug.warn("\t{}\n", .{buf8[0..len]});
    k32.ExitProcess(@bitCast(u16, err));
}

pub fn WinMain(instance: HINSTANCE, prevInstance: ?HINSTANCE, param: LPSTR, cmdShow: INT) INT {
    const wnd_class_info = WNDCLASSEXA{
        .cbSize = @sizeOf(WNDCLASSEXA),
        .style = CS_OWNDC | CS_HREDRAW | CS_VREDRAW,
        .lpfnWndProc = wnd_proc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = instance,
        .hIcon = null,
        .hCursor = null,
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = "Zigmade Hero",
        .hIconSm = null,
    };

    const wnd_class = RegisterClassExA(&wnd_class_info);
    if (wnd_class == 0) {
        std.debug.warn("Failed to register window class\n", .{});
        win_error_exit();
    }

    const wnd = CreateWindowExA(
        0,
        "Zigmade Hero",
        "Zigmade Hero",
        WS_OVERLAPPEDWINDOW | WS_VISIBLE,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        960,
        540,
        null,
        null,
        instance,
        null,
    );

    if (wnd == null) {
        std.debug.warn("Failed to create window\n", .{});
        win_error_exit();
    }

    while (running) {
        var msg: MSG = undefined;
        const msgResult = GetMessageA(&msg, wnd, 0, 0);
        if (msgResult > 0) {
            _ = TranslateMessage(&msg);
            _ = DispatchMessageA(&msg);
        } else {
            break;
        }
    }

    return 0;
}
