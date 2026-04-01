#include "flutter_window.h"

#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  ::ShowWindow(flutter_controller_->view()->GetNativeWindow(), SW_HIDE);

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    show_startup_splash_ = false;
    ::ShowWindow(flutter_controller_->view()->GetNativeWindow(), SW_SHOWNORMAL);
    InvalidateRect(GetHandle(), nullptr, TRUE);
  });

  this->Show();

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_ERASEBKGND:
      return show_startup_splash_ ? 1 : DefWindowProc(window_handle_, message,
                                                      wparam, lparam);

    case WM_PAINT:
      if (show_startup_splash_) {
        PAINTSTRUCT ps;
        HDC dc = BeginPaint(hwnd, &ps);
        DrawStartupSplash(dc, ps.rcPaint);
        EndPaint(hwnd, &ps);
        return 0;
      }
      break;

    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::DrawStartupSplash(HDC dc, RECT bounds) {
  const int width = bounds.right - bounds.left;
  const int height = bounds.bottom - bounds.top;

  const COLORREF blue = RGB(34, 80, 244);
  const COLORREF orange = RGB(255, 138, 29);
  const COLORREF white = RGB(255, 255, 255);

  RECT full_rect = bounds;
  HBRUSH blue_brush = CreateSolidBrush(blue);
  FillRect(dc, &full_rect, blue_brush);

  RECT orange_rect = bounds;
  orange_rect.left = bounds.left + (width / 2);
  HBRUSH orange_brush = CreateSolidBrush(orange);
  FillRect(dc, &orange_rect, orange_brush);

  HBRUSH bottom_tint_brush = CreateSolidBrush(RGB(210, 164, 188));
  HGDIOBJ previous_bottom_brush = SelectObject(dc, bottom_tint_brush);
  HPEN transparent_pen = CreatePen(PS_NULL, 0, RGB(0, 0, 0));
  HGDIOBJ previous_pen_for_tint = SelectObject(dc, transparent_pen);
  Ellipse(dc, bounds.left + (width / 2) - 130, bounds.bottom - 210,
          bounds.left + (width / 2) + 130, bounds.bottom - 30);
  SelectObject(dc, previous_pen_for_tint);
  SelectObject(dc, previous_bottom_brush);

  SetBkMode(dc, TRANSPARENT);
  SetTextColor(dc, RGB(0, 0, 0));

  const int title_font_size = max(34, min(54, width / 12));
  HFONT title_font = CreateFontW(
      -MulDiv(title_font_size, GetDeviceCaps(dc, LOGPIXELSY), 72), 0, 0, 0,
      FW_HEAVY, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_OUTLINE_PRECIS,
      CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY, VARIABLE_PITCH, L"Segoe UI");
  HFONT previous_font = static_cast<HFONT>(SelectObject(dc, title_font));
  RECT title_shadow_rect = {bounds.left, bounds.top + max(42, height / 12) + 8,
                            bounds.right, bounds.top + max(120, height / 5) + 8};
  DrawTextW(dc, L"iliprestō", -1, &title_shadow_rect,
            DT_CENTER | DT_TOP | DT_SINGLELINE);
  SetTextColor(dc, white);
  RECT title_rect = {bounds.left, bounds.top + max(42, height / 12),
                     bounds.right, bounds.top + max(120, height / 5)};
  DrawTextW(dc, L"iliprestō", -1, &title_rect,
            DT_CENTER | DT_TOP | DT_SINGLELINE);

  const int logo_size = min(max(150, width / 4), 240);
  const int logo_left = bounds.left + (width - logo_size) / 2;
  const int logo_top = bounds.top + max(160, height / 3 - logo_size / 6);
  const int logo_right = logo_left + logo_size;
  const int logo_bottom = logo_top + logo_size;
  const int corner_radius = 28;

    HBRUSH shadow_brush = CreateSolidBrush(RGB(47, 54, 84));
    HGDIOBJ previous_shadow_brush = SelectObject(dc, shadow_brush);
    SelectObject(dc, transparent_pen);
    Ellipse(dc, logo_left + static_cast<int>(logo_size * 0.22),
      logo_bottom - static_cast<int>(logo_size * 0.02),
      logo_right - static_cast<int>(logo_size * 0.22),
      logo_bottom + static_cast<int>(logo_size * 0.16));
    SelectObject(dc, previous_shadow_brush);

    HPEN glow_pen = CreatePen(PS_SOLID, 1, RGB(255, 255, 255));
    HGDIOBJ previous_glow_pen = SelectObject(dc, glow_pen);
    HBRUSH glow_brush = CreateSolidBrush(RGB(235, 241, 255));
    HGDIOBJ previous_glow_brush = SelectObject(dc, glow_brush);
    RoundRect(dc, logo_left - 8, logo_top - 8, logo_right + 8, logo_bottom + 8,
        corner_radius + 8, corner_radius + 8);
    SelectObject(dc, previous_glow_pen);
    SelectObject(dc, previous_glow_brush);

  HRGN clip_region = CreateRoundRectRgn(logo_left, logo_top, logo_right,
                                        logo_bottom, corner_radius, corner_radius);
  SelectClipRgn(dc, clip_region);

  RECT logo_left_rect = {logo_left, logo_top, logo_left + logo_size / 2,
                         logo_bottom};
  FillRect(dc, &logo_left_rect, blue_brush);
  RECT logo_right_rect = {logo_left + logo_size / 2, logo_top, logo_right,
                          logo_bottom};
  FillRect(dc, &logo_right_rect, orange_brush);

  SelectClipRgn(dc, nullptr);

  HPEN border_pen = CreatePen(PS_SOLID, 3, white);
  HPEN divider_pen = CreatePen(PS_SOLID, 6, white);
  HGDIOBJ previous_pen = SelectObject(dc, border_pen);
  HGDIOBJ previous_brush = SelectObject(dc, GetStockObject(HOLLOW_BRUSH));
  RoundRect(dc, logo_left, logo_top, logo_right, logo_bottom, corner_radius,
            corner_radius);

  SelectObject(dc, divider_pen);
  MoveToEx(dc, logo_left + logo_size / 2, logo_top + 10, nullptr);
  LineTo(dc, logo_left + logo_size / 2, logo_bottom - 10);

  HFONT logo_font = CreateFontW(
      -MulDiv(max(74, logo_size / 2), GetDeviceCaps(dc, LOGPIXELSY), 72), 0,
      0, 0, FW_HEAVY, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
      OUT_OUTLINE_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
      VARIABLE_PITCH, L"Segoe UI");
  SelectObject(dc, logo_font);
  RECT left_i_rect = {logo_left + 12, logo_top + 22, logo_left + logo_size / 2 - 12,
                      logo_bottom - 10};
  RECT right_i_rect = {logo_left + logo_size / 2 + 12, logo_top + 22,
                       logo_right - 12, logo_bottom - 10};
  DrawTextW(dc, L"i", -1, &left_i_rect,
            DT_CENTER | DT_VCENTER | DT_SINGLELINE);
  DrawTextW(dc, L"i", -1, &right_i_rect,
            DT_CENTER | DT_VCENTER | DT_SINGLELINE);

    HPEN smile_shadow_pen = CreatePen(PS_SOLID, max(6, logo_size / 18), RGB(70, 70, 70));
    HGDIOBJ previous_smile_pen = SelectObject(dc, smile_shadow_pen);
    Arc(dc, logo_left + static_cast<int>(logo_size * 0.29),
      logo_top + static_cast<int>(logo_size * 0.56) + 4,
      logo_left + static_cast<int>(logo_size * 0.72),
      logo_top + static_cast<int>(logo_size * 0.92) + 4,
      logo_left + static_cast<int>(logo_size * 0.38),
      logo_top + static_cast<int>(logo_size * 0.77) + 4,
      logo_left + static_cast<int>(logo_size * 0.64),
      logo_top + static_cast<int>(logo_size * 0.77) + 4);

    HPEN smile_pen = CreatePen(PS_SOLID, max(5, logo_size / 20), white);
    SelectObject(dc, smile_pen);
    Arc(dc, logo_left + static_cast<int>(logo_size * 0.29),
      logo_top + static_cast<int>(logo_size * 0.56),
      logo_left + static_cast<int>(logo_size * 0.72),
      logo_top + static_cast<int>(logo_size * 0.92),
      logo_left + static_cast<int>(logo_size * 0.38),
      logo_top + static_cast<int>(logo_size * 0.77),
      logo_left + static_cast<int>(logo_size * 0.64),
      logo_top + static_cast<int>(logo_size * 0.77));

  SelectObject(dc, previous_brush);
  SelectObject(dc, previous_pen);
  SelectObject(dc, previous_font);

    DeleteObject(smile_pen);
    SelectObject(dc, previous_smile_pen);
    DeleteObject(smile_shadow_pen);
    DeleteObject(glow_brush);
    DeleteObject(glow_pen);
    DeleteObject(shadow_brush);
    DeleteObject(transparent_pen);
    DeleteObject(bottom_tint_brush);
  DeleteObject(logo_font);
  DeleteObject(divider_pen);
  DeleteObject(border_pen);
  DeleteObject(clip_region);
  DeleteObject(title_font);
  DeleteObject(orange_brush);
  DeleteObject(blue_brush);
}
