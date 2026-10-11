#include "rich_clipboard.h"

#include <cstring>
#include <string>

namespace {

struct ClipboardPayload {
  std::string plain;
  std::string html;
};

void provide_data(GtkClipboard*, GtkSelectionData* selection, guint info,
                  gpointer user_data) {
  const auto* payload = static_cast<ClipboardPayload*>(user_data);
  if (info == 1) {
    gtk_selection_data_set(selection, gtk_selection_data_get_target(selection),
                           8, reinterpret_cast<const guchar*>(payload->html.data()),
                           static_cast<gint>(payload->html.size()));
  } else {
    gtk_selection_data_set_text(selection, payload->plain.data(),
                                static_cast<gint>(payload->plain.size()));
  }
}

void clear_data(GtkClipboard*, gpointer user_data) {
  delete static_cast<ClipboardPayload*>(user_data);
}

bool set_rich_text(const gchar* plain, const gchar* html) {
  auto* clipboard = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
  if (clipboard == nullptr) return false;
  auto* payload = new ClipboardPayload{plain, html};
  // GTK copies the target descriptors; payload is owned until clear_data.
  auto* targets = gtk_target_list_new(nullptr, 0);
  gtk_target_list_add_text_targets(targets, 0);
  gtk_target_list_add(targets, gdk_atom_intern_static_string("text/html"), 0, 1);
  gint count = 0;
  auto* entries = gtk_target_table_new_from_list(targets, &count);
  const bool accepted = gtk_clipboard_set_with_data(
      clipboard, entries, count, provide_data, clear_data, payload);
  if (accepted) {
    // Permit a desktop clipboard manager to preserve both formats on exit.
    gtk_clipboard_set_can_store(clipboard, entries, count);
  } else {
    delete payload;
  }
  gtk_target_table_free(entries, count);
  gtk_target_list_unref(targets);
  return accepted;
}

void handle_method(FlMethodChannel*, FlMethodCall* call, gpointer) {
  if (std::strcmp(fl_method_call_get_name(call), "setRichText") != 0) {
    fl_method_call_respond_not_implemented(call, nullptr);
    return;
  } else {
    auto* args = fl_method_call_get_args(call);
    auto* plain = args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP
                      ? fl_value_lookup_string(args, "plainText") : nullptr;
    auto* html = args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP
                     ? fl_value_lookup_string(args, "html") : nullptr;
    if (plain == nullptr || html == nullptr ||
        fl_value_get_type(plain) != FL_VALUE_TYPE_STRING ||
        fl_value_get_type(html) != FL_VALUE_TYPE_STRING) {
      fl_method_call_respond_error(
          call, "invalid_arguments", "Expected clipboard text and HTML.",
          nullptr, nullptr);
      return;
    } else {
      g_autoptr(FlValue) accepted = fl_value_new_bool(set_rich_text(
          fl_value_get_string(plain), fl_value_get_string(html)));
      fl_method_call_respond_success(call, accepted, nullptr);
      return;
    }
  }
}

}  // namespace

void orbit_rich_clipboard_register(FlView* view) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "orbit_note/clipboard", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, handle_method, nullptr,
                                            nullptr);
  g_object_set_data_full(G_OBJECT(view), "orbit-note-rich-clipboard",
                         g_object_ref(channel), g_object_unref);
}
