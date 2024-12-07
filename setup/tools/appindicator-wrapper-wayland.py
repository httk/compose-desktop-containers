#!/usr/bin/env python3
import gi
import subprocess
import os
import time
import json
from pathlib import Path

gi.require_version("AppIndicator3", "0.1")
from gi.repository import AppIndicator3, Gtk, GObject, GdkPixbuf


class WaylandAppIndicator:
    def __init__(self, cmd):
        self.cmd = cmd
        self.process = None
        self.pid = None
        self.indicator = AppIndicator3.Indicator.new(
            "wayland-indicator",
            "application-exit",
            AppIndicator3.IndicatorCategory.APPLICATION_STATUS,
        )
        self.indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)

        # Create menu
        self.menu = Gtk.Menu()
        item_toggle = Gtk.MenuItem(label="Show/Focus Program")
        item_toggle.connect("activate", self.on_toggle)
        self.menu.append(item_toggle)

        item_quit = Gtk.MenuItem(label="Quit Wrapper")
        item_quit.connect("activate", self.on_quit)
        self.menu.append(item_quit)
        self.menu.show_all()

        self.indicator.set_menu(self.menu)

        # Launch the application
        self.start_application()
        time.sleep(1)  # Allow time for the application to launch

        # Set tray icon
        self.fetch_and_set_icon()

    def start_application(self):
        """Start the application and get its PID."""
        self.process = subprocess.Popen(self.cmd)
        self.pid = self.process.pid
        print(f"Started application with PID {self.pid}")

    def find_wayland_window(self):
        """Find Wayland window by PID using swaymsg or wayland-info."""
        try:
            # Use `swaymsg -t get_tree` for Sway-based compositors
            output = subprocess.check_output(["swaymsg", "-t", "get_tree"], universal_newlines=True)
            windows = json.loads(output)

            # Recursively search for the window matching the PID
            def find_window(node):
                if node.get("pid") == self.pid:
                    return node
                for child in node.get("nodes", []):
                    result = find_window(child)
                    if result:
                        return result
                return None

            window = find_window(windows)
            if window:
                print(f"Found window: {window}")
                return window
        except Exception as e:
            print(f"Error finding Wayland window: {e}")
        return None

    def fetch_and_set_icon(self):
        """Fetch the application icon via the desktop entry."""
        # Find the application's desktop entry
        desktop_file = self.get_desktop_entry()
        if not desktop_file:
            print("Could not find desktop entry for application.")
            return

        # Parse the desktop entry to find the icon
        icon_name = self.get_icon_from_desktop_entry(desktop_file)
        if not icon_name:
            print("Could not find icon in desktop entry.")
            return

        # Locate the icon in the system's icon theme
        icon_path = self.locate_icon(icon_name)
        if not icon_path:
            print("Could not locate icon in system icon theme.")
            return

        # Set the icon as the tray icon
        pixbuf = GdkPixbuf.Pixbuf.new_from_file(icon_path)
        scaled = pixbuf.scale_simple(32, 32, GdkPixbuf.InterpType.BILINEAR)
        tmp_path = "/tmp/app_icon_wayland.png"
        scaled.savev(tmp_path, "png", [], [])
        self.indicator.set_icon_theme_path("/tmp")
        self.indicator.set_icon("app_icon_wayland")

    def get_desktop_entry(self):
        """Find the desktop entry for the application."""
        try:
            cmd_name = Path(self.cmd[0]).name
            output = subprocess.check_output(["gtk-launch", "--list"], universal_newlines=True)
            for line in output.splitlines():
                if cmd_name in line:
                    desktop_entry_path = f"/usr/share/applications/{line.strip()}.desktop"
                    if os.path.exists(desktop_entry_path):
                        return desktop_entry_path
        except Exception as e:
            print(f"Error finding desktop entry: {e}")
        return None

    def get_icon_from_desktop_entry(self, desktop_file):
        """Parse the desktop entry to find the Icon field."""
        try:
            with open(desktop_file, "r") as f:
                for line in f:
                    if line.startswith("Icon="):
                        return line.split("=", 1)[1].strip()
        except Exception as e:
            print(f"Error reading desktop entry: {e}")
        return None

    def locate_icon(self, icon_name):
        """Locate the icon in the system's icon theme."""
        try:
            output = subprocess.check_output(["xdg-icon-resource", "lookup", icon_name], universal_newlines=True)
            return output.strip()
        except Exception as e:
            print(f"Error locating icon: {e}")
        return None

    def on_toggle(self, source):
        """Toggle the application: bring it to focus or restart if closed."""
        if self.process.poll() is None:
            # Application is running, attempt to focus it
            window = self.find_wayland_window()
            if window:
                subprocess.run(["swaymsg", "[con_id={}] focus".format(window["id"])], check=False)
        else:
            # Restart application
            self.start_application()
            time.sleep(1)
            self.fetch_and_set_icon()

    def on_quit(self, source):
        """Quit the application."""
        if self.process and self.process.poll() is None:
            self.process.terminate()
        Gtk.main_quit()


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Wayland AppIndicator Wrapper")
    parser.add_argument("cmd", nargs="+", help="Command to launch the application")
    args = parser.parse_args()

    GObject.threads_init()
    app = WaylandAppIndicator(cmd=args.cmd)
    Gtk.main()


if __name__ == "__main__":
    main()


