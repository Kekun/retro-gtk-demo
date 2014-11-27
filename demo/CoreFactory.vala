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

public class CoreFactory : Object {
	private HashTable<string, Array<string>> module_for_ext;

	public VideoHandler video_handler { get; construct set; }
	public AudioHandler audio_handler { get; construct set; }
	public InputHandler input_handler { get; construct set; }
	public VariablesHandler variables_handler { get; construct set; }
	public Retro.Log log_interface { get; construct set; }

	public CoreFactory () {
		module_for_ext = new HashTable<string, Array<string>> (str_hash, str_equal);

		try {
			var dirpath = @"$PREFIX/lib/libretro";
			var directory = File.new_for_path (dirpath);
			var enumerator = directory.enumerate_children (FileAttribute.STANDARD_NAME, 0);

			FileInfo file_info;
			while ((file_info = enumerator.next_file ()) != null) {
				var name = file_info.get_name ();
				if (/libretro-.+\.so/.match (name))
					add_module (@"$dirpath/$name");
			}

		} catch (Error e) {
			stderr.printf ("Error: %s\n", e.message);
		}
	}

	private void add_module (string file_name) {
		var info = Retro.get_system_info (file_name);
		if (info == null) return;

		var exts = info.valid_extensions.split ("|");
		foreach (var ext in exts) {
			if (module_for_ext[ext] == null) module_for_ext[ext] = new Array<string> ();
			module_for_ext[ext].append_val (file_name);
		}
	}

	public List<weak string> get_valid_extensions () {
		return module_for_ext.get_keys ();
	}

	public Core? core_for_game (string game_name) {
		var split = game_name.split(".");
		var ext = split[split.length -1];

		if (! module_for_ext.contains (ext))
			return null; // TODO warn

		var modules = module_for_ext[ext];
		// Using foreach on modules.data display warnings

		for (uint i = 0 ; i < modules.length ; i ++) {
			var module = modules.index (i);
			var core = new Core (module);

			init_handlers ();

			core.variables_handler = variables_handler;
			core.log_interface = log_interface;

			core.video_handler = video_handler;
			core.audio_handler = audio_handler;
			core.input_handler = input_handler;

			core.init ();

			try {
				var fullpath = core.system_info.need_fullpath;
				if (core.load_game (fullpath ? GameInfo (game_name) : GameInfo.with_data (game_name)))
					return core;
			}
			catch (GLib.FileError e) {
				stderr.printf ("Error: %s\n", e.message);
			}
		}

		return null; // TODO warn
	}

	private void init_handlers () {
		variables_handler.core = null;
		video_handler.core = null;
		audio_handler.core = null;
		input_handler.core = null;
	}
}

