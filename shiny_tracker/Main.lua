Main = {}

-- The latest version of the tracker. Should be updated with each PR.
Main.Version = { major = "0", minor = "1", patch = "0" }

Main.CreditsList = { -- based on the PokemonBizhawkLua project by MKDasher
	CreatedBy = "Trevorrl",
	Contributors = { "Besteon", "UTDZac", "Fellshadow", "ninjafriend", "OnlySpaghettiCode", "bdjeffyp", "Amber Cyprian", "thisisatest", "kittenchilly", "Aeiry", "TheRealTaintedWolf", "Kurumas", "davidhouweling", "AKD", "rcj001", "GB127", },
}

Main.EMU = {
	MGBA = "mGBA", -- Lua 5.4
	BIZHAWK_OLD = "Bizhawk Old", -- Non-compatible Bizhawk version
	BIZHAWK28 = "Bizhawk 2.8", -- Lua 5.1
	BIZHAWK29 = "Bizhawk 2.9", -- Lua 5.4
	BIZHAWK_FUTURE = "Bizhawk Future", -- Lua 5.4
}

-- Returns false if an error occurs that completely prevents the Tracker from functioning; otherwise, returns true
function Main.Initialize()
	Main.TrackerVersion = string.format("%s.%s.%s", Main.Version.major, Main.Version.minor, Main.Version.patch)
	Main.Version.remindMe = true
	Main.Version.latestAvailable = Main.TrackerVersion
	Main.Version.releaseNotes = {}
	Main.Version.dateChecked = ""
	Main.Version.showUpdate = false
	-- Informs the Tracker to perform an update the next time that Tracker is loaded.
	Main.Version.updateAfterRestart = false
	-- Used to display the release notes once, after each new version update. Defaults true for updates that didn't have this
	Main.Version.showReleaseNotes = true

	Main.MetaSettings = {}
	Main.CrashReport = {
		crashedOccurred = false,
	}
	Main.currentSeed = 1
	Main.loadNextSeed = false
	Main.hasRunOnce = false

	-- Set seed based on epoch seconds; required for other features
	math.randomseed(os.time() % 100000 * 17) -- seed was acting wonky (read as: predictable), so made it wonkier
	math.random() -- required first call, for some reason

	Main.SetupEmulatorInfo()

	-- Check the version of BizHawk that is running
	if Main.emulator == Main.EMU.BIZHAWK_OLD then
		print("> ERROR: This version of BizHawk is not supported for use with the Tracker.")
		print("> Please update to version 2.8 or higher.")
		Main.DisplayError("This version of BizHawk is not supported for use with the Tracker.\n\nPlease update to version 2.8 or higher.")
		return false
	end

	if not Main.SetupFileManager() then
		return false
	end

	if FileManager.slash == "\\" then
		Main.OS = "Windows"
	else
		Main.OS = "Linux"
	end

	-- Check if the Tracker was previously running; used to prevent self-update until a full restart
	if Program ~= nil then
		Main.hasRunOnce = (Program.hasRunOnce == true)
	end

	for _, luafile in ipairs(FileManager.LuaCode) do
		if not FileManager.loadLuaFile(luafile.filepath) then
			return false
		end
	end
	if not FileManager.loadLuaFile(FileManager.Files.UPDATE_OR_INSTALL) then
		return false
	end

	Main.LoadSettings()
	Resources.initialize()

	print(string.format("Shiny Tracker v%s successfully loaded", Main.TrackerVersion))

	-- Get the quickload files just once to be used in several places during start-up, removed later
	Main.ReadAttemptsCount()
	Main.CheckForVersionUpdate()

	return true
end

