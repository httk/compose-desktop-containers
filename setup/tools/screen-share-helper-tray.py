#!/usr/bin/env python3
#
# Screen-share-helper
#
# (c) 2024 Rickard Armiento
#

import os
import re
import signal
import dbus
from dbus.mainloop.glib import DBusGMainLoop

# Force Gtk to use X11, which is necessary for getting XID
os.environ['GDK_BACKEND'] = 'x11'

import gi
gi.require_version('Gst', '1.0')
gi.require_version('Gtk', '3.0')
gi.require_version('GstVideo', '1.0')
gi.require_version('AppIndicator3', '0.1')

from gi.repository import GLib, Gtk, GObject, Gst, GstVideo, Gdk, AppIndicator3
from Xlib import X, display, Xatom
from Xlib.ext import randr

DBusGMainLoop(set_as_default=True)
Gst.init(None)

loop = GLib.MainLoop()

bus = dbus.SessionBus()
request_iface = 'org.freedesktop.portal.Request'
screen_cast_iface = 'org.freedesktop.portal.ScreenCast'

pipeline = None
window = None
indicator = None
session = None

def create_window(width, height):
    # Create a new X11 Window using Gtk
    global window

    gdk_display = Gdk.Display.get_default()

    mon_geoms = [
        gdk_display.get_monitor(i).get_geometry() for i in range(gdk_display.get_n_monitors())
    ]

    x0 = min(r.x            for r in mon_geoms)
    y0 = min(r.y            for r in mon_geoms)
    x1 = max(r.x + r.width  for r in mon_geoms)
    y1 = max(r.y + r.height for r in mon_geoms)

    w = x1 - x0
    h = y1 - y0

    print(f'Screen Size: {w},{h}')

    window = Gtk.Window()
    window.set_default_size(width, height)
    window.set_title("Screensharing Window")
    window.connect("destroy", on_window_destroy)

    widget = Gtk.DrawingArea()
    window.add(widget)
    window.set_keep_below(True)
    window.set_skip_pager_hint(True)
    window.set_deletable(False)
    window.set_accept_focus(False)
    window.show_all()

    return widget, window


def create_tray_icon():
    global indicator

    indicator = AppIndicator3.Indicator.new(
        "screenshare-helper",
        "media-playback-start",
        AppIndicator3.IndicatorCategory.APPLICATION_STATUS
    )
    indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)
    indicator.set_menu(build_menu(start=True))


def build_menu(start=True):
    menu = Gtk.Menu()

    if start:
        start_item = Gtk.MenuItem(label="Start Screenshare")
        start_item.connect("activate", on_start_screenshare)
        menu.append(start_item)
    else:
        stop_item = Gtk.MenuItem(label="Stop Screenshare")
        stop_item.connect("activate", on_stop_screenshare)
        menu.append(stop_item)

    quit_item = Gtk.MenuItem(label="Quit")
    quit_item.connect("activate", on_quit)
    menu.append(quit_item)

    menu.show_all()
    return menu


def on_start_screenshare(source):
    global session
    if session is None:
        (session_path, session_token) = new_session_path()
        screen_cast_call(portal.CreateSession, on_create_session_response,
                         options={'session_handle_token': session_token})
    indicator.set_menu(build_menu(start=False))


def on_stop_screenshare(source):
    global pipeline, window
    if pipeline is not None:
        pipeline.set_state(Gst.State.NULL)
        pipeline = None
    if window is not None:
        window.hide()
    indicator.set_menu(build_menu(start=True))


def on_window_destroy(window):
    # When the window is destroyed, reset the tray icon to allow restarting screenshare
    global pipeline
    if pipeline is not None:
        pipeline.set_state(Gst.State.NULL)
        pipeline = None
    indicator.set_menu(build_menu(start=True))


def on_quit(source):
    terminate()


def terminate():
    if pipeline is not None:
        pipeline.set_state(Gst.State.NULL)
    loop.quit()


request_token_counter = 0
session_token_counter = 0
sender_name = re.sub(r'\.', r'_', bus.get_unique_name()[1:])


