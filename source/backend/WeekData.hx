package backend;

import openfl.utils.Assets as OpenFlAssets;
import openfl.utils.AssetType;

import haxe.Json;

typedef WeekFile =
{
	var songs:Array<Dynamic>;
	var weekCharacters:Array<String>;
	var weekBackground:String;
	var weekBefore:String;
	var storyName:String;
	var weekName:String;
	var startUnlocked:Bool;
	var hiddenUntilUnlocked:Bool;
	var hideStoryMode:Bool;
	var hideFreeplay:Bool;
	var difficulties:String;
}

class WeekData
{
	public static var weeksLoaded:Map<String, WeekData> = new Map<String, WeekData>();
	public static var weeksList:Array<String> = [];

	/*
	 * BFEXEOPT content is packaged inside the APK:
	 *
	 * assets/BFEXEOPT/weeks/
	 */
	public var folder:String = 'BFEXEOPT';

	// JSON variables
	public var songs:Array<Dynamic>;
	public var weekCharacters:Array<String>;
	public var weekBackground:String;
	public var weekBefore:String;
	public var storyName:String;
	public var weekName:String;
	public var startUnlocked:Bool;
	public var hiddenUntilUnlocked:Bool;
	public var hideStoryMode:Bool;
	public var hideFreeplay:Bool;
	public var difficulties:String;

	public var fileName:String;

	public static function createWeekFile():WeekFile
	{
		var weekFile:WeekFile =
		{
			songs:
			[
				["Bopeebo", "face", [146, 113, 253]],
				["Fresh", "face", [146, 113, 253]],
				["Dad Battle", "face", [146, 113, 253]]
			],

			#if BASE_GAME_FILES
			weekCharacters: ['dad', 'bf', 'gf'],
			#else
			weekCharacters: ['bf', 'bf', 'gf'],
			#end

			weekBackground: 'stage',
			weekBefore: 'tutorial',
			storyName: 'Your New Week',
			weekName: 'Custom Week',
			startUnlocked: true,
			hiddenUntilUnlocked: false,
			hideStoryMode: false,
			hideFreeplay: false,
			difficulties: ''
		};

		return weekFile;
	}

	public function new(
		weekFile:WeekFile,
		fileName:String
	)
	{
		for (field in Reflect.fields(weekFile))
		{
			if (Reflect.fields(this).contains(field))
			{
				Reflect.setProperty(
					this,
					field,
					Reflect.getProperty(
						weekFile,
						field
					)
				);
			}
		}

		this.fileName = fileName;
		this.folder = 'BFEXEOPT';
	}

	/*
	 * =========================================================
	 * RELOAD WEEKS
	 * =========================================================
	 *
	 * The old Psych Engine version searched:
	 *
	 * mods/
	 * mods/<mod>/
	 * assets/shared/
	 *
	 * BFEXEOPT instead uses:
	 *
	 * assets/BFEXEOPT/weeks/
	 *
	 * weekList.txt:
	 *
	 * assets/BFEXEOPT/weeks/weekList.txt
	 */

