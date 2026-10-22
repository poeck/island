// Persistent virtual pointer for the disposable compositor test. No uinput or host devices.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wayland-client.h>
#include "pointer-protocol.h"
static struct wl_seat *seat;
static struct zwlr_virtual_pointer_manager_v1 *manager;
static void global(void *data, struct wl_registry *r, uint32_t name, const char *type, uint32_t version) {
    (void)data; (void)version;
    if (!strcmp(type, "wl_seat")) seat=wl_registry_bind(r,name,&wl_seat_interface,1);
    if (!strcmp(type,"zwlr_virtual_pointer_manager_v1")) manager=wl_registry_bind(r,name,&zwlr_virtual_pointer_manager_v1_interface,1);
}
static void removed(void *data,struct wl_registry *r,uint32_t name) {(void)data;(void)r;(void)name;}
int main(void) {
    struct wl_display *display=wl_display_connect(NULL);
    if (!display) return 1;
    struct wl_registry *registry=wl_display_get_registry(display);
    const struct wl_registry_listener listener={global,removed};
    wl_registry_add_listener(registry,&listener,NULL);wl_display_roundtrip(display);
    if (!seat || !manager) return 2;
    struct zwlr_virtual_pointer_v1 *pointer=zwlr_virtual_pointer_manager_v1_create_virtual_pointer(manager,seat);
    wl_display_roundtrip(display);puts("ready");fflush(stdout);
    char line[128]; unsigned a,b,timestamp=1; int delta;
    while (fgets(line,sizeof(line),stdin)) {
        if (sscanf(line,"move %u %u",&a,&b)==2) zwlr_virtual_pointer_v1_motion_absolute(pointer,timestamp++,a,b,1920,1080);
        else if (sscanf(line,"button %u",&a)==1) zwlr_virtual_pointer_v1_button(pointer,timestamp++,272,a);
        else if (sscanf(line,"right %u",&a)==1) zwlr_virtual_pointer_v1_button(pointer,timestamp++,273,a);
        else if (sscanf(line,"middle %u",&a)==1) zwlr_virtual_pointer_v1_button(pointer,timestamp++,274,a);
        else if (sscanf(line,"axis %d",&delta)==1) zwlr_virtual_pointer_v1_axis(pointer,timestamp++,WL_POINTER_AXIS_VERTICAL_SCROLL,wl_fixed_from_int(delta));
        zwlr_virtual_pointer_v1_frame(pointer);wl_display_roundtrip(display);puts("ok");fflush(stdout);
    }
    zwlr_virtual_pointer_v1_destroy(pointer);wl_display_disconnect(display);return 0;
}
