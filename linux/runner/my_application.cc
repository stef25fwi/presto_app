#include "my_application.h"

#include <cmath>

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

namespace {

constexpr double kBlueRed = 34.0 / 255.0;
constexpr double kBlueGreen = 80.0 / 255.0;
constexpr double kBlueBlue = 244.0 / 255.0;
constexpr double kOrangeRed = 1.0;
constexpr double kOrangeGreen = 138.0 / 255.0;
constexpr double kOrangeBlue = 29.0 / 255.0;

void draw_center_glow(cairo_t* cr, double width, double height) {
  cairo_pattern_t* pattern = cairo_pattern_create_linear(width / 2.0, 0,
                                                         width / 2.0, height);
  cairo_pattern_add_color_stop_rgba(pattern, 0.0, 1, 1, 1, 0.0);
  cairo_pattern_add_color_stop_rgba(pattern, 0.22, 1, 1, 1, 0.08);
  cairo_pattern_add_color_stop_rgba(pattern, 0.48, 1, 1, 1, 0.14);
  cairo_pattern_add_color_stop_rgba(pattern, 0.72, 1, 1, 1, 0.06);
  cairo_pattern_add_color_stop_rgba(pattern, 1.0, 1, 1, 1, 0.0);
  cairo_rectangle(cr, width * 0.39, 0, width * 0.22, height);
  cairo_set_source(cr, pattern);
  cairo_fill(cr);
  cairo_pattern_destroy(pattern);
}

void draw_bottom_tint(cairo_t* cr, double width, double height) {
  cairo_pattern_t* pattern = cairo_pattern_create_radial(
      width / 2.0, height * 0.9, 0, width / 2.0, height * 0.9,
      std::max(140.0, width * 0.18));
  cairo_pattern_add_color_stop_rgba(pattern, 0.0, 210.0 / 255.0,
                                    164.0 / 255.0, 188.0 / 255.0, 0.52);
  cairo_pattern_add_color_stop_rgba(pattern, 0.52, 210.0 / 255.0,
                                    164.0 / 255.0, 188.0 / 255.0, 0.14);
  cairo_pattern_add_color_stop_rgba(pattern, 1.0, 210.0 / 255.0,
                                    164.0 / 255.0, 188.0 / 255.0, 0.0);
  cairo_arc(cr, width / 2.0, height * 0.9, std::max(140.0, width * 0.18), 0,
            2 * G_PI);
  cairo_set_source(cr, pattern);
  cairo_fill(cr);
  cairo_pattern_destroy(pattern);
}

void draw_rounded_rect(cairo_t* cr,
                       double x,
                       double y,
                       double width,
                       double height,
                       double radius) {
  const double degrees = G_PI / 180.0;
  cairo_new_sub_path(cr);
  cairo_arc(cr, x + width - radius, y + radius, radius, -90 * degrees,
            0 * degrees);
  cairo_arc(cr, x + width - radius, y + height - radius, radius,
            0 * degrees, 90 * degrees);
  cairo_arc(cr, x + radius, y + height - radius, radius, 90 * degrees,
            180 * degrees);
  cairo_arc(cr, x + radius, y + radius, radius, 180 * degrees,
            270 * degrees);
  cairo_close_path(cr);
}

gboolean splash_draw_cb(GtkWidget* widget, cairo_t* cr, gpointer) {
  const double width = gtk_widget_get_allocated_width(widget);
  const double height = gtk_widget_get_allocated_height(widget);
  const double mid_x = width / 2.0;

  cairo_set_source_rgb(cr, kBlueRed, kBlueGreen, kBlueBlue);
  cairo_rectangle(cr, 0, 0, mid_x, height);
  cairo_fill(cr);

  cairo_set_source_rgb(cr, kOrangeRed, kOrangeGreen, kOrangeBlue);
  cairo_rectangle(cr, mid_x, 0, width - mid_x, height);
  cairo_fill(cr);

  draw_center_glow(cr, width, height);
  draw_bottom_tint(cr, width, height);

  cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL,
                         CAIRO_FONT_WEIGHT_BOLD);
  cairo_set_font_size(cr, std::min(width * 0.085, 54.0));
  cairo_set_source_rgba(cr, 0, 0, 0, 0.16);

  cairo_text_extents_t title_extents;
  const char* title = "iliprest\305\215";
  cairo_text_extents(cr, title, &title_extents);
  cairo_move_to(cr, (width - title_extents.width) / 2.0 - title_extents.x_bearing,
                std::max(78.0, height * 0.14) + 8.0);
  cairo_show_text(cr, title);

  cairo_set_source_rgb(cr, 1, 1, 1);
  cairo_move_to(cr, (width - title_extents.width) / 2.0 - title_extents.x_bearing,
                std::max(78.0, height * 0.14));
  cairo_show_text(cr, title);

  const double logo_size = std::min(width * 0.34, 220.0);
  const double logo_x = (width - logo_size) / 2.0;
  const double logo_y = std::max(height * 0.31, 180.0);
  const double radius = 28.0;

