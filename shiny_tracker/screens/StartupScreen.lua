StartupScreen = {}

StartupScreen.Buttons = {
	SettingsGear = {
		type = Constants.ButtonTypes.PIXELIMAGE,
		image = Constants.PixelImages.GEAR,
		box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 130, 8, 7, 7 },
		onClick = function(self) Program.changeScreenView(NavigationMenu) end
	},
	PokemonIcon = {
		type = Constants.ButtonTypes.POKEMON_ICON,
		clickableArea = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 100, Constants.SCREEN.MARGIN + 14, 31, 28 },
		box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 40, Constants.SCREEN.MARGIN + 10, 64, 64 },
		pokemonID = 0,
		getIconId = function(self) return self.pokemonID, SpriteData.Types.Walk end,
		onClick = function(self) StartupScreen.openChoosePokemonWindow() end
	},
	ResetsCount = {
		type = Constants.ButtonTypes.NO_BORDER,
		getText = function(self) return tostring(Main.currentSeed) or Constants.BLANKLINE end,
		textSize = 24,
		box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 45, Constants.SCREEN.MARGIN + 60, 33, 11 },
		isVisible = function() return Main.currentSeed > 1 end,
		onClick = function(self) StreamerScreen.openEditResetsWindow() end
	}
}

function StartupScreen.initialize()
	StartupScreen.setPokemonIcon(Options["Startup Pokemon displayed"])

	for _, button in pairs(StartupScreen.Buttons) do
		if button.textColor == nil then
			button.textColor = "Default text"
		end
		if button.boxColors == nil then
			button.boxColors = { "Upper box border", "Upper box background" }
		end
	end

	StartupScreen.refreshButtons()

	-- Output to console the Tracker data load status to help with troubleshooting
	if Tracker.LoadStatus ~= nil then
		local loadStatusMessage = Resources.StartupScreen[Tracker.LoadStatus]
		if loadStatusMessage then
			print(string.format("> %s: %s", Resources.StartupScreen.TrackedDataMsgLabel, loadStatusMessage))
		end
	end
end

function StartupScreen.refreshButtons()
	for _, button in pairs(StartupScreen.Buttons) do
		if type(button.updateSelf) == "function" then
			button:updateSelf()
		end
	end
end

function StartupScreen.setPokemonIcon(displayOption)
	local pokemonID = Utils.randomPokemonID()

	if displayOption == Options.StartupIcon.random then
		pokemonID = Utils.randomPokemonID()
		Options["Startup Pokemon displayed"] = Options.StartupIcon.random
	elseif displayOption == Options.StartupIcon.none then
		pokemonID = 0
		Options["Startup Pokemon displayed"] = Options.StartupIcon.none
	else
		-- The option is a pokemonID already
		local id = tonumber(displayOption) or -1
		if PokemonData.isImageIDValid(id) then
			pokemonID = id
			Options["Startup Pokemon displayed"] = pokemonID
		end
	end

	if pokemonID ~= nil then
		StartupScreen.Buttons.PokemonIcon.pokemonID = pokemonID
	end
end

function StartupScreen.openChoosePokemonWindow()
	local form = Utils.createBizhawkForm(Resources.StartupScreen.PromptChooseAPokemonTitle, 330, 145)

	local dropdownOptions = {
		string.format("-- %s", Resources.StartupScreen.PromptChooseAPokemonByRandom),
		string.format("-- %s", Resources.StartupScreen.PromptChooseAPokemonNone),
	}

	local allPokemon = PokemonData.namesToList()
	for _, opt in ipairs(dropdownOptions) do
		table.insert(allPokemon, opt)
	end
	table.insert(allPokemon, "...................................") -- A spacer to separate special options

	forms.label(form,Resources.StartupScreen.PromptChooseAPokemonDesc, 49, 10, 250, 20)
	local pokedexDropdown = forms.dropdown(form, {["Init"]="Loading Pokedex"}, 50, 30, 145, 30)
	forms.setdropdownitems(pokedexDropdown, allPokemon, true) -- true = alphabetize the list
	forms.setproperty(pokedexDropdown, "AutoCompleteSource", "ListItems")
	forms.setproperty(pokedexDropdown, "AutoCompleteMode", "Append")

	local initialChoice
	if Options["Startup Pokemon displayed"] == Options.StartupIcon.random then
		initialChoice = dropdownOptions[2]
	elseif Options["Startup Pokemon displayed"] == Options.StartupIcon.none then
		initialChoice = dropdownOptions[1]
	else
		initialChoice = PokemonData.Pokemon[Options["Startup Pokemon displayed"] or "1"].name
	end
	forms.settext(pokedexDropdown, initialChoice)

	forms.button(form, Resources.AllScreens.Save, function()
		local optionSelected = forms.gettext(pokedexDropdown)

		if optionSelected == dropdownOptions[1] then
			optionSelected = Options.StartupIcon.random
		elseif optionSelected == dropdownOptions[2] then
			optionSelected = Options.StartupIcon.none
		elseif optionSelected ~= "..................................." then
			-- The option is a Pokemon's name and needs to be convered to an ID
			optionSelected = PokemonData.getIdFromName(optionSelected) or -1
		end

		StartupScreen.setPokemonIcon(optionSelected)
		Program.redraw(true)
		Main.SaveSettings(true)

		Utils.closeBizhawkForm(form)
	end, 200, 29)

	forms.button(form, Resources.AllScreens.Cancel, function()
		Utils.closeBizhawkForm(form)
	end, 120, 69)
end

-- USER INPUT FUNCTIONS
function StartupScreen.checkInput(xmouse, ymouse)
	Input.checkButtonsClicked(xmouse, ymouse, StartupScreen.Buttons)
end

-- DRAWING FUNCTIONS
function StartupScreen.drawScreen()
	Drawing.drawBackgroundAndMargins()

	local topBox = {
		x = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN,
		y = Constants.SCREEN.MARGIN,
		width = Constants.SCREEN.RIGHT_GAP - (Constants.SCREEN.MARGIN * 2),
		height = Constants.SCREEN.HEIGHT - (Constants.SCREEN.MARGIN * 2),
		text = Theme.COLORS["Default text"],
		border = Theme.COLORS["Upper box border"],
		fill = Theme.COLORS["Upper box background"],
		shadow = Utils.calcShadowColor(Theme.COLORS["Upper box background"]),
	}
	local textLineY = topBox.y + 11
	local linespacing = Constants.SCREEN.LINESPACING + 1

	-- TOP BORDER BOX
	gui.defaultTextBackground(topBox.fill)
	gui.drawRectangle(topBox.x, topBox.y, topBox.width, topBox.height, topBox.border, topBox.fill)

	textLineY = textLineY + linespacing

	-- if StartupScreen.Buttons.ResetsCount.isVisible() then
	-- 	Drawing.drawText(topBox.x + 2, textLineY, Resources.StartupScreen.Resets .. ":", topBox.text, topBox.shadow, 12)
	-- end

	-- Draw all buttons
	for _, button in pairs(StartupScreen.Buttons) do
		Drawing.drawButton(button, topBox.shadow)
	end
end