-- Waits for game to be loaded, then begins the Main loop. From here after, do NOT trust values from Shiny-Tracker.lua
function Main.Run()
	if Main.IsOnBizhawk() then
		-- mGBA hates infinite loops. This "wait for startup" is handled differently
		if GameSettings.getRomName() == nil or GameSettings.getRomName() == "Null" then
			print("> Waiting for a game ROM to be loaded... (File -> Open ROM)")
		end
		local romLoaded = false
		while not romLoaded do
			if GameSettings.getRomName() ~= nil and GameSettings.getRomName() ~= "Null" then
				romLoaded = true
			end
			Main.frameAdvance()
		end
	else
		-- mGBA specific callbacks
		if Main.startCallbackId == nil then
			Main.startCallbackId = callbacks:add("start", Main.Run)
		end
		if Main.resetCallbackId == nil then
			 -- start doesn't get trigged on-reset
			Main.resetCallbackId = callbacks:add("reset", function()
				-- Emulator is closing as expected; no crash
				CrashRecoveryScreen.logCrashReport(false)
				Main.Run()
			end)
		end
		if Main.stopCallbackId == nil then
			Main.stopCallbackId = callbacks:add("stop", function()
				-- Emulator is closing as expected; no crash
				CrashRecoveryScreen.logCrashReport(false)
				MGBA.removeActiveRunCallbacks()
			end)
		end
		if Main.shutdownCallbackId == nil then
			Main.shutdownCallbackId = callbacks:add("shutdown", function()
				-- Emulator is closing as expected; no crash
				CrashRecoveryScreen.logCrashReport(false)
				MGBA.removeActiveRunCallbacks()
			end)
		end
		if Main.crashedCallbackId == nil then
			Main.crashedCallbackId = callbacks:add("crashed", function()
				CrashRecoveryScreen.logCrashReport(true)
				MGBA.removeActiveRunCallbacks()
			end)
		end

		if emu == nil then
			print("> Waiting for a game ROM to be loaded... (mGBA Emulator -> File -> Load ROM...)")
			return
		else
			MGBA.setupActiveRunCallbacks()
		end
	end

	Memory.initialize()
	GameSettings.initialize()
	Resources.autoDetectForeignLanguage()

	-- If the loaded game is unsupported, remove the Tracker padding but continue to let the game play.
	if GameSettings.gamename == nil or GameSettings.gamename == "Unsupported Game" then
		print("> Unsupported Game detected, please load a supported game ROM")
		print("> Check the README.txt file in the tracker folder for supported games")
		if Main.IsOnBizhawk() then
			client.SetGameExtraPadding(0, 0, 0, 0)
		end
		return
	end

	-- After a game is successfully loaded, then initialize the remaining Tracker files
	FileManager.setupErrorLog()
	Main.ReadAttemptsCount() -- re-check attempts count if different game is loaded
	FileManager.executeEachFile("initialize") -- initialize all tracker files

	-- Final garbage collection prior to game loops beginning
	collectgarbage()

	Main.CrashReport = CrashRecoveryScreen.readCrashReport()
	-- After crash report is read in, establish a new crash report; treat as "crashed" until emulator safely exits
	CrashRecoveryScreen.logCrashReport(true)

	if Main.IsOnBizhawk() then
		event.onexit(Program.HandleExit, "HandleExit")
		event.onconsoleclose(function()
			-- Emulator is closing as expected; no crash
			CrashRecoveryScreen.logCrashReport(false)
		end, "SafelyCloseWithoutCrash")

		-- Bizhawk 2.9+ doesn't properly refocus onto the emulator window after Quickload
		if Options["Refocus emulator after load"] and Main.emulator ~= Main.EMU.BIZHAWK28 and not Drawing.AnimatedPokemon:isVisible() then
			Program.focusBizhawkWindow()
		end

		Main.AfterStartupScreenRedirect()
		Main.hasRunOnce = true
		Program.hasRunOnce = true

		-- Allow emulation frame after frame until a new seed is quickloaded or a tracker update is requested
		while not Main.loadNextSeed and not Main.updateRequested do
			xpcall(function() Program.mainLoop() end, FileManager.logError)
			Main.frameAdvance()
		end

		if Main.updateRequested then
			UpdateScreen.performAutoUpdate()
		end
	else
		MGBA.printStartupInstructions()
	end
