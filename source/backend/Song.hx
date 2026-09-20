package backend;

import haxe.Json;
import openfl.utils.Assets as OpenFlAssets;

import objects.Note;

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var events:Array<Dynamic>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;
	var offset:Float;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;
	var format:String;

	@:optional var gameOverChar:String;
	@:optional var gameOverSound:String;
	@:optional var gameOverLoop:String;
	@:optional var gameOverEnd:String;

	@:optional var disableNoteRGB:Bool;

	@:optional var arrowSkin:String;
	@:optional var splashSkin:String;
}

typedef SwagSection =
{
	var sectionNotes:Array<Dynamic>;
	var sectionBeats:Float;
	var mustHitSection:Bool;
	@:optional var altAnim:Bool;
	@:optional var gfSection:Bool;
	@:optional var bpm:Float;
	@:optional var changeBPM:Bool;
}

class Song
{
	public var song:String;
	public var notes:Array<SwagSection>;
	public var events:Array<Dynamic>;
	public var bpm:Float;
	public var needsVoices:Bool = true;

	public var arrowSkin:String;
	public var splashSkin:String;

	public var gameOverChar:String;
	public var gameOverSound:String;
	public var gameOverLoop:String;
	public var gameOverEnd:String;

	public var disableNoteRGB:Bool = false;

	public var speed:Float = 1;
	public var stage:String;

	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';

	public var format:String = 'psych_v1';

	/*
	 * =========================================================
	 * CHART CONVERSION
	 * =========================================================
	 */

	public static function convert(songJson:Dynamic)
	{
		/*
		 * Old Psych charts used player3 for GF.
		 */
		if (songJson.gfVersion == null)
		{
			songJson.gfVersion =
				songJson.player3;

			if (
				Reflect.hasField(
					songJson,
					'player3'
				)
			)
			{
				Reflect.deleteField(
					songJson,
					'player3'
				);
			}
		}

		/*
		 * Old charts may not contain events.
		 */
		if (songJson.events == null)
		{
			songJson.events = [];

			if (songJson.notes != null)
			{
				for (
					secNum in 0...songJson.notes.length
				)
				{
					var sec:SwagSection =
						songJson.notes[secNum];

					var i:Int = 0;

					var notes:Array<Dynamic> =
						sec.sectionNotes;

					var len:Int =
						notes.length;

					while (i < len)
					{
						var note:Array<Dynamic> =
							notes[i];

						if (note[1] < 0)
						{
							songJson.events.push(
								[
									note[0],
									[
										[
											note[2],
											note[3],
											note[4]
										]
									]
								]
							);

							notes.remove(note);

							len =
								notes.length;
						}
						else
						{
							i++;
						}
					}
				}
			}
		}

		var sectionsData:Array<SwagSection> =
			songJson.notes;

		if (sectionsData == null)
			return;

		for (section in sectionsData)
		{
			var beats:Null<Float> =
				cast section.sectionBeats;

			if (
				beats == null
				|| Math.isNaN(beats)
			)
			{
				section.sectionBeats = 4;

				if (
					Reflect.hasField(
						section,
						'lengthInSteps'
					)
				)
				{
					Reflect.deleteField(
						section,
						'lengthInSteps'
					);
				}
			}

			if (section.sectionNotes == null)
				continue;

			for (note in section.sectionNotes)
			{
				var gottaHitNote:Bool =
					(note[1] < 4)
						? section.mustHitSection
						: !section.mustHitSection;

				note[1] =
					(note[1] % 4)
					+ (
						gottaHitNote
							? 0
							: 4
					);

				/*
				 * Compatibility with old numeric note types.
				 */
				if (
					!Std.isOfType(
						note[3],
						String
					)
				)
				{
					note[3] =
						Note.defaultNoteTypes[
							note[3]
						];
				}
			}
		}
	}

	/*
	 * =========================================================
	 * CURRENT CHART
	 * =========================================================
	 */

	public static var chartPath:String;
	public static var loadedSongName:String;

