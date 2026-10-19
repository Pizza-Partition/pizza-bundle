#include <stdio.h>
#include <string.h>
#include <wpe/webkit.h>
#include <wpe/wpe-platform.h>

static GMainLoop *loop;
static gboolean passed;
static gboolean message(WebKitUserContentManager *manager, JSCValue *value,
                        WebKitScriptMessageReply *reply, gpointer data) {
  (void)manager;
  (void)data;
  char *text = jsc_value_to_string(value);
  if (!strcmp(text, "ping:42")) {
    JSCValue *answer =
        jsc_value_new_string(jsc_value_get_context(value), "pong:42");
    webkit_script_message_reply_return_value(reply, answer);
    g_object_unref(answer);
  } else if (!strcmp(text, "PASS")) {
    passed = TRUE;
    g_main_loop_quit(loop);
  } else {
    fprintf(stderr, "Unexpected JavaScript result: %s\n", text);
    g_main_loop_quit(loop);
  }
  g_free(text);
  return TRUE;
}
static gboolean expired(gpointer data) {
  (void)data;
  fprintf(stderr, "WPE smoke test timed out\n");
  g_main_loop_quit(loop);
  return G_SOURCE_REMOVE;
}
int main(void) {
  fprintf(stderr, "WPE: creating main loop\n");
  loop = g_main_loop_new(NULL, FALSE);
  fprintf(stderr, "WPE: creating ephemeral session\n");
  WebKitNetworkSession *session = webkit_network_session_new_ephemeral();
  fprintf(stderr, "WPE: creating view\n");
  WebKitWebView *view =
      g_object_new(WEBKIT_TYPE_WEB_VIEW, "network-session", session, NULL);
  fprintf(stderr, "WPE: registering bridge\n");
  WebKitUserContentManager *manager =
      webkit_web_view_get_user_content_manager(view);
  g_signal_connect(manager, "script-message-with-reply-received::pizza",
                   G_CALLBACK(message), NULL);
  if (!webkit_user_content_manager_register_script_message_handler_with_reply(
          manager, "pizza", NULL))
    return 2;
  WPEView *native = webkit_web_view_get_wpe_view(view);
  wpe_view_resized(native, 800, 600);
  wpe_view_set_visible(native, TRUE);
  g_timeout_add_seconds(60, expired, NULL);
  webkit_web_view_load_html(
      view,
      "<!doctype html><script>(async()=>{const "
      "p=window.webkit.messageHandlers.pizza;"
      "const r=await p.postMessage('ping:'+6*7);await "
      "p.postMessage(r==='pong:42'?'PASS':'FAIL')})()</script>",
      "file:///");
  fprintf(stderr, "WPE: running page\n");
  g_main_loop_run(loop);
  puts(passed ? "PIZZA_WPE_SMOKE_PASS" : "PIZZA_WPE_SMOKE_FAIL");
  return passed ? 0 : 1;
}