end

-- Check which emulator is in use
function Main.SetupEmulatorInfo()
	local frameAdvanceFunc
	if console.createBuffer == nil then -- This function doesn't exist in Bizhawk, only mGBA
		Main.emulator = Main.GetBizhawkVersion()
		Main.supportsSpecialChars = (Main.emulator == Main.EMU.BIZHAWK29 or Main.emulator == Main.EMU.BIZHAWK_FUTURE)
		frameAdvanceFunc = function()
			emu.frameadvance()
		end
	else
		Main.emulator = Main.EMU.MGBA
		Main.supportsSpecialChars = true
		frameAdvanceFunc = function()
			-- emu:runFrame() -- don't use this, use callbacks:add("frame", func) instead
		end
	end
	Main.frameAdvance = frameAdvanceFunc
end

function Main.IsOnBizhawk()
	return Main.emulator == Main.EMU.BIZHAWK28 or Main.emulator == Main.EMU.BIZHAWK29 or Main.emulator == Main.EMU.BIZHAWK_FUTURE
end

-- Checks if Bizhawk version is 2.8 or later
function Main.GetBizhawkVersion()
	-- Significantly older Bizhawk versions don't have a client.getversion function
	if client == nil or client.getversion == nil then return Main.EMU.BIZHAWK_OLD end

	-- Check the major and minor version numbers separately, to account for versions such as "2.10"
	local major, minor = string.match(client.getversion(), "(%d+)%.(%d+)")

	local majorNumber = tonumber(tostring(major)) or 0 -- tostring first allows nil input
	local minorNumber = tonumber(tostring(minor)) or 0

	if majorNumber >= 3 then
		-- Versions 3.0 or higher (not yet released)
		return Main.EMU.BIZHAWK_FUTURE
	elseif majorNumber < 2 or minorNumber < 8 then
		-- Versions 2.7 or lower (old, incompatible releases)
		return Main.EMU.BIZHAWK_OLD
	elseif minorNumber == 8 then
		return Main.EMU.BIZHAWK28
	elseif minorNumber == 9 then
		return Main.EMU.BIZHAWK29
	else
		-- Versions 2.10+
		return Main.EMU.BIZHAWK_FUTURE
	end
end

function Main.SetupFileManager()
	local slash = package.config:sub(1,1) or "\\" -- Windows is \ and Linux is /
	local fileManagerPath = "shiny_tracker" .. slash .. "FileManager.lua"

	local fileManagerFile = io.open(fileManagerPath, "r")
	if fileManagerFile == nil then
		fileManagerPath = (ShinyTracker.workingDir or "") .. fileManagerPath
		fileManagerFile = io.open(fileManagerPath, "r")
		if fileManagerFile == nil then
			local err1 = string.format("Unable to load a Tracker code file: %s", fileManagerPath)
			local err2 = "Make sure all of the Tracker's code files are still together."
			print("> " .. err1)
			print("> " .. err2)
			Main.DisplayError(err1 .. "\n\n" .. err2)
			return false
		end
	end
	io.close(fileManagerFile)

	dofile(fileManagerPath)
	FileManager.setupWorkingDirectory()

	return true
end

-- Displays a given error message in a pop-up dialogue box
function Main.DisplayError(errMessage)
	if not Main.IsOnBizhawk() then return end -- Only Bizhawk allows popup form windows

	client.pause()
	local formTitle = string.format("[v%s] Whoops, there's been an issue!", Main.TrackerVersion)
	local form = forms.newform(400, 150, formTitle, function() client.unpause() end)
	local actualLocation = client.transformPoint(100, 50)
	forms.setproperty(form, "Left", client.xpos() + actualLocation['x'] )
	forms.setproperty(form, "Top", client.ypos() + actualLocation['y'] + 64) -- so we are below the ribbon menu

	forms.label(form, errMessage, 18, 10, 350, 65)
	forms.button(form, "Close", function()
		client.unpause()
		forms.destroy(form)
	end, 155, 80)
