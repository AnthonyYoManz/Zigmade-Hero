const std = @import("std");
const k32 = std.os.windows.kernel32;
usingnamespace std.os.windows;
usingnamespace std.os.windows.user32;

const g = @import("graphics.zig");
usingnamespace @import("common.zig");
usingnamespace @import("win32_extension.zig");

const initial_resolution = Size.init(960, 540);
var running = false;
var offscreen_buf = g.Bitmap.withSize(initial_resolution);

fn win32WndProc(wnd: HWND, msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.Stdcall) LRESULT {
    var result: LRESULT = null;

    switch (msg) {
        WM_PAINT => {
            var paint: PAINTSTRUCT = undefined;
            const dc = BeginPaint(wnd, &paint);

            const x = paint.rcPaint.left;
            const y = paint.rcPaint.top;
            const dst_size = Size{
                .w = paint.rcPaint.right - paint.rcPaint.left,
                .h = paint.rcPaint.bottom - paint.rcPaint.top,
            };

            _ = PatBlt(dc, x, y, dst_size.w, dst_size.h, BLACKNESS);
            g.win32PresentBufferToWindow(&offscreen_buf, dc, dst_size);

            _ = EndPaint(wnd, &paint);
        },
        WM_SIZE => {
            var client_rect: RECT = undefined;
            _ = GetClientRect(wnd, &client_rect);

            const dst_size = Size{
                .w = client_rect.right - client_rect.left,
                .h = client_rect.bottom - client_rect.top,
            };

            g.win32ResizeBmp(&offscreen_buf, dst_size);
        },
        WM_DESTROY => {
            running = false;
        },
        WM_CLOSE => {
            running = false;
        },
        WM_QUIT => {
            running = false;
        },
        WM_ACTIVATEAPP => {},
        else => {
            result = DefWindowProcA(wnd, msg, wParam, lParam);
        },
    }

    return result;
}

fn win32ErrorExit() void {
    const err = k32.GetLastError();
    var buf16: [256]u16 = undefined;
    var buf8: [256]u8 = undefined;

    const len = k32.FormatMessageW(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, null, err, (1 << 10) | 0, &buf16, buf16.len / @sizeOf(TCHAR), null);
    _ = std.unicode.utf16leToUtf8(&buf8, buf16[0..len]) catch unreachable;

    std.debug.warn("\t{}\n", .{buf8[0..len]});
    k32.ExitProcess(@bitCast(u16, err));
}

pub fn wWinMain(instance: HINSTANCE, prevInstance: ?HINSTANCE, param: LPWSTR, cmdShow: INT) INT {
    const wnd_class_info = WNDCLASSEXA{
        .cbSize = @sizeOf(WNDCLASSEXA),
        .style = CS_OWNDC | CS_HREDRAW | CS_VREDRAW,
        .lpfnWndProc = win32WndProc,
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
        win32ErrorExit();
    }

    const wnd = CreateWindowExA(
        0,
        "Zigmade Hero",
        "Zigmade Hero",
        WS_OVERLAPPEDWINDOW | WS_VISIBLE,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        initial_resolution.w,
        initial_resolution.h,
        null,
        null,
        instance,
        null,
    ) orelse {
        std.debug.warn("Failed to create window\n", .{});
        win32ErrorExit();
        unreachable;
    };

    running = true;
    var tick: usize = 0;
    while (running) {
        var msg: MSG = undefined;
        while (PeekMessageA(&msg, wnd, 0, 0, PM_REMOVE)) {
            _ = TranslateMessage(&msg);
            _ = DispatchMessageA(&msg);
        }

        // Update bitmap
        g.renderWeirdGradient(&offscreen_buf, tick);
        tick +%= 1;

        // Render bitmap to screen
        if (GetDC(wnd)) |dc| {
            var client_rect: RECT = undefined;
            _ = GetClientRect(wnd, &client_rect);

            const dst_size = Size{
                .w = client_rect.right - client_rect.left,
                .h = client_rect.bottom - client_rect.top,
            };

            g.win32PresentBufferToWindow(&offscreen_buf, dc, dst_size);
            _ = ReleaseDC(wnd, dc);
        }
    }

    return 0;
}