def new_request_path():
    global request_token_counter
    request_token_counter = request_token_counter + 1
    token = 'u%d' % request_token_counter
    path = '/org/freedesktop/portal/desktop/request/%s/%s' % (sender_name, token)
    return (path, token)


def new_session_path():
    global session_token_counter
    session_token_counter = session_token_counter + 1
    token = 'u%d' % session_token_counter
    path = '/org/freedesktop/portal/desktop/session/%s/%s' % (sender_name, token)
    return (path, token)


def screen_cast_call(method, callback, *args, options={}):
    (request_path, request_token) = new_request_path()
    bus.add_signal_receiver(callback,
                            'Response',
                            request_iface,
                            'org.freedesktop.portal.Desktop',
                            request_path)
    options['handle_token'] = request_token
    method(*(args + (options,)),
           dbus_interface=screen_cast_iface)


def on_sync_message(bus, message):
    if message.get_structure() is None:
        return
    message_name = message.get_structure().get_name()
    if message_name == "prepare-window-handle":
        imagesink = message.src
        if isinstance(imagesink, GstVideo.VideoOverlay):
            xid = widget.get_window().get_xid()
            imagesink.set_window_handle(xid)
            print(f"Setting window handle to XID {xid}")


def on_gst_message(bus, message):
    if message.type == Gst.MessageType.ERROR:
        err, debug = message.parse_error()
        print(f"Error: {err}, {debug}")
        terminate()
    elif message.type == Gst.MessageType.EOS:
        print("End of stream")
        terminate()


def play_pipewire_stream(node_id, stream_properties):
    empty_dict = dbus.Dictionary(signature="sv")
    fd_object = portal.OpenPipeWireRemote(session, empty_dict,
                                          dbus_interface=screen_cast_iface)
    fd = fd_object.take()

    # Add the option to set the framerate to reduce performance impact
    pipeline_str = 'pipewiresrc fd=%d path=%u ! videorate ! video/x-raw,framerate=15/1 ! videoconvert ! ximagesink name=sink' % (fd, node_id)
    global pipeline
    pipeline = Gst.parse_launch(pipeline_str)

    ximagesink = pipeline.get_by_name('sink')
    ximagesink.set_property("sync", False)

    widget, window = create_window(stream_properties['size'][0], stream_properties['size'][1])
    xid = widget.get_window().get_xid()
    ximagesink.set_window_handle(xid)

    bus = pipeline.get_bus()
    bus.add_signal_watch()
    bus.connect("message", on_gst_message)
    bus.connect("sync-message::element", on_sync_message)

    # Set pipeline state to READY initially, and move to PLAYING once the handle is set
    pipeline.set_state(Gst.State.READY)
    pipeline.set_state(Gst.State.PLAYING)

    xdisplay = display.Display()
    xwindow = xdisplay.create_resource_object('window', window.get_window().get_xid())

    # Set window opacity
    opacity_atom = xdisplay.intern_atom("_NET_WM_WINDOW_OPACITY", only_if_exists=False)
    xwindow.change_property(opacity_atom, Xatom.CARDINAL, 32, [0])

    xdisplay.flush()


def on_start_response(response, results):
    if response != 0:
        print("Failed to start: %s" % response)
        terminate()
        return

    print("streams:", results)
    for (node_id, stream_properties) in results['streams']:
        print("stream {}".format(node_id))
        play_pipewire_stream(node_id, stream_properties)


def on_select_sources_response(response, results):
    if response != 0:
        print("Failed to select sources: %d" % response)
        terminate()
        return

    print("sources selected")
    global session
    screen_cast_call(portal.Start, on_start_response,
                     session, '')


def on_create_session_response(response, results):
    if response != 0:
        print("Failed to create session: %d" % response)
        terminate()
        return

    global session
    session = results['session_handle']
    print("session %s created" % session)

    screen_cast_call(portal.SelectSources, on_select_sources_response,
                     session,
                     options={'multiple': False,
                              'cursor_mode': dbus.UInt32(2),
                              'types': dbus.UInt32(1 | 2)})


portal = bus.get_object('org.freedesktop.portal.Desktop',
                        '/org/freedesktop/portal/desktop')

create_tray_icon()

try:
    loop.run()
except KeyboardInterrupt:
    terminate()