end

function Main.AfterStartupScreenRedirect()
	if not Main.IsOnBizhawk() then
		return
	end

	if Main.CrashReport and Main.CrashReport.crashedOccurred then
		CrashRecoveryScreen.previousScreen = Program.currentScreen
		Program.changeScreenView(CrashRecoveryScreen)
		return
	end

	if Main.Version.showReleaseNotes then
		UpdateScreen.showNotes = true
		Main.Version.showReleaseNotes = false
		UpdateScreen.buildOutPagedButtons()
		UpdateScreen.refreshButtons()
		Main.SaveSettings(true)
	end

	if Main.Version.updateAfterRestart and not Main.hasRunOnce then
		UpdateScreen.currentState = UpdateScreen.States.NOT_UPDATED
		Program.changeScreenView(UpdateScreen)
	end
end

-- Determines if there is an update to the current Tracker version
-- Intentionally will only check against Major and Minor version updates,
-- allowing patches to seamlessly update without bothering every end-user
-- forcedCheck: if true, will force an update check (please use sparingly)
function Main.CheckForVersionUpdate(forcedCheck)
	-- Update check not supported on Linux Bizhawk 2.8, Lua 5.1
	if Main.emulator == Main.EMU.BIZHAWK28 and Main.OS ~= "Windows" then
		return
	end

	-- %x - Date representation for current locale (Standard date string), eg. "25/04/07"
	local todaysDate = os.date("%x")

	-- Only notify about updates once per day. Note: 1st run of bizhawk results in date being an integer not a string
	if forcedCheck or tostring(todaysDate) ~= tostring(Main.Version.dateChecked) then
		-- Track that an update was checked today, so no additional api calls are performed today
		Main.Version.dateChecked = todaysDate

		Utils.tempDisableBizhawkSound()

		local updatecheckCommand = string.format('curl "%s" --ssl-no-revoke', FileManager.Urls.VERSION)
		local success, fileLines = FileManager.tryOsExecute(updatecheckCommand)
		if success then
			local response = table.concat(fileLines, "\n")

			if response then
				Main.updateReleaseNotes(response)
			end

			-- Get version number formatted as [major].[minor].[patch]
			local major, minor, patch = string.match(response or "", '"tag_name":%s+"%w+(%d+)%.(%d+)%.(%d+)"')
			major = major or Main.Version.major
			minor = minor or Main.Version.minor
			patch = patch or Main.Version.patch

			local latestReleasedVersion = string.format("%s.%s.%s", major, minor, patch)

			-- Ignore patch numbers when checking to notify for a new release
			local newVersionAvailable = not Main.isOnLatestVersion(string.format("%s.%s.0", major, minor))

			-- Other than choosing to be reminded, only notify when a release comes out that is different than the last recorded newest release
			local shouldNotify = Main.Version.remindMe or Main.Version.latestAvailable ~= latestReleasedVersion

			-- Determine if a major version update is available and notify the user accordingly
			if newVersionAvailable and shouldNotify then
				Main.Version.showUpdate = true
			end

			-- Track the latest available version
			Main.Version.latestAvailable = latestReleasedVersion
		end

		Utils.tempEnableBizhawkSound()
	end

	Main.SaveSettings(true)
end

