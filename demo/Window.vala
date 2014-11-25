/* Window.vala  A simple display.
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
using RetroGtk;

using Gtk;

public class Window : Gtk.Window {
	private CoreFactory factory;

	private enum UiState {
		EMPTY,
		GAME_LOADED
	}

	private Gtk.HeaderBar header;
	private KeyboardBox kb_box;
	private Display game_screen;

	private Gtk.Image play_image;
	private Gtk.Image pause_image;

	private Gtk.Button open_game_button;
	private Gtk.Button start_button;
	private Gtk.Button stop_button;
	private Gtk.MenuButton properties_button;
	private Gtk.Popover popover;
	private Gtk.Widget grid;

	private KeyboardGamepadAdapter gamepad;

	private OptionsHandler options;
	private Runner runner;
	private bool running { set; get; default = false; }

	public Window (string[] modules) {
		factory = CoreFactory.instance;

		header = new Gtk.HeaderBar ();
		kb_box = new KeyboardBox ();
		game_screen = new Display ();
		game_screen.set_size_request (640, 480);

		open_game_button = new Gtk.Button.from_icon_name ("document-open-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
		start_button = new Gtk.Button ();
		stop_button = new Gtk.Button.from_icon_name ("media-skip-backward-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
		properties_button = new Gtk.MenuButton ();
		popover = new Gtk.Popover (properties_button);

		set_titlebar (header);
		add (kb_box);
		kb_box.add (game_screen);

		header.pack_start (open_game_button);
		header.pack_start (start_button);
		header.pack_start (stop_button);
		header.pack_end (properties_button);

		header.set_show_close_button (true);

		open_game_button.clicked.connect (on_open_game_button_clicked);
		start_button.clicked.connect (on_start_button_clicked);
		stop_button.clicked.connect (on_stop_button_clicked);
		properties_button.clicked.connect (on_properties_button_clicked);

		header.show ();
		kb_box.show ();
		game_screen.show ();

		open_game_button.show ();
		start_button.show ();
		stop_button.show ();
		properties_button.show ();

		set_ui_state (UiState.EMPTY);

		play_image = new Image.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
		pause_image = new Image.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.SMALL_TOOLBAR);

		start_button.set_image (running ? pause_image : play_image);

		properties_button.set_popover (popover);

		gamepad = new KeyboardGamepadAdapter (kb_box);

		var gamepad_button = new Button.from_icon_name ("applications-games-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
		header.pack_end (gamepad_button);
		gamepad_button.show ();

		gamepad_button.clicked.connect (() => {
			var gamepad_dialog = new KeyboardGamepadConfigurationDialog ();
			gamepad_dialog.set_transient_for (this);
			if (gamepad_dialog.run () == ResponseType.APPLY) {
				gamepad.configuration = gamepad_dialog.configuration;
			}
			gamepad_dialog.close ();
		});
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
			runner.stop ();
			running = false;
			start_button.set_image (play_image);
			game_screen.hide_texture ();
		}
		else {
			runner.start ();
			running = true;
			start_button.set_image (pause_image);
			game_screen.show_texture ();
		}
	}

	void on_stop_button_clicked (Gtk.Button button) {
		runner.reset ();
	}

	void on_properties_button_clicked (Gtk.Button button) {
		if (grid != null) popover.remove (grid);

		grid = new OptionsGrid (options);
		grid.show_all ();

		popover.add (grid);
	}

	private void set_game (string path) {
		var core = factory.core_for_game (path);
		if (core == null) return;

		if (runner != null) {
			runner.stop ();
			runner = null;
		}

		// Video
		game_screen.core = core;
		core.video_handler = game_screen;

		// Audio
		core.audio_handler = new AudioDevice ();

		// Input
		var controller_handler = new ControllerHandler ();
		controller_handler.core = core;
		core.input_handler = controller_handler;
		controller_handler.set_controller_device (0, gamepad);

		// Options
		options = new OptionsHandler ();
		options.value_changed.connect (() => {
			core.variable_update = true;
		});
		core.get_variable.connect ((key) => { return options[key]; });
		core.set_variables.connect ((variables) => {
			options.insert_multiple (variables);
			return true;
		});

		// Log
		core.log_interface = new FileStreamLogger ();

		core.init ();

		runner = new Runner (core);

		open_game_button.show ();
		header.set_title (core.system_info.library_name);

		header.set_subtitle (File.new_for_path (path).get_basename ());

		set_ui_state (UiState.GAME_LOADED);

		start_button.clicked ();
	}

	private void set_ui_state (UiState ui_state) {
		switch (ui_state) {
			case UiState.EMPTY:
				start_button.hide ();
				stop_button.hide ();
				properties_button.hide ();
				break;
			case UiState.GAME_LOADED:
				start_button.show ();
				stop_button.show ();
				properties_button.show ();
				break;
		}
	}
}

