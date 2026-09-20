package backend;

import openfl.utils.Assets;

import haxe.Json;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef ModsList = {
	enabled:Array<String>,
	disabled:Array<String>,
	all:Array<String>
};

class Mods
{
	/*
	 * BFEXEOPT ENGINE
	 *
	 * Main game content:
	 * assets/BFEXEOPT/
	 *
	 * This engine does NOT use the external mods/ directory
	 * for the main BFEXEOPT content.
	 */

	static public var currentModDirectory:String = 'BFEXEOPT';

	public static final ignoreModFolders:Array<String> = [
		'characters',
		'custom_events',
		'custom_notetypes',
		'data',
		'songs',
		'music',
		'sounds',
		'shaders',
		'videos',
		'images',
		'stages',
		'weeks',
		'fonts',
		'scripts',
		'achievements'
	];

	private static var globalMods:Array<String> = [];

	/*
	 * ---------------------------------------------------------
	 * GLOBAL MODS
	 * ---------------------------------------------------------
	 *
	 * Kept for compatibility with Psych Engine code.
	 * BFEXEOPT itself is the built-in content pack.
	 */

	inline public static function getGlobalMods():Array<String>
	{
		return globalMods;
	}

	inline public static function pushGlobalMods():Array<String>
	{
		globalMods = [];

		/*
		 * Do not scan external mods.
		 *
		 * BFEXEOPT is already the built-in game content.
		 */

		return globalMods;
	}

	/*
	 * ---------------------------------------------------------
	 * MOD DIRECTORIES
	 * ---------------------------------------------------------
	 *
	 * Disabled for the BFEXEOPT build.
	 */

	inline public static function getModDirectories():Array<String>
	{
		return [];
	}

	/*
	 * ---------------------------------------------------------
	 * TEXT MERGING
	 * ---------------------------------------------------------
	 *
	 * Used by some Psych systems.
	 *
	 * First check the built-in BFEXEOPT content.
	 */

	inline public static function mergeAllTextsNamed(
		path:String,
		?defaultDirectory:String = null,
		allowDuplicates:Bool = false
	)
	{
		if (defaultDirectory == null)
			defaultDirectory = Paths.getGameContentPath();

		defaultDirectory = defaultDirectory.trim();

		if (!defaultDirectory.endsWith('/'))
			defaultDirectory += '/';

		var mergedList:Array<String> = [];

		var paths:Array<String> =
			directoriesWithFile(
				defaultDirectory,
				path,
				false
			);

		var defaultPath:String =
			defaultDirectory + path;

		if (paths.contains(defaultPath))
		{
			paths.remove(defaultPath);
			paths.insert(0, defaultPath);
		}

		for (file in paths)
		{
			var list:Array<String> =
				CoolUtil.coolTextFile(file);

			for (value in list)
			{
				if (
					(
						allowDuplicates
						|| !mergedList.contains(value)
					)
					&& value.length > 0
				)
				{
					mergedList.push(value);
				}
			}
		}

		return mergedList;
	}

	/*
	 * ---------------------------------------------------------
	 * FIND FILES
	 * ---------------------------------------------------------
	 */

	inline public static function directoriesWithFile(
		path:String,
		fileToFind:String,
		mods:Bool = false
	)
	{
		var foldersToCheck:Array<String> = [];

		/*
		 * -----------------------------------------------------
		 * BFEXEOPT
		 * -----------------------------------------------------
		 *
		 * Convert:
		 *
		 * assets/BFEXEOPT/
		 *
		 * + data/file.json
		 *
		 * into:
		 *
		 * assets/BFEXEOPT/data/file.json
		 */

		var gamePath:String = path;

		if (!gamePath.startsWith('assets/BFEXEOPT'))
			gamePath = Paths.getGameContentPath();

		if (!gamePath.endsWith('/'))
			gamePath += '/';

		var gameFile:String =
			gamePath + fileToFind;

		if (
			OpenFlAssets.exists(
				gameFile,
				openfl.utils.AssetType.TEXT
			)
		)
		{
			foldersToCheck.push(gameFile);
		}

		/*
		 * -----------------------------------------------------
		 * Shared fallback
		 * -----------------------------------------------------
		 */

		var sharedFile:String =
			Paths.getSharedPath(fileToFind);

		if (
			OpenFlAssets.exists(
				sharedFile,
				openfl.utils.AssetType.TEXT
			)
			&& !foldersToCheck.contains(sharedFile)
		)
		{
			foldersToCheck.push(sharedFile);
		}

		/*
		 * -----------------------------------------------------
		 * Current level
		 * -----------------------------------------------------
		 */

		if (
			Paths.currentLevel != null
			&& Paths.currentLevel.length > 0
		)
		{
			var levelFile:String =
				Paths.getFolderPath(
					fileToFind,
					Paths.currentLevel
				);

			if (
				OpenFlAssets.exists(
					levelFile,
					openfl.utils.AssetType.TEXT
				)
				&& !foldersToCheck.contains(levelFile)
			)
			{
				foldersToCheck.push(levelFile);
			}
		}

		/*
		 * External mods intentionally ignored.
		 */

		return foldersToCheck;
	}

	/*
	 * ---------------------------------------------------------
	 * PACK.JSON
	 * ---------------------------------------------------------
	 *
	 * BFEXEOPT does not require an external mod pack.json.
	 *
	 * Keep this function for compatibility.
	 */

	public static function getPack(?folder:String = null):Dynamic
	{
		/*
		 * The built-in BFEXEOPT content is not treated as
		 * an external Psych Engine mod.
		 */

		return null;
	}

	/*
	 * ---------------------------------------------------------
	 * MOD LIST
	 * ---------------------------------------------------------
	 *
	 * No modsList.txt is required for the built-in content.
	 */

	public static var updatedOnState:Bool = true;

	inline public static function parseList():ModsList
	{
		return {
			enabled: ['BFEXEOPT'],
			disabled: [],
			all: ['BFEXEOPT']
		};
	}

	private static function updateModList()
	{
		/*
		 * Intentionally disabled.
		 *
		 * BFEXEOPT is packaged directly inside the APK.
		 */
		updatedOnState = true;
	}

	/*
	 * ---------------------------------------------------------
	 * LOAD TOP MOD
	 * ---------------------------------------------------------
	 *
	 * Instead of reading modsList.txt, always select the
	 * built-in BFEXEOPT content.
	 */

	public static function loadTopMod()
	{
		Mods.currentModDirectory = 'BFEXEOPT';

		/*
		 * Tell Paths that BFEXEOPT is the active content.
		 */
		Paths.setCurrentLevel(null);
	}
}