-- If no release notes have been retrieved yet (update check was skipped), then get those and parse them
-- Searches a response body for the "# Release Notes" area, and gets a list of changes
function Main.updateReleaseNotes(response)
	if not response then
		Utils.tempDisableBizhawkSound()
		local updatecheckCommand = string.format('curl "%s" --ssl-no-revoke', FileManager.Urls.VERSION)
		local success, fileLines = FileManager.tryOsExecute(updatecheckCommand)
		if success then
			response = table.concat(fileLines, "\n")
		end
		Utils.tempEnableBizhawkSound()
	end

	-- Parse the release notes
	Main.Version.releaseNotes = {}

	-- The body of the release post is contained between 'body' and 'mentions_count'
	local body = string.match(response or "", '"body":%s+"(.+)".-"mentions_count"')
	if body == nil then
		return
	end
	body = Utils.formatSpecialCharacters(body)

	local formatInput = function(str)
		-- Remove hyperlinks, format: [text](url) -> [text]
		str = str:gsub("%[([^%]]-)%]%(.-%)", "%1")
		-- Remove bold, format: **text** -> text
		str = str:gsub("%*%*(.-)%*%*", "%1")
		-- Fix double-quotes, format: \"text\" -> "text"
		str = str:gsub('\\"(.-)\\"', '"%1"')
		return str
	end

	local notesFound = false
	for line in string.gmatch(body .. '\\r\\n', '(.-)\\r\\n') do
		if notesFound then
			-- Include all release notes up until the mention of "version changelog"
			if line:lower():find("version.changelog") then -- . being a wild card match
				break
			end
			table.insert(Main.Version.releaseNotes, formatInput(line))
		elseif line:lower():find("# release notes") then
			notesFound = true
		end
	end
end

-- Checks the current version of the Tracker against the version of the latest release, true if greater/equal; false otherwise.
-- 'versionToCheck': optional, if provided the version check will compare current version against the one provided.
function Main.isOnLatestVersion(versionToCheck)
	versionToCheck = versionToCheck or Main.Version.latestAvailable

	if Main.TrackerVersion == versionToCheck then
		return true
	end

	local currMajor, currMinor, currPatch = string.match(Main.TrackerVersion, "(%d+)%.(%d+)%.(%d+)")
	local latestMajor, latestMinor, latestPatch = string.match(versionToCheck, "(%d+)%.(%d+)%.(%d+)")

	currMajor, currMinor, currPatch = (tonumber(currMajor) or 0), (tonumber(currMinor) or 0), (tonumber(currPatch) or 0)
	latestMajor, latestMinor, latestPatch = (tonumber(latestMajor) or 0), (tonumber(latestMinor) or 0), (tonumber(latestPatch) or 0)

	if currMajor > latestMajor then
		return true
	elseif currMajor == latestMajor then
		if currMinor > latestMinor then
			return true
		elseif currMinor == latestMinor then
			if currPatch > latestPatch then
				return true
			end
		end
	end

	return false
end

function Main.GetAttemptsFile()
	local attemptsFileName, attemptsFilePath

	-- Otherwise, check if an attempts file exists based on the ROM file name (w/o numbers)
	-- The case when using Quickload method: premade ROMS
	local quickloadRomName
	-- If on Bizhawk, can just get the currently loaded ROM
	-- mGBA however does NOT return the filename, so need to use the quickload folder files
	if Main.IsOnBizhawk() then
		quickloadRomName = GameSettings.getRomName() or ""
	else
		quickloadRomName = ""
	end

	local romprefix = string.match(quickloadRomName, '[^0-9]+') or "" -- remove numbers

	attemptsFileName = string.format("%s %s%s", romprefix, FileManager.PostFixes.ATTEMPTS_FILE, FileManager.Extensions.ATTEMPTS)
	attemptsFilePath = FileManager.getPathIfExists(attemptsFileName)

	-- Otherwise, create an attempts file using the name provided by the emulator itself
	if attemptsFilePath == nil then
		attemptsFilePath = FileManager.prependDir(string.format("%s %s%s", romprefix, FileManager.PostFixes.ATTEMPTS_FILE, FileManager.Extensions.ATTEMPTS))
	end

	return attemptsFilePath
end

