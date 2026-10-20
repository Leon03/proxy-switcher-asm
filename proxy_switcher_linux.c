/*
 * Proxy Switcher — Linux/XFCE 版本
 * GTK3 系统托盘 + xfconf 代理切换
 * 编译: gcc -O2 -o proxy_switcher_linux proxy_switcher_linux.c $(pkg-config --cflags --libs gtk+-3.0)
 */

#include <gtk/gtk.h>
#include <stdlib.h>
#include <string.h>

#define DEFAULT_PROXY_HOST "127.0.0.1"
#define DEFAULT_PROXY_PORT "7890"

static GtkStatusIcon *tray_icon = NULL;
static GtkWidget *menu = NULL;

// ── 调用 xfconf-query 设置代理 ──
static void xfconf_set(const char *property, const char *value)
{
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "xfconf-query -c xsettings -p %s -s %s 2>/dev/null", property, value);
    system(cmd);
}

static void xfconf_set_int(const char *property, int value)
{
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "xfconf-query -c xsettings -p %s -s %d -t int 2>/dev/null", property, value);
    system(cmd);
}

// ── 设置/关闭代理 ──
static void set_proxy(int enabled)
{
    if (enabled) {
        xfconf_set("/Net/ProxyMode", "manual");
        xfconf_set("/Net/ProxyHTTP", DEFAULT_PROXY_HOST);
        xfconf_set_int("/Net/ProxyHTTPPort", atoi(DEFAULT_PROXY_PORT));
        xfconf_set("/Net/ProxyHTTPS", DEFAULT_PROXY_HOST);
        xfconf_set_int("/Net/ProxyHTTPSPort", atoi(DEFAULT_PROXY_PORT));
    } else {
        xfconf_set("/Net/ProxyMode", "none");
    }
}

// ── 查询当前代理状态 ──
static int get_proxy_enabled(void)
{
    char buf[256];
    FILE *fp = popen("xfconf-query -c xsettings -p /Net/ProxyMode 2>/dev/null", "r");
    if (!fp) return 0;
    if (fgets(buf, sizeof(buf), fp)) {
        buf[strcspn(buf, "\n")] = 0;
        pclose(fp);
        return (strcmp(buf, "manual") == 0 || strcmp(buf, "auto") == 0);
    }
    pclose(fp);
    return 0;
}

// ── 菜单回调 ──
static void on_proxy_on(GtkMenuItem *item, gpointer data)
{
    set_proxy(1);
}

static void on_proxy_off(GtkMenuItem *item, gpointer data)
{
    set_proxy(0);
}

static void on_proxy_toggle(GtkMenuItem *item, gpointer data)
{
    set_proxy(!get_proxy_enabled());
}

static void on_open_settings(GtkMenuItem *item, gpointer data)
{
    system("xfce4-settings-editor &");
}

static void on_quit(GtkMenuItem *item, gpointer data)
{
    gtk_main_quit();
}

// ── 托盘右键菜单 ──
static void on_popup(GtkStatusIcon *icon, guint button, guint time, gpointer data)
{
    gtk_widget_show_all(menu);
    gtk_menu_popup(GTK_MENU(menu), NULL, NULL, NULL, NULL, button, time);
}

// ── 双击托盘切换代理 ──
static void on_activate(GtkStatusIcon *icon, gpointer data)
{
    set_proxy(!get_proxy_enabled());
}

// ── 构建菜单 ──
static GtkWidget *build_menu(void)
{
    GtkWidget *menu = gtk_menu_new();

    GtkWidget *item_on = gtk_menu_item_new_with_label("代理开启");
    GtkWidget *item_off = gtk_menu_item_new_with_label("代理关闭");
    GtkWidget *item_toggle = gtk_menu_item_new_with_label("切换代理");
    GtkWidget *sep1 = gtk_separator_menu_item_new();
    GtkWidget *item_settings = gtk_menu_item_new_with_label("打开设置编辑器");
    GtkWidget *sep2 = gtk_separator_menu_item_new();
    GtkWidget *item_quit = gtk_menu_item_new_with_label("退出");

    g_signal_connect(item_on, "activate", G_CALLBACK(on_proxy_on), NULL);
    g_signal_connect(item_off, "activate", G_CALLBACK(on_proxy_off), NULL);
    g_signal_connect(item_toggle, "activate", G_CALLBACK(on_proxy_toggle), NULL);
    g_signal_connect(item_settings, "activate", G_CALLBACK(on_open_settings), NULL);
    g_signal_connect(item_quit, "activate", G_CALLBACK(on_quit), NULL);

    gtk_menu_shell_append(GTK_MENU_SHELL(menu), item_on);
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), item_off);
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), item_toggle);
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), sep1);
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), item_settings);
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), sep2);
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), item_quit);

    return menu;
}

int main(int argc, char *argv[])
{
    gtk_init(&argc, &argv);

    // 创建托盘图标
    tray_icon = gtk_status_icon_new_from_icon_name("network-transmit-receive");
    gtk_status_icon_set_tooltip_text(tray_icon, "Proxy Switcher");
    gtk_status_icon_set_visible(tray_icon, TRUE);

    // 构建菜单
    menu = build_menu();

    // 信号
    g_signal_connect(tray_icon, "popup-menu", G_CALLBACK(on_popup), NULL);
    g_signal_connect(tray_icon, "activate", G_CALLBACK(on_activate), NULL);

    gtk_main();
    return 0;
}