	public static function loadFromJson(
		jsonInput:String,
		?folder:String
	):SwagSong
	{
		if (folder == null)
			folder = jsonInput;

		PlayState.SONG =
			getChart(
				jsonInput,
				folder
			);

		loadedSongName =
			folder;

		chartPath =
			_lastPath;

		#if windows
		/*
		 * Windows-only path normalization.
		 */
		chartPath =
			chartPath.replace(
				'/',
				'\\'
			);
		#end

		/*
		 * Load the stage belonging to the chart.
		 */
		if (PlayState.SONG != null)
			StageData.loadDirectory(
				PlayState.SONG
			);

		return PlayState.SONG;
	}

	/*
	 * Last resolved chart path.
	 */
	static var _lastPath:String;

	/*
	 * =========================================================
	 * LOAD CHART
	 * =========================================================
	 *
	 * BFEXEOPT chart location:
	 *
	 * assets/BFEXEOPT/data/<song>/<song>.json
	 *
	 * Paths.json() handles the actual asset mapping.
	 *
	 * No mods/ directory is used here.
	 */

	public static function getChart(
		jsonInput:String,
		?folder:String
	):SwagSong
	{
		if (folder == null)
			folder = jsonInput;

		var rawData:String = null;

		var formattedFolder:String =
			Paths.formatToSongPath(
				folder
			);

		var formattedSong:String =
			Paths.formatToSongPath(
				jsonInput
			);

		/*
		 * Paths.json() resolves the chart through
		 * the BFEXEOPT content path.
		 */
		_lastPath =
			Paths.json(
				'$formattedFolder/$formattedSong'
			);

		/*
		 * Packaged APK asset.
		 */
		if (
			OpenFlAssets.exists(
				_lastPath,
				openfl.utils.AssetType.TEXT
			)
		)
		{
			try
			{
				rawData =
					OpenFlAssets.getText(
						_lastPath
					);
			}
			catch (e:Dynamic)
			{
				trace(
					'Failed to read chart: '
					+ _lastPath
				);

				trace(e);
			}
		}
		else
		{
			trace(
				'Chart not found: '
				+ _lastPath
			);
		}

		if (
			rawData != null
			&& rawData.length > 0
		)
		{
			return parseJSON(
				rawData,
				jsonInput
			);
		}

		return null;
	}

	/*
	 * =========================================================
	 * PARSE JSON
	 * =========================================================
	 */

	public static function parseJSON(
		rawData:String,
		?nameForError:String = null,
		?convertTo:String = 'psych_v1'
	):SwagSong
	{
		if (
			rawData == null
			|| rawData.length == 0
		)
		{
			return null;
		}

		var songJson:SwagSong;

		try
		{
			songJson =
				cast Json.parse(
					rawData
				);
		}
		catch (e:Dynamic)
		{
			trace(
				'Failed to parse chart: '
				+ nameForError
			);

			trace(e);

			return null;
		}

		/*
		 * Some older charts wrap the actual song
		 * data inside a "song" object.
		 */
		if (
			Reflect.hasField(
				songJson,
				'song'
			)
		)
		{
			var subSong:SwagSong =
				Reflect.field(
					songJson,
					'song'
				);

			if (
				subSong != null
				&& Type.typeof(subSong)
					== TObject
			)
			{
				songJson =
					subSong;
			}
		}

		/*
		 * Convert old chart formats to Psych 1.0.
		 */
		if (
			convertTo != null
			&& convertTo.length > 0
		)
		{
			var fmt:String =
				songJson.format;

			if (fmt == null)
			{
				fmt =
					songJson.format =
						'unknown';
			}

			switch (convertTo)
			{
				case 'psych_v1':

					if (
						!fmt.startsWith(
							'psych_v1'
						)
					)
					{
						trace(
							'converting chart '
							+ nameForError
							+ ' with format '
							+ fmt
							+ ' to psych_v1 format...'
						);

						songJson.format =
							'psych_v1_convert';

						convert(
							songJson
						);
					}
			}
		}

		return songJson;
	}
}