	public static function reloadWeekFiles(
		isStoryMode:Null<Bool> = false
	)
	{
		weeksList = [];
		weeksLoaded.clear();

		var weekListPath:String =
			Paths.getGameContentPath(
				'weeks/weekList.txt'
			);

		/*
		 * -----------------------------------------------------
		 * Read BFEXEOPT weekList.txt
		 * -----------------------------------------------------
		 */

		var sexList:Array<String> = [];

		if (
			OpenFlAssets.exists(
				weekListPath,
				AssetType.TEXT
			)
		)
		{
			sexList =
				CoolUtil.coolTextFile(
					weekListPath
				);
		}

		/*
		 * -----------------------------------------------------
		 * Load every week listed in weekList.txt
		 * -----------------------------------------------------
		 */

		for (weekNameEntry in sexList)
		{
			var weekName:String =
				weekNameEntry.trim();

			if (weekName.length == 0)
				continue;

			if (weeksLoaded.exists(weekName))
				continue;

			var filePath:String =
				Paths.getGameContentPath(
					'weeks/$weekName.json'
				);

			var week:WeekFile =
				getWeekFile(filePath);

			if (week == null)
				continue;

			var weekFile:WeekData =
				new WeekData(
					week,
					weekName
				);

			/*
			 * Story Mode filtering.
			 */

			if (
				isStoryMode == null
				|| (
					isStoryMode
					&& !weekFile.hideStoryMode
				)
				|| (
					!isStoryMode
					&& !weekFile.hideFreeplay
				)
			)
			{
				weekFile.folder = 'BFEXEOPT';

				weeksLoaded.set(
					weekName,
					weekFile
				);

				weeksList.push(
					weekName
				);
			}
		}

		/*
		 * -----------------------------------------------------
		 * Fallback scan
		 * -----------------------------------------------------
		 *
		 * If weekList.txt is missing or incomplete, scan the
		 * packaged BFEXEOPT week directory using the OpenFL
		 * asset list.
		 */

		var allAssets:Array<String> =
			OpenFlAssets.list(
				AssetType.TEXT
			);

		var prefix:String =
			Paths.getGameContentPath(
				'weeks/'
			);

		for (asset in allAssets)
		{
			if (!asset.startsWith(prefix))
				continue;

			if (!asset.endsWith('.json'))
				continue;

			var fileName:String =
				asset.substr(
					prefix.length,
					asset.length
					- prefix.length
					- 5
				);

			if (fileName.length == 0)
				continue;

			if (weeksLoaded.exists(fileName))
				continue;

			var week:WeekFile =
				getWeekFile(asset);

			if (week == null)
				continue;

			var weekFile:WeekData =
				new WeekData(
					week,
					fileName
				);

			weekFile.folder = 'BFEXEOPT';

			if (
				isStoryMode == null
				|| (
					isStoryMode
					&& !weekFile.hideStoryMode
				)
				|| (
					!isStoryMode
					&& !weekFile.hideFreeplay
				)
			)
			{
				weeksLoaded.set(
					fileName,
					weekFile
				);

				weeksList.push(
					fileName
				);
			}
		}
	}

	/*
	 * =========================================================
	 * ADD WEEK
	 * =========================================================
	 *
	 * Kept because other Psych Engine code may call it.
	 */

	private static function addWeek(
		weekToCheck:String,
		path:String,
		directory:String,
		i:Int,
		originalLength:Int
	)
	{
		if (weeksLoaded.exists(weekToCheck))
			return;

		var week:WeekFile =
			getWeekFile(path);

		if (week == null)
			return;

		var weekFile:WeekData =
			new WeekData(
				week,
				weekToCheck
			);

		weekFile.folder = 'BFEXEOPT';

		if (
			(
				PlayState.isStoryMode
				&& !weekFile.hideStoryMode
			)
			||
			(
				!PlayState.isStoryMode
				&& !weekFile.hideFreeplay
			)
		)
		{
			weeksLoaded.set(
				weekToCheck,
				weekFile
			);

			weeksList.push(
				weekToCheck
			);
		}
	}

	/*
	 * =========================================================
	 * READ WEEK JSON
	 * =========================================================
	 */

	private static function getWeekFile(
		path:String
	):WeekFile
	{
		var rawJson:String = null;

		/*
		 * APK / OpenFL asset.
		 */
		if (
			OpenFlAssets.exists(
				path,
				AssetType.TEXT
			)
		)
		{
			try
			{
				rawJson =
					OpenFlAssets.getText(
						path
					);
			}
			catch (e:Dynamic)
			{
				trace(
					'Failed to read week file: '
					+ path
				);
			}
		}

		if (
			rawJson != null
			&& rawJson.length > 0
		)
		{
			try
			{
				return cast tjson.TJSON.parse(
					rawJson
				);
			}
			catch (e:Dynamic)
			{
				trace(
					'Failed to parse week JSON: '
					+ path
				);

				trace(e);
			}
		}

		return null;
	}

	/*
	 * =========================================================
	 * CURRENT WEEK
	 * =========================================================
	 */

	public static function getWeekFileName():String
	{
		if (
			weeksList == null
			|| weeksList.length == 0
		)
		{
			return null;
		}

		if (
			PlayState.storyWeek < 0
			|| PlayState.storyWeek >= weeksList.length
		)
		{
			return weeksList[0];
		}

		return weeksList[
			PlayState.storyWeek
		];
	}

	public static function getCurrentWeek():WeekData
	{
		var weekName:String =
			getWeekFileName();

		if (weekName == null)
			return null;

		return weeksLoaded.get(
			weekName
		);
	}

	/*
	 * =========================================================
	 * DIRECTORY
	 * =========================================================
	 *
	 * The active content is always BFEXEOPT.
	 */

	public static function setDirectoryFromWeek(
		?data:WeekData = null
	)
	{
		Mods.currentModDirectory =
			'BFEXEOPT';

		if (data != null)
		{
			data.folder = 'BFEXEOPT';
		}
	}
}