-- Determines what attempts # the play session is on, either from pre-existing file or from Bizhawk's ROM Name
function Main.ReadAttemptsCount()
	local filepath = Main.GetAttemptsFile()
	local attemptsRead = io.open(filepath, "r")

	-- First check if a matching "attempts file" already exists, if so read from that
	if attemptsRead ~= nil then
		local attemptsText = attemptsRead:read("*a")
		attemptsRead:close()
		if attemptsText ~= nil and tonumber(attemptsText) ~= nil then
			Main.currentSeed = tonumber(attemptsText)
		end
	elseif Options["Use premade ROMs"] then
		if Main.IsOnBizhawk() then -- mostly for Bizhawk
			local romname = GameSettings.getRomName() or ""
			local romnumber = string.match(romname, '[0-9]+') or "1"
			if romnumber ~= "1" then
				Main.currentSeed = tonumber(romnumber)
			end
		elseif Options.FILES["ROMs Folder"] == nil or Options.FILES["ROMs Folder"] == "" then -- mostly for mGBA
			local smallestSeedNumber = Main.FindSmallestSeedFromQuickloadFiles()
			if smallestSeedNumber ~= -1 then
				Main.currentSeed = smallestSeedNumber
			end
		end
	end
	-- Otherwise, leave the attempts count at default, which is 1
end

function Main.WriteAttemptsCountToFile(filepath, attemptsCount)
	attemptsCount = attemptsCount or Main.currentSeed

	local attemptsWrite = io.open(filepath, "w")
	if attemptsWrite ~= nil then
		attemptsWrite:write(attemptsCount)
		attemptsWrite:close()
	end
end

-- Get the user settings saved on disk and create the base Settings object; returns true if successfully reads in file
function Main.LoadSettings()
	local settings = nil

	local file = io.open(FileManager.prependDir(FileManager.Files.SETTINGS))
	if file ~= nil then
		settings = Inifile.parse(file:read("*a"), "memory")
		io.close(file)
	end

	if settings == nil then
		return false
	end

	-- Keep the meta data for saving settings later in a specified order
	Main.MetaSettings = settings

	-- [CONFIG]
	if settings.config ~= nil then
		if settings.config.RemindMeLater ~= nil then
			Main.Version.remindMe = settings.config.RemindMeLater
		end
		if settings.config.LatestAvailableVersion ~= nil then
			Main.Version.latestAvailable = settings.config.LatestAvailableVersion
		end
		if settings.config.DateLastChecked ~= nil then
			Main.Version.dateChecked = settings.config.DateLastChecked
		end
		if settings.config.ShowUpdateNotification ~= nil then
			Main.Version.showUpdate = settings.config.ShowUpdateNotification
		end
		if settings.config.UpdateAfterRestart ~= nil then
			Main.Version.updateAfterRestart = settings.config.UpdateAfterRestart
		end
		if settings.config.ShowReleaseNotes ~= nil then
			Main.Version.showReleaseNotes = settings.config.ShowReleaseNotes
		end

		for configKey, _ in pairs(Options.FILES) do
			local configValue = settings.config[string.gsub(configKey, " ", "_")]
			if configValue ~= nil then
				Options.FILES[configKey] = configValue
			end
		end
	end

	-- [TRACKER]
	if settings.tracker ~= nil then
		for _, optionKey in ipairs(Constants.OrderedLists.OPTIONS) do
			local optionValue = settings.tracker[string.gsub(optionKey, " ", "_")]
			if optionValue ~= nil then
				Options[optionKey] = optionValue
			end
		end
	end
	UpdateOrInstall.Dev.enabled = (Options["Dev branch updates"] == true)

	-- [CONTROLS]
	if settings.controls ~= nil then
		for controlKey, _ in pairs(Options.CONTROLS) do
			local controlValue = settings.controls[string.gsub(controlKey, " ", "_")]
			if controlValue ~= nil then
				Options.CONTROLS[controlKey] = controlValue
			end
		end
	end

	-- [THEME]
	if settings.theme ~= nil then
		for _, colorkey in ipairs(Constants.OrderedLists.THEMECOLORS) do
			local color_hexval = settings.theme[string.gsub(colorkey, " ", "_")]
			if color_hexval ~= nil then
				Theme.COLORS[colorkey] = 0xFF000000 + tonumber(color_hexval, 16)
			end
		end

		local enableMoveTypes = settings.theme.MOVE_TYPES_ENABLED
		if enableMoveTypes ~= nil then
			Theme.MOVE_TYPES_ENABLED = enableMoveTypes
			Theme.Buttons.MoveTypeEnabled.toggleState = not enableMoveTypes -- Show the opposite of the Setting, can't change existing theme strings
		end

		local enableTextShadows = settings.theme.DRAW_TEXT_SHADOWS
		if enableTextShadows ~= nil then
			Theme.DRAW_TEXT_SHADOWS = enableTextShadows
			Theme.Buttons.DrawTextShadows.toggleState = enableTextShadows
		end
	end

	return true
