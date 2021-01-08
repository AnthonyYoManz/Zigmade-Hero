const std = @import("std");
usingnamespace std.os.windows;
usingnamespace std.os.windows.user32;

pub extern "user32" fn BeginPaint(hWnd: HWND, lpPaint: LPPAINTSTRUCT) callconv(.Stdcall) HDC;
pub extern "user32" fn EndPaint(hWnd: HWND, lpPaint: LPPAINTSTRUCT) callconv(.Stdcall) BOOL;
pub extern "user32" fn GetClientRect(hWnd: HWND, lpRect: LPRECT) callconv(.Stdcall) BOOL;

pub const RECT = extern struct {
    left: LONG,
    top: LONG,
    right: LONG,
    bottom: LONG,
};

pub const PAINTSTRUCT = extern struct {
    hdc: HDC,
    fErase: BOOL,
    rcPaint: RECT,
    fRestore: BOOL,
    fIncUpdate: BOOL,
    rgbReserved: [32]BYTE,
};

pub const LPPAINTSTRUCT = *PAINTSTRUCT;
pub const LPRECT = *RECT;

pub const WM_ACTIVATEAPP = 0x001c;
pub const WS_VISIBLE = 0x10000000;
pub const WS_OVERLAPPEDWINDOW = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
pub const CW_USEDEFAULT = std.math.minInt(INT);