  cairo_pattern_t* shadow_pattern = cairo_pattern_create_radial(
      width / 2.0, logo_y + logo_size + 10.0, 0, width / 2.0,
      logo_y + logo_size + 10.0, logo_size * 0.36);
  cairo_pattern_add_color_stop_rgba(shadow_pattern, 0.0, 47.0 / 255.0,
                                    54.0 / 255.0, 84.0 / 255.0, 0.40);
  cairo_pattern_add_color_stop_rgba(shadow_pattern, 1.0, 47.0 / 255.0,
                                    54.0 / 255.0, 84.0 / 255.0, 0.0);
  cairo_arc(cr, width / 2.0, logo_y + logo_size + 10.0, logo_size * 0.36, 0,
            2 * G_PI);
  cairo_set_source(cr, shadow_pattern);
  cairo_fill(cr);
  cairo_pattern_destroy(shadow_pattern);

  cairo_set_source_rgba(cr, 1, 1, 1, 0.14);
  draw_rounded_rect(cr, logo_x - 8.0, logo_y - 8.0, logo_size + 16.0,
                    logo_size + 16.0, radius + 8.0);
  cairo_fill(cr);

  cairo_save(cr);
  draw_rounded_rect(cr, logo_x, logo_y, logo_size, logo_size, radius);
  cairo_clip(cr);

  cairo_set_source_rgb(cr, kBlueRed, kBlueGreen, kBlueBlue);
  cairo_rectangle(cr, logo_x, logo_y, logo_size / 2.0, logo_size);
  cairo_fill(cr);

  cairo_set_source_rgb(cr, kOrangeRed, kOrangeGreen, kOrangeBlue);
  cairo_rectangle(cr, logo_x + logo_size / 2.0, logo_y, logo_size / 2.0,
                  logo_size);
  cairo_fill(cr);
  cairo_restore(cr);

  cairo_set_source_rgba(cr, 1, 1, 1, 0.96);
  cairo_set_line_width(cr, 3.0);
  draw_rounded_rect(cr, logo_x, logo_y, logo_size, logo_size, radius);
  cairo_stroke(cr);

  cairo_set_source_rgba(cr, 1, 1, 1, 0.98);
  cairo_rectangle(cr, logo_x + (logo_size / 2.0) - 3.0, logo_y + 10.0, 6.0,
                  logo_size - 20.0);
  cairo_fill(cr);

  cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL,
                         CAIRO_FONT_WEIGHT_BOLD);
  cairo_set_font_size(cr, logo_size * 0.62);

  cairo_text_extents_t i_extents;
  cairo_text_extents(cr, "i", &i_extents);
  const double baseline_y = logo_y + logo_size * 0.69;
  const double left_center_x = logo_x + logo_size * 0.25;
  const double right_center_x = logo_x + logo_size * 0.75;

  cairo_move_to(cr,
                left_center_x - (i_extents.width / 2.0) - i_extents.x_bearing,
                baseline_y);
  cairo_show_text(cr, "i");
  cairo_move_to(
      cr,
      right_center_x - (i_extents.width / 2.0) - i_extents.x_bearing,
      baseline_y);
  cairo_show_text(cr, "i");

  cairo_set_source_rgba(cr, 0, 0, 0, 0.14);
  cairo_set_line_width(cr, logo_size * 0.06);
  cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND);
  cairo_move_to(cr, logo_x + logo_size * 0.38, logo_y + logo_size * 0.76 + 4.0);
  cairo_curve_to(cr, logo_x + logo_size * 0.46, logo_y + logo_size * 0.84 + 4.0,
                 logo_x + logo_size * 0.56, logo_y + logo_size * 0.84 + 4.0,
                 logo_x + logo_size * 0.64, logo_y + logo_size * 0.77 + 4.0);
  cairo_stroke(cr);

  cairo_set_source_rgba(cr, 1, 1, 1, 0.96);
  cairo_set_line_width(cr, logo_size * 0.055);
  cairo_move_to(cr, logo_x + logo_size * 0.38, logo_y + logo_size * 0.76);
  cairo_curve_to(cr, logo_x + logo_size * 0.46, logo_y + logo_size * 0.84,
                 logo_x + logo_size * 0.56, logo_y + logo_size * 0.84,
                 logo_x + logo_size * 0.64, logo_y + logo_size * 0.77);
  cairo_stroke(cr);

  return FALSE;
}

GtkWidget* create_startup_splash() {
  GtkWidget* splash = gtk_drawing_area_new();
  gtk_widget_set_hexpand(splash, TRUE);
  gtk_widget_set_vexpand(splash, TRUE);
  g_signal_connect(splash, "draw", G_CALLBACK(splash_draw_cb), nullptr);
  return splash;
}

}  // namespace

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  GtkWidget* splash =
      GTK_WIDGET(g_object_get_data(G_OBJECT(view), "startup-splash"));
  if (splash != nullptr) {
    gtk_widget_hide(splash);
  }
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "presto_app");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "presto_app");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GtkWidget* overlay = gtk_overlay_new();
  GtkWidget* splash = create_startup_splash();
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#00000000");
  fl_view_set_background_color(view, &background_color);
  gtk_container_add(GTK_CONTAINER(overlay), GTK_WIDGET(view));
  gtk_overlay_add_overlay(GTK_OVERLAY(overlay), splash);
  gtk_widget_set_halign(splash, GTK_ALIGN_FILL);
  gtk_widget_set_valign(splash, GTK_ALIGN_FILL);
  gtk_container_add(GTK_CONTAINER(window), overlay);
  g_object_set_data(G_OBJECT(view), "startup-splash", splash);

  // Remove the native startup splash once Flutter draws its first frame.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_show_all(GTK_WIDGET(window));
  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