end

-- Saves the user settings on to disk
function Main.SaveSettings(forced)
	-- Don't bother saving to a file if nothing has changed
	if not forced and not Theme.settingsUpdated then
		return
	end

	local settings = Main.MetaSettings

	if settings == nil then settings = {} end
	if settings.config == nil then settings.config = {} end
	if settings.tracker == nil then settings.tracker = {} end
	if settings.controls == nil then settings.controls = {} end
	if settings.theme == nil then settings.theme = {} end

	-- [CONFIG]
	settings.config.RemindMeLater = Main.Version.remindMe
	settings.config.LatestAvailableVersion = Main.Version.latestAvailable
	settings.config.DateLastChecked = Main.Version.dateChecked
	settings.config.ShowUpdateNotification = Main.Version.showUpdate
	settings.config.UpdateAfterRestart = Main.Version.updateAfterRestart
	settings.config.ShowReleaseNotes = Main.Version.showReleaseNotes

	for configKey, _ in pairs(Options.FILES) do
		local encodedKey = string.gsub(configKey, " ", "_")
		settings.config[encodedKey] = Options.FILES[configKey]
	end

	-- [TRACKER]
	for _, optionKey in ipairs(Constants.OrderedLists.OPTIONS) do
		local encodedKey = string.gsub(optionKey, " ", "_")
		settings.tracker[encodedKey] = Options[optionKey]
	end

	-- [CONTROLS]
	for _, controlKey in ipairs(Constants.OrderedLists.CONTROLS) do
		local encodedKey = string.gsub(controlKey, " ", "_")
		settings.controls[encodedKey] = Options.CONTROLS[controlKey]
	end

	-- [THEME]
	for _, colorkey in ipairs(Constants.OrderedLists.THEMECOLORS) do
		local encodedKey = string.gsub(colorkey, " ", "_")
		settings.theme[encodedKey] = string.upper(string.sub(string.format("%#x", Theme.COLORS[colorkey]), 5))
	end
	settings.theme["MOVE_TYPES_ENABLED"] = Theme.MOVE_TYPES_ENABLED
	settings.theme["DRAW_TEXT_SHADOWS"] = Theme.DRAW_TEXT_SHADOWS

	Inifile.save(FileManager.prependDir(FileManager.Files.SETTINGS), settings)
	Theme.settingsUpdated = false
end

function Main.SetMetaSetting(section, key, value)
	if section == nil or key == nil or value == nil or section == "" or key == "" then return end
	if Main.MetaSettings[section] == nil then
		Main.MetaSettings[section] = {}
	end
	Main.MetaSettings[section][key] = value
end

function Main.RemoveMetaSetting(section, key)
	if section == nil or key == nil or section == "" or key == "" then return end
	if Main.MetaSettings[section] ~= nil then
		Main.MetaSettings[section][key] = nil
	end
end
