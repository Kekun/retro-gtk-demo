/* Copyright (C) 2014  Adrien Plazas
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
using RetroGtk;

using Gtk;

private enum UiState {
	EMPTY,
	GAME_LOADED
}

private class DemoHeaderBar : HeaderBar {
	public Button open_game_button;
	public Button start_button;
	public Button stop_button;

	public Button gamepad_button;
	public MenuButton properties_button;
	public Popover popover;

	public bool play { set; get; }
	private Image play_image;
	private Image pause_image;

	public Widget grid;

	construct {
		open_game_button = new Button.from_icon_name ("document-open-symbolic", IconSize.SMALL_TOOLBAR);
		start_button = new Button ();
		stop_button = new Button.from_icon_name ("media-skip-backward-symbolic", IconSize.SMALL_TOOLBAR);

		gamepad_button = new Button.from_icon_name ("applications-games-symbolic", IconSize.SMALL_TOOLBAR);
		properties_button = new MenuButton ();
		popover = new Popover (properties_button);

		play_image = new Image.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
		pause_image = new Image.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.SMALL_TOOLBAR);

		start_button.set_image (play ? pause_image : play_image);
		notify["play"].connect (() => {
			start_button.set_image (play ? pause_image : play_image);
		});

		properties_button.set_popover (popover);

		pack_start (open_game_button);
		pack_start (start_button);
		pack_start (stop_button);
		pack_end (properties_button);
		pack_end (gamepad_button);

		open_game_button.show ();
		start_button.show ();
		stop_button.show ();
		gamepad_button.show ();
		properties_button.show ();

		set_show_close_button (true);
	}

	public void set_ui_state (UiState ui_state) {
		switch (ui_state) {
			case UiState.EMPTY:
				start_button.hide ();
				stop_button.hide ();
				properties_button.hide ();
				set_title ("RetroGtk Demo");
				break;
			case UiState.GAME_LOADED:
				start_button.show ();
				stop_button.show ();
				properties_button.show ();
				break;
		}
	}
}

public class Window : Gtk.ApplicationWindow {
	private CoreFactory factory;

	private DemoHeaderBar header;
	private EventBox kb_box;
	private Display game_screen;

	private VirtualGamepad virtual_gamepad;
	private Gamepad gamepad;

	private Options options;
	private RetroGtk.InputDeviceManager controller_interface;
	private Loop loop;
	private bool running { set; get; default = false; }

	construct {
		header = new DemoHeaderBar ();
		kb_box = new EventBox ();
		game_screen = new CairoDisplay ();
		game_screen.set_size_request (640, 480);

		set_titlebar (header);
		add (kb_box);
		kb_box.add (game_screen);

		header.open_game_button.clicked.connect (on_open_game_button_clicked);
		header.start_button.clicked.connect (on_start_button_clicked);
		header.stop_button.clicked.connect (on_stop_button_clicked);
		header.properties_button.clicked.connect (on_properties_button_clicked);

		header.show ();
		kb_box.show ();
		game_screen.show ();

		header.set_ui_state (UiState.EMPTY);

		var monitor = new Jsk.JoystickMonitor ("/dev/input");
		var joysticks = monitor.get_joysticks ();
		if (joysticks.length > 0)
			gamepad = new Gamepad (new Jsk.Gamepad (joysticks[0]));

		virtual_gamepad = new VirtualGamepad (kb_box);

		header.gamepad_button.clicked.connect (() => {
			var gamepad_dialog = new GamepadConfigurationDialog ();
			gamepad_dialog.set_transient_for (this);
			if (gamepad_dialog.run () == ResponseType.APPLY) {
				virtual_gamepad.configuration = gamepad_dialog.configuration;
			}
			gamepad_dialog.close ();
		});

		var mouse = new Mouse (kb_box);
		mouse.notify["parse"].connect (() => header.set_subtitle (mouse.parse ? "Press Crtl+Esc to ungrab" : null));

		options = new Options ();
		controller_interface = new RetroGtk.InputDeviceManager ();
		if (gamepad != null)
			controller_interface.set_controller_device (0, gamepad);
		else
			controller_interface.set_controller_device (0, virtual_gamepad);
		controller_interface.set_controller_device (1, mouse);
		controller_interface.set_keyboard (new Keyboard (kb_box));

		factory = new CoreFactory ();

		factory.video_interface = game_screen;
		factory.audio_interface = new PaPlayer ();
		factory.input_interface = controller_interface;
		factory.variables_interface = options;
		factory.log_interface = new FileStreamLog ();
	}

	void on_open_game_button_clicked (Gtk.Button button) {
		var dialog = new Gtk.FileChooserDialog ("Open core", this, Gtk.FileChooserAction.OPEN, "_Cancel", ResponseType.CANCEL, "_Open", ResponseType.ACCEPT);

		var filter = new FileFilter ();
		filter.set_filter_name ("Valid games");
		foreach (var ext in factory.get_valid_extensions ()) {
			filter.add_pattern ("*." + ext);
		}
		dialog.add_filter (filter);

		if (dialog.run () == Gtk.ResponseType.ACCEPT) {
			set_game (dialog.get_filename ());
		}

		dialog.destroy ();
	}

	void on_start_button_clicked (Gtk.Button button) {
		if (running) {
			loop.stop ();
			running = false;
			game_screen.hide_video ();
		}
		else {
			loop.start ();
			running = true;
			game_screen.show_video ();
		}
		header.play = running;
	}

	void on_stop_button_clicked (Gtk.Button button) {
		loop.reset ();
	}

	void on_properties_button_clicked (Gtk.Button button) {
		if (header.grid != null) header.popover.remove (header.grid);

		header.grid = new OptionsGrid (options);
		header.grid.show_all ();

		header.popover.add (header.grid);
	}

	private void set_game (string path) {
		var core = factory.core_for_game (path);
		if (core == null) return;

		if (loop != null) {
			loop.stop ();
			loop = null;
			running = false;
		}

		loop = new ThreadedLoop (core);

		header.open_game_button.show ();
		header.set_title (File.new_for_path (path).get_basename ());

		header.set_ui_state (UiState.GAME_LOADED);

		header.start_button.clicked ();
	}
}

