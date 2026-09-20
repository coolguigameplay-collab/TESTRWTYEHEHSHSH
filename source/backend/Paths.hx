package backend;

import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxRect;
import flixel.system.FlxAssets;

import openfl.display.BitmapData;
import openfl.display3D.textures.RectangleTexture;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import openfl.system.System;
import openfl.geom.Rectangle;

import lime.utils.Assets;
import flash.media.Sound;

import haxe.Json;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class Paths
{
	/*
	 * =========================================================
	 * BFEXEOPT STANDALONE CONTENT SYSTEM
	 * =========================================================
	 *
	 * All mod/game content is expected to be packaged as:
	 *
	 * assets/BFEXEOPT/
	 *
	 * project.xml:
	 *
	 * <assets path="assets/BFEXEOPT" rename="BFEXEOPT" />
	 *
	 * The engine will NEVER use the external "mods/" folder
	 * as the main content source.
	 *
	 * BFEXEOPT is intentionally fixed.
	 */

	inline public static var GAME_CONTENT:String = "BFEXEOPT";

	inline public static var SOUND_EXT =
		#if web
			"mp3"
		#else
			"ogg"
		#end

	inline public static var VIDEO_EXT = "mp4";

	/*
	 * ---------------------------------------------------------
	 * BFEXEOPT PATH HELPERS
	 * ---------------------------------------------------------
	 */

	inline static public function getGameContentPath(file:String = '')
	{
		if (file == null || file.length == 0)
			return GAME_CONTENT;

		return GAME_CONTENT + '/' + file;
	}

	/**
	 * Checks whether a packaged BFEXEOPT asset exists.
	 */
	inline static public function gameContentExists(file:String, type:AssetType = TEXT):Bool
	{
		return OpenFlAssets.exists(getGameContentPath(file), type);
	}

	/**
	 * Returns a BFEXEOPT path for a normal asset.
	 *
	 * Example:
	 * getGamePath("images/menuBG.png")
	 *
	 * -> BFEXEOPT/images/menuBG.png
	 */
	inline static public function getGamePath(file:String, ?parentfolder:String):String
	{
		var path:String = file;

		if (parentfolder != null && parentfolder.length > 0)
			path = parentfolder + '/' + file;

		return getGameContentPath(path);
	}

	/*
	 * =========================================================
	 * MEMORY / CACHE
	 * =========================================================
	 */

	public static function excludeAsset(key:String)
	{
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static var dumpExclusions:Array<String> = [
		'assets/shared/music/freakyMenu.$SOUND_EXT',
		'assets/shared/mobile/touchpad/bg.png'
	];

	public static function clearUnusedMemory()
	{
		for (key in currentTrackedAssets.keys())
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				destroyGraphic(currentTrackedAssets.get(key));
				currentTrackedAssets.remove(key);
			}
		}

		System.gc();

		#if cpp
		cpp.NativeGc.run(true);
		#end
	}

	public static var localTrackedAssets:Array<String> = [];

	@:access(flixel.system.frontEnds.BitmapFrontEnd._cache)
	public static function clearStoredMemory()
	{
		for (key in FlxG.bitmap._cache.keys())
		{
			if (!currentTrackedAssets.exists(key))
				destroyGraphic(FlxG.bitmap.get(key));
		}

		for (key => asset in currentTrackedSounds)
		{
			if (!localTrackedAssets.contains(key)
				&& !dumpExclusions.contains(key)
				&& asset != null)
			{
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}

		localTrackedAssets = [];

		#if !html5
		openfl.Assets.cache.clear("songs");
		#end
	}

	public static function freeGraphicsFromMemory()
	{
		var protectedGfx:Array<FlxGraphic> = [];

		function checkForGraphics(spr:Dynamic)
		{
			try
			{
				var grp:Array<Dynamic> = Reflect.getProperty(spr, 'members');

				if (grp != null)
				{
					for (member in grp)
						checkForGraphics(member);

					return;
				}
			}
			catch (e:Dynamic) {}

			try
			{
				var gfx:FlxGraphic = Reflect.getProperty(spr, 'graphic');

				if (gfx != null)
					protectedGfx.push(gfx);
			}
			catch (e:Dynamic) {}
		}

		for (member in FlxG.state.members)
			checkForGraphics(member);

		if (FlxG.state.subState != null)
		{
			for (member in FlxG.state.subState.members)
				checkForGraphics(member);
		}

		for (key in currentTrackedAssets.keys())
		{
			if (!dumpExclusions.contains(key))
			{
				var graphic:FlxGraphic = currentTrackedAssets.get(key);

				if (!protectedGfx.contains(graphic))
				{
					destroyGraphic(graphic);
					currentTrackedAssets.remove(key);
				}
			}
		}
	}

	inline static function destroyGraphic(graphic:FlxGraphic)
	{
		if (graphic != null
			&& graphic.bitmap != null
			&& graphic.bitmap.__texture != null)
		{
			graphic.bitmap.__texture.dispose();
		}

		FlxG.bitmap.remove(graphic);
	}

	/*
	 * =========================================================
	 * LEVEL
	 * =========================================================
	 */

	static public var currentLevel:String;

	public static function setCurrentLevel(name:String)
		currentLevel = name.toLowerCase();

	/*
	 * =========================================================
	 * MAIN PATH RESOLVER
	 * =========================================================
	 *
	 * Priority:
	 *
	 * 1. BFEXEOPT packaged content
	 * 2. currentLevel inside normal engine assets
	 * 3. shared engine assets
	 *
	 * External mods/ folder is intentionally NOT checked.
	 */

	public static function getPath(
		file:String,
		?type:AssetType = TEXT,
		?parentfolder:String,
		?modsAllowed:Bool = true
	):String
	{
		/*
		 * BFEXEOPT CONTENT
		 *
		 * If parentfolder exists:
		 *
		 * BFEXEOPT/<parentfolder>/<file>
		 *
		 * Otherwise:
		 *
		 * BFEXEOPT/<file>
		 */

		var gamePath:String = getGamePath(file, parentfolder);

		if (OpenFlAssets.exists(gamePath, type))
			return gamePath;

		/*
		 * Mobile is still handled by the normal shared engine
		 * assets. This keeps Psych Engine's mobile controls
		 * working.
		 */

		if (parentfolder == "mobile")
			return getSharedPath('mobile/$file');

		/*
		 * If the requested parent folder is an engine folder,
		 * check the normal assets directory.
		 */

		if (parentfolder != null)
		{
			var folderPath:String = getFolderPath(file, parentfolder);

			if (OpenFlAssets.exists(folderPath, type))
				return folderPath;
		}

		/*
		 * Current level fallback.
		 */

		if (currentLevel != null && currentLevel != 'shared')
		{
			var levelPath:String = getFolderPath(file, currentLevel);

			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;
		}

		/*
		 * Final fallback: shared engine assets.
		 */

		return getSharedPath(file);
	}

	inline static public function getFolderPath(
		file:String,
		folder:String = "shared"
	)
	{
		return 'assets/$folder/$file';
	}

	inline public static function getSharedPath(file:String = '')
	{
		return 'assets/shared/$file';
	}

	/*
	 * =========================================================
	 * TEXT / DATA
	 * =========================================================
	 */

	inline static public function txt(key:String, ?folder:String)
		return getPath('data/$key.txt', TEXT, folder, false);

	inline static public function xml(key:String, ?folder:String)
		return getPath('data/$key.xml', TEXT, folder, false);

	inline static public function json(key:String, ?folder:String)
		return getPath('data/$key.json', TEXT, folder, false);

	inline static public function shaderFragment(key:String, ?folder:String)
		return getPath('shaders/$key.frag', TEXT, folder, false);

	inline static public function shaderVertex(key:String, ?folder:String)
		return getPath('shaders/$key.vert', TEXT, folder, false);

	inline static public function lua(key:String, ?folder:String)
		return getPath('$key.lua', TEXT, folder, false);

	/*
	 * =========================================================
	 * VIDEO
	 * =========================================================
	 */

	static public function video(key:String)
	{
		var packaged:String = getGamePath(
			'videos/$key.$VIDEO_EXT'
		);

		if (OpenFlAssets.exists(packaged, AssetType.BINARY))
			return packaged;

		var shared:String = 'assets/videos/$key.$VIDEO_EXT';

		if (OpenFlAssets.exists(shared, AssetType.BINARY))
			return shared;

		return packaged;
	}

	/*
	 * =========================================================
	 * SOUND
	 * =========================================================
	 */

	inline static public function sound(
		key:String,
		?modsAllowed:Bool = true
	):Sound
	{
		return returnSound(
			'sounds/$key',
			null,
			false
		);
	}

	inline static public function music(
		key:String,
		?modsAllowed:Bool = true
	):Sound
	{
		return returnSound(
			'music/$key',
			null,
			false
		);
	}

	inline static public function inst(
		song:String,
		?modsAllowed:Bool = true
	):Sound
	{
		return returnSound(
			'${formatToSongPath(song)}/Inst',
			'songs',
			false
		);
	}

	inline static public function voices(
		song:String,
		postfix:String = null,
		?modsAllowed:Bool = true
	):Sound
	{
		var songKey:String =
			'${formatToSongPath(song)}/Voices';

		if (postfix != null)
			songKey += '-' + postfix;

		return returnSound(
			songKey,
			'songs',
			false,
			false
		);
	}

	inline static public function soundRandom(
		key:String,
		min:Int,
		max:Int,
		?modsAllowed:Bool = true
	)
	{
		return sound(
			key + FlxG.random.int(min, max),
			false
		);
	}

	/*
	 * =========================================================
	 * IMAGE CACHE
	 * =========================================================
	 */

	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];

	static public function image(
		key:String,
		?parentFolder:String = null,
		?allowGPU:Bool = true
	):FlxGraphic
	{
		key =
			Language.getFileTranslation(
				'images/$key'
			) + '.png';

		var bitmap:BitmapData = null;

		if (currentTrackedAssets.exists(key))
		{
			localTrackedAssets.push(key);
			return currentTrackedAssets.get(key);
		}

		return cacheBitmap(
			key,
			parentFolder,
			bitmap,
			allowGPU
		);
	}

	public static function cacheBitmap(
		key:String,
		?parentFolder:String,
		?bitmap:BitmapData,
		?allowGPU:Bool = true
	):FlxGraphic
	{
		if (bitmap == null)
		{
			var file:String =
				getPath(
					key,
					IMAGE,
					parentFolder,
					false
				);

			if (OpenFlAssets.exists(file, IMAGE))
				bitmap =
					OpenFlAssets.getBitmapData(file);

			if (bitmap == null)
			{
				trace(
					'Bitmap not found: '
					+ file
					+ ' | key: '
					+ key
				);

				return null;
			}
		}

		if (
			allowGPU
			&& ClientPrefs.data.cacheOnGPU
			&& bitmap.image != null
		)
		{
			bitmap.lock();

			if (bitmap.__texture == null)
			{
				bitmap.image.premultiplied = true;
				bitmap.getTexture(
					FlxG.stage.context3D
				);
			}

			bitmap.getSurface();
			bitmap.disposeImage();

			bitmap.image.data = null;
			bitmap.image = null;
			bitmap.readable = true;
		}

		var graph:FlxGraphic =
			FlxGraphic.fromBitmapData(
				bitmap,
				false,
				key
			);

		graph.persist = true;
		graph.destroyOnNoUse = false;

		currentTrackedAssets.set(
			key,
			graph
		);

		localTrackedAssets.push(key);

		return graph;
	}

	/*
	 * =========================================================
	 * TEXT FILE READING
	 * =========================================================
	 */

	inline static public function getTextFromFile(
		key:String,
		?ignoreMods:Bool = false
	):String
	{
		var path:String =
			getPath(
				key,
				TEXT,
				null,
				false
			);

		#if sys
		if (FileSystem.exists(path))
			return File.getContent(path);

		if (OpenFlAssets.exists(path, TEXT))
			return Assets.getText(path);

		return null;
		#else
		return OpenFlAssets.exists(path, TEXT)
			? Assets.getText(path)
			: null;
		#end
	}

	/*
	 * =========================================================
	 * FONT
	 * =========================================================
	 */

	inline static public function font(key:String)
	{
		var folderKey:String =
			Language.getFileTranslation(
				'fonts/$key'
			);

		/*
		 * BFEXEOPT font first.
		 */

		var packaged:String =
			getGameContentPath(folderKey);

		if (OpenFlAssets.exists(packaged, AssetType.FONT))
			return packaged;

		/*
		 * Shared engine font fallback.
		 */

		return 'assets/$folderKey';
	}

	/*
	 * =========================================================
	 * FILE EXISTS
	 * =========================================================
	 */

	public static function fileExists(
		key:String,
		type:AssetType,
		?ignoreMods:Bool = false,
		?parentFolder:String = null
	)
	{
		/*
		 * BFEXEOPT first.
		 */

		var packaged:String =
			getGamePath(
				key,
				parentFolder
			);

		if (OpenFlAssets.exists(packaged, type))
			return true;

		/*
		 * Shared/engine fallback.
		 */

		var normal:String =
			getPath(
				key,
				type,
				parentFolder,
				false
			);

		return OpenFlAssets.exists(
			normal,
			type
		);
	}

	/*
	 * =========================================================
	 * ATLAS
	 * =========================================================
	 */

	static public function getAtlas(
		key:String,
		?parentFolder:String = null,
		?allowGPU:Bool = true
	):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic =
			image(
				key,
				parentFolder,
				allowGPU
			);

		if (imageLoaded == null)
			return null;

		/*
		 * Sparrow XML
		 */

		var myXml:String =
			getPath(
				'images/$key.xml',
				TEXT,
				parentFolder,
				false
			);

		if (OpenFlAssets.exists(myXml, TEXT))
		{
			return FlxAtlasFrames.fromSparrow(
				imageLoaded,
				myXml
			);
		}

		/*
		 * TexturePacker JSON
		 */

		var myJson:String =
			getPath(
				'images/$key.json',
				TEXT,
				parentFolder,
				false
			);

		if (OpenFlAssets.exists(myJson, TEXT))
		{
			return FlxAtlasFrames.fromTexturePackerJson(
				imageLoaded,
				myJson
			);
		}

		return getPackerAtlas(
			key,
			parentFolder,
			allowGPU
		);
	}

	/*
	 * =========================================================
	 * MULTI ATLAS
	 * =========================================================
	 */

	static public function getMultiAtlas(
		keys:Array<String>,
		?parentFolder:String = null,
		?allowGPU:Bool = true
	):FlxAtlasFrames
	{
		if (keys == null || keys.length == 0)
			return null;

		var parentFrames:FlxAtlasFrames =
			Paths.getAtlas(
				keys[0].trim(),
				parentFolder,
				allowGPU
			);

		if (parentFrames == null)
			return null;

		if (keys.length > 1)
		{
			var original:FlxAtlasFrames =
				parentFrames;

			parentFrames =
				new FlxAtlasFrames(
					original.parent
				);

			parentFrames.addAtlas(
				original,
				true
			);

			for (i in 1...keys.length)
			{
				var extraFrames:FlxAtlasFrames =
					Paths.getAtlas(
						keys[i].trim(),
						parentFolder,
						allowGPU
					);

				if (extraFrames != null)
					parentFrames.addAtlas(
						extraFrames,
						true
					);
			}
		}

		return parentFrames;
	}

	/*
	 * =========================================================
	 * SPARROW
	 * =========================================================
	 */

	inline static public function getSparrowAtlas(
		key:String,
		?parentFolder:String = null,
		?allowGPU:Bool = true
	):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic =
			image(
				key,
				parentFolder,
				allowGPU
			);

		if (imageLoaded == null)
			return null;

		var xmlPath:String =
			getPath(
				Language.getFileTranslation(
					'images/$key'
				) + '.xml',
				TEXT,
				parentFolder,
				false
			);

		if (!OpenFlAssets.exists(xmlPath, TEXT))
		{
			trace(
				'Sparrow XML not found: '
				+ xmlPath
			);

			return null;
		}

		return FlxAtlasFrames.fromSparrow(
			imageLoaded,
			xmlPath
		);
	}

	/*
	 * =========================================================
	 * TEXTURE PACKER
	 * =========================================================
	 */

	inline static public function getPackerAtlas(
		key:String,
		?parentFolder:String = null,
		?allowGPU:Bool = true
	):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic =
			image(
				key,
				parentFolder,
				allowGPU
			);

		if (imageLoaded == null)
			return null;

		var txtPath:String =
			getPath(
				Language.getFileTranslation(
					'images/$key'
				) + '.txt',
				TEXT,
				parentFolder,
				false
			);

		if (!OpenFlAssets.exists(txtPath, TEXT))
		{
			trace(
				'Packer TXT not found: '
				+ txtPath
			);

			return null;
		}

		return FlxAtlasFrames.fromSpriteSheetPacker(
			imageLoaded,
			txtPath
		);
	}

	/*
	 * =========================================================
	 * ASEPRITE / JSON ATLAS
	 * =========================================================
	 */

	inline static public function getAsepriteAtlas(
		key:String,
		?parentFolder:String = null,
		?allowGPU:Bool = true
	):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic =
			image(
				key,
				parentFolder,
				allowGPU
			);

		if (imageLoaded == null)
			return null;

		var jsonPath:String =
			getPath(
				Language.getFileTranslation(
					'images/$key'
				) + '.json',
				TEXT,
				parentFolder,
				false
			);

		if (!OpenFlAssets.exists(jsonPath, TEXT))
		{
			trace(
				'Aseprite JSON not found: '
				+ jsonPath
			);

			return null;
		}

		return FlxAtlasFrames.fromTexturePackerJson(
			imageLoaded,
			jsonPath
		);
	}

	/*
	 * =========================================================
	 * SONG PATH
	 * =========================================================
	 */

	inline static public function formatToSongPath(path:String)
	{
		final invalidChars =
			~/[~&;:<>#\s]/g;

		final hideChars =
			~/[.,'"%?!]/g;

		return hideChars
			.replace(
				invalidChars.replace(
					path,
					'-'
				),
				''
			)
			.trim()
			.toLowerCase();
	}

	/*
	 * =========================================================
	 * SOUND CACHE
	 * =========================================================
	 */

	public static var currentTrackedSounds:Map<String, Sound> = [];

	public static function returnSound(
		key:String,
		?path:String,
		?modsAllowed:Bool = true,
		?beepOnNull:Bool = true
	):Sound
	{
		var file:String =
			getPath(
				Language.getFileTranslation(key)
				+ '.$SOUND_EXT',
				SOUND,
				path,
				false
			);

		if (!currentTrackedSounds.exists(file))
		{
			#if sys
			if (FileSystem.exists(file))
			{
				currentTrackedSounds.set(
					file,
					Sound.fromFile(file)
				);
			}
			else
			#end
			if (OpenFlAssets.exists(file, SOUND))
			{
				currentTrackedSounds.set(
					file,
					OpenFlAssets.getSound(file)
				);
			}
			else if (beepOnNull)
			{
				trace(
					'SOUND NOT FOUND: '
					+ key
					+ ', PATH: '
					+ path
				);

				FlxG.log.error(
					'SOUND NOT FOUND: '
					+ key
					+ ', PATH: '
					+ path
				);

				return FlxAssets.getSound(
					'flixel/sounds/beep'
				);
			}
		}

		localTrackedAssets.push(file);

		return currentTrackedSounds.get(file);
	}

	/*
	 * =========================================================
	 * LEGACY MOD FUNCTIONS
	 * =========================================================
	 *
	 * These are kept so other Psych Engine source files that
	 * reference Paths.mods(), modsJson(), etc. don't immediately
	 * fail to compile.
	 *
	 * They are NOT used by the BFEXEOPT asset resolver.
	 */

	#if MODS_ALLOWED

	inline static public function mods(
		key:String = ''
	)
	{
		return #if mobile
			Sys.getCwd() +
		#end
		'mods/' + key;
	}

	inline static public function modsJson(key:String)
		return modFolders('data/' + key + '.json');

	inline static public function modsVideo(key:String)
		return modFolders(
			'videos/'
			+ key
			+ '.'
			+ VIDEO_EXT
		);

	inline static public function modsSounds(
		path:String,
		key:String
	)
	{
		return modFolders(
			path
			+ '/'
			+ key
			+ '.'
			+ SOUND_EXT
		);
	}

	inline static public function modsImages(key:String)
		return modFolders(
			'images/'
			+ key
			+ '.png'
		);

	inline static public function modsXml(key:String)
		return modFolders(
			'images/'
			+ key
			+ '.xml'
		);

	inline static public function modsTxt(key:String)
		return modFolders(
			'images/'
			+ key
			+ '.txt'
		);

	inline static public function modsImagesJson(key:String)
		return modFolders(
			'images/'
			+ key
			+ '.json'
		);

	static public function modFolders(key:String)
	{
		if (
			Mods.currentModDirectory != null
			&& Mods.currentModDirectory.length > 0
		)
		{
			var fileToCheck:String =
				mods(
					Mods.currentModDirectory
					+ '/'
					+ key
				);

			if (FileSystem.exists(fileToCheck))
				return fileToCheck;

			#if linux
			else
			{
				var newPath:String =
					findFile(key);

				if (newPath != null)
					return newPath;
			}
			#end
		}

		for (mod in Mods.getGlobalMods())
		{
			var fileToCheck:String =
				mods(
					mod
					+ '/'
					+ key
				);

			if (FileSystem.exists(fileToCheck))
				return fileToCheck;

			#if linux
			else
			{
				var newPath:String =
					findFile(key);

				if (newPath != null)
					return newPath;
			}
			#end
		}

		return #if mobile
			Sys.getCwd() +
		#end
		('mods/' + key);
	}

	#if linux

	static function findFile(key:String):String
	{
		var targetParts:Array<String> =
			key
			.replace('\\', '/')
			.split('/');

		if (targetParts.length == 0)
			return null;

		var baseDir:String =
			targetParts.shift();

		var searchDirs:Array<String> = [
			mods(
				Mods.currentModDirectory
				+ '/'
				+ baseDir
			),
			mods(baseDir)
		];

		for (part in targetParts)
		{
			if (part == '')
				continue;

			var nextDir:String =
				findNodeInDirs(
					searchDirs,
					part
				);

			if (nextDir == null)
				return null;

			searchDirs = [nextDir];
		}

		return searchDirs[0];
	}

	static function findNodeInDirs(
		dirs:Array<String>,
		key:String
	):String
	{
		for (dir in dirs)
		{
			var node:String =
				findNode(dir, key);

			if (node != null)
				return dir + '/' + node;
		}

		return null;
	}

	static function findNode(
		dir:String,
		key:String
	):String
	{
		try
		{
			var allFiles:Array<String> =
				Paths.readDirectory(dir);

			var fileMap:Map<String, String> =
				new Map();

			for (file in allFiles)
				fileMap.set(
					file.toLowerCase(),
					file
				);

			return fileMap.get(
				key.toLowerCase()
			);
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	#end
	#end

	/*
	 * =========================================================
	 * FLXANIMATE
	 * =========================================================
	 */

	#if flxanimate

	public static function loadAnimateAtlas(
		spr:FlxAnimate,
		folderOrImg:Dynamic,
		spriteJson:Dynamic = null,
		animationJson:Dynamic = null
	)
	{
		var changedAnimJson:Bool = false;
		var changedAtlasJson:Bool = false;
		var changedImage:Bool = false;

		if (spriteJson != null)
		{
			changedAtlasJson = true;
			spriteJson = File.getContent(
				spriteJson
			);
		}

		if (animationJson != null)
		{
			changedAnimJson = true;
			animationJson = File.getContent(
				animationJson
			);
		}

		if (Std.isOfType(folderOrImg, String))
		{
			var originalPath:String =
				folderOrImg;

			for (i in 0...10)
			{
				var st:String = '$i';

				if (i == 0)
					st = '';

				if (!changedAtlasJson)
				{
					spriteJson =
						getTextFromFile(
							'images/'
							+ originalPath
							+ '/spritemap'
							+ st
							+ '.json'
						);

					if (spriteJson != null)
					{
						changedImage = true;
						changedAtlasJson = true;

						folderOrImg =
							image(
								originalPath
								+ '/spritemap'
								+ st
							);

						break;
					}
				}
				else if (
					fileExists(
						'images/'
						+ originalPath
						+ '/spritemap'
						+ st
						+ '.png',
						IMAGE
					)
				)
				{
					changedImage = true;

					folderOrImg =
						image(
							originalPath
							+ '/spritemap'
							+ st
						);

					break;
				}
			}

			if (!changedImage)
			{
				changedImage = true;
				folderOrImg =
					image(originalPath);
			}

			if (!changedAnimJson)
			{
				changedAnimJson = true;

				animationJson =
					getTextFromFile(
						'images/'
						+ originalPath
						+ '/Animation.json'
					);
			}
		}

		spr.loadAtlasEx(
			folderOrImg,
			spriteJson,
			animationJson
		);
	}

	#end

	/*
	 * =========================================================
	 * DIRECTORY READING
	 * =========================================================
	 */

	public static function readDirectory(
		directory:String
	):Array<String>
	{
		/*
		 * For the standalone BFEXEOPT build, we first try
		 * the real filesystem only when the requested path
		 * is actually a filesystem path.
		 */

		#if sys

		if (FileSystem.exists(directory))
			return FileSystem.readDirectory(
				directory
			);

		#end

		/*
		 * Packaged OpenFL assets.
		 */

		var dirs:Array<String> = [];

		for (
			dir in Assets.list()
				.filter(
					folder ->
						folder.startsWith(
							directory
						)
				)
		)
		{
			@:privateAccess
			for (
				library in
				lime.utils.Assets.libraries.keys()
			)
			{
				if (
					library != 'default'
					&& Assets.exists(
						'$library:$dir'
					)
					&& (
						!dirs.contains(
							'$library:$dir'
						)
						||
						!dirs.contains(dir)
					)
				)
				{
					dirs.push(
						'$library:$dir'
					);
				}
				else if (
					Assets.exists(dir)
					&& !dirs.contains(dir)
				)
				{
					dirs.push(dir);
				}
			}
		}

		return dirs.map(
			dir ->
				dir.substr(
					dir.lastIndexOf("/")
					+ 1
				)
		);
	}
}
