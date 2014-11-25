/* Demo.vala  A simple demo.
 * Copyright (C) 2014  Adrien Plazas
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 */

using Retro;
using Gtk;

class Demo : Gtk.Application {
	construct {
		application_id = "org.retro-gtk.demo";
		flags = ApplicationFlags.FLAGS_NONE;
	}

	public override void activate () {
		Gtk.Settings.get_default().set("gtk-application-prefer-dark-theme", true);

		var window = new Window ();
		window.show ();
//		window.destroy.connect (() => { Gtk.main_quit(); } );
		add_window (window);
	}

	public static int main (string[] argv) {
		Gtk.init (ref argv);
		var clutter_error = Clutter.init (ref argv);
		if (clutter_error != Clutter.InitError.SUCCESS) {
			stderr.printf ("Clutter init error: %s\n", clutter_error.to_string ());
			return clutter_error;
		}

		var d = new Demo ();
		return d.run (argv);
}

}

