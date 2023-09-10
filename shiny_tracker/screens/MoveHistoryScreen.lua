MoveHistoryScreen = {
	Colors = {
		text = "Lower box text",
		headerMoves = "Intermediate text",
		border = "Lower box border",
		boxFill = "Lower box background",
	},
	pokemonID = nil,
}

MoveHistoryScreen.Pagination = {
	currentPage = 0,
	totalPages = 0,
	itemsPerPage = 7,
	getPageText = function(self)
		if self.totalPages <= 1 then return Resources.AllScreens.Page end
		return string.format("%s %s/%s", Resources.AllScreens.Page, self.currentPage, self.totalPages)
	end,
	prevPage = function(self)
		if self.totalPages <= 1 then return end
		self.currentPage = ((self.currentPage - 2 + self.totalPages) % self.totalPages) + 1
		Program.redraw(true)
	end,
	nextPage = function(self)
		if self.totalPages <= 1 then return end
		self.currentPage = (self.currentPage % self.totalPages) + 1
		Program.redraw(true)
	end,
}

MoveHistoryScreen.Buttons = {
	LookupPokemon = {
		type = Constants.ButtonTypes.PIXELIMAGE,
		image = Constants.PixelImages.MAGNIFYING_GLASS,
		box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 127, Constants.SCREEN.MARGIN + 4, 10, 10, },
		onClick = function(self)
			MoveHistoryScreen.openPokemonInfoWindow()
		end
	},
	CurrentPage = {
		type = Constants.ButtonTypes.NO_BORDER,
		getText = function(self) return MoveHistoryScreen.Pagination:getPageText() end,
		box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 46, Constants.SCREEN.MARGIN + 135, 50, 10, },
		isVisible = function() return MoveHistoryScreen.Pagination.totalPages > 1 end,
	},
	PrevPage = {
		type = Constants.ButtonTypes.PIXELIMAGE,
		image = Constants.PixelImages.LEFT_ARROW,
		box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 32, Constants.SCREEN.MARGIN + 136, 10, 10, },
		isVisible = function() return MoveHistoryScreen.Pagination.totalPages > 1 end,
		onClick = function(self)
			MoveHistoryScreen.Pagination:prevPage()
		end
	},
	NextPage = {
		type = Constants.ButtonTypes.PIXELIMAGE,
		image = Constants.PixelImages.RIGHT_ARROW,
		box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 91, Constants.SCREEN.MARGIN + 136, 10, 10, },
		isVisible = function() return MoveHistoryScreen.Pagination.totalPages > 1 end,
		onClick = function(self)
			MoveHistoryScreen.Pagination:nextPage()
		end
	},
	Back = Drawing.createUIElementBackButton(function()
		if InfoScreen.infoLookup == nil or InfoScreen.infoLookup == 0 then
			Program.changeScreenView(TrackerScreen)
		else
			Program.changeScreenView(InfoScreen)
		end
	end),
}

MoveHistoryScreen.TemporaryButtons = {}

function MoveHistoryScreen.initialize()
	for _, button in pairs(MoveHistoryScreen.Buttons) do
		if button.textColor == nil then
			button.textColor = MoveHistoryScreen.Colors.text
		end
		if button.boxColors == nil then
			button.boxColors = { MoveHistoryScreen.Colors.border, MoveHistoryScreen.Colors.boxFill }
		end
	end
end

-- Lists out all known tracked moves for the Pokemon provided. If too many tracked moves, trims based on [startingLevel:optional]
function MoveHistoryScreen.buildOutHistory(pokemonID, startingLevel)
	if not PokemonData.isValid(pokemonID) then return false end

	MoveHistoryScreen.pokemonID = pokemonID
	startingLevel = startingLevel or 1
	MoveHistoryScreen.TemporaryButtons = {}

	local moves
	if Options["Open Book Play Mode"] then
		local pokemonLog = RandomizerLog.Data.Pokemon[pokemonID] or {}
		moves = pokemonLog.MoveSet or {}
	else
		moves = Tracker.getMoves(pokemonID)
	end
	for _, move in ipairs(moves) do
		local moveId = move.id or move.moveId
		if MoveData.isValid(moveId) then -- Don't add in the placeholder moves
			local moveButton = {
				type = Constants.ButtonTypes.NO_BORDER,
				getText = function(self) return MoveData.Moves[moveId].name end,
				textColor = MoveHistoryScreen.Colors.text,
				trackedMove = move,
				isVisible = function(self) return self.pageVisible == MoveHistoryScreen.Pagination.currentPage end,
				draw = function(self, shadowcolor)
					-- Implied move text is drawn, then the levels off to the right-side
					local minLvTxt = self.trackedMove.minLv or self.trackedMove.level
					local maxLvTxt = self.trackedMove.maxLv or self.trackedMove.level
					Drawing.drawNumber(self.box[1] + 74 + 3, self.box[2], minLvTxt, 2, Theme.COLORS[MoveHistoryScreen.Colors.text], shadowcolor) -- 74 from drawScreen()
					Drawing.drawNumber(self.box[1] + 99 + 3, self.box[2], maxLvTxt, 2, Theme.COLORS[MoveHistoryScreen.Colors.text], shadowcolor) -- 99 from drawScreen()
				end,
				onClick = function(self)
					InfoScreen.changeScreenView(InfoScreen.Screens.MOVE_INFO, moveId)
				end
			}
			table.insert(MoveHistoryScreen.TemporaryButtons, moveButton)
		end
	end

	if not Options["Open Book Play Mode"] then
		-- Sort based on min level seen, or last level seen, in descending order
		local sortFunc = function(a, b)
			if a.trackedMove.minLv ~= nil and b.trackedMove.minLv ~= nil then
				return a.trackedMove.minLv > b.trackedMove.minLv
			else
				return a.trackedMove.level > b.trackedMove.level
			end
		end
		table.sort(MoveHistoryScreen.TemporaryButtons, sortFunc)
	end

	-- After sorting the moves, determine which are visible on which page, and where on the page vertically
	local startX = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 12
	local startY = Constants.SCREEN.MARGIN + 55
	local linespacing = Constants.SCREEN.LINESPACING + 0

	for index, button in ipairs(MoveHistoryScreen.TemporaryButtons) do
		local pageItemIndex = ((index - 1) % MoveHistoryScreen.Pagination.itemsPerPage) + 1
		button.box = { startX, startY + (pageItemIndex - 1) * linespacing, 80, 10 }
		button.pageVisible = math.ceil(index / MoveHistoryScreen.Pagination.itemsPerPage)
	end

	MoveHistoryScreen.Pagination.currentPage = 1
	MoveHistoryScreen.Pagination.totalPages = math.ceil(#MoveHistoryScreen.TemporaryButtons / MoveHistoryScreen.Pagination.itemsPerPage)

	return true
end

function MoveHistoryScreen.openPokemonInfoWindow()
	local form = Utils.createBizhawkForm(Resources.MoveHistoryScreen.PromptPokemonTitle, 360, 105)

	local pokemonName
	if PokemonData.isValid(MoveHistoryScreen.pokemonID) then
		pokemonName = PokemonData.Pokemon[MoveHistoryScreen.pokemonID].name
	else
		pokemonName = ""
	end
	local pokedexData = PokemonData.namesToList()

	forms.label(form, Resources.MoveHistoryScreen.PromptPokemonDesc .. ":", 49, 10, 250, 20)
	local pokedexDropdown = forms.dropdown(form, {["Init"]="Loading Pokedex"}, 50, 30, 145, 30)
	forms.setdropdownitems(pokedexDropdown, pokedexData, true) -- true = alphabetize the list
	forms.setproperty(pokedexDropdown, "AutoCompleteSource", "ListItems")
	forms.setproperty(pokedexDropdown, "AutoCompleteMode", "Append")
	forms.settext(pokedexDropdown, pokemonName)

	forms.button(form, Resources.AllScreens.Lookup, function()
		local pokemonNameFromForm = forms.gettext(pokedexDropdown)
		local pokemonId = PokemonData.getIdFromName(pokemonNameFromForm)

		if pokemonId ~= nil and pokemonId ~= 0 then
			if MoveHistoryScreen.buildOutHistory(pokemonId) then
				Program.redraw(true)
			end
		end
		Utils.closeBizhawkForm(form)
	end, 212, 29)
end

-- USER INPUT FUNCTIONS
function MoveHistoryScreen.checkInput(xmouse, ymouse)
	Input.checkButtonsClicked(xmouse, ymouse, MoveHistoryScreen.Buttons)
	Input.checkButtonsClicked(xmouse, ymouse, MoveHistoryScreen.TemporaryButtons)
end

-- DRAWING FUNCTIONS
function MoveHistoryScreen.drawScreen()
	Drawing.drawBackgroundAndMargins()
	gui.defaultTextBackground(Theme.COLORS[MoveHistoryScreen.Colors.boxFill])

	local shadowcolor = Utils.calcShadowColor(Theme.COLORS[MoveHistoryScreen.Colors.boxFill])
	local topboxX = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN
	local topboxY = Constants.SCREEN.MARGIN
	local topboxWidth = Constants.SCREEN.RIGHT_GAP - (Constants.SCREEN.MARGIN * 2)
	local topboxHeight = Constants.SCREEN.HEIGHT - (Constants.SCREEN.MARGIN * 2)

	if not PokemonData.isValid(MoveHistoryScreen.pokemonID) then
		for _, button in pairs(MoveHistoryScreen.Buttons) do
			Drawing.drawButton(button, shadowcolor)
		end
		return
	end

	-- Draw top border box
	gui.drawRectangle(topboxX, topboxY, topboxWidth, topboxHeight, Theme.COLORS[MoveHistoryScreen.Colors.border], Theme.COLORS[MoveHistoryScreen.Colors.boxFill])

	-- Draw header text
	local pokemonName = Utils.toUpperUTF8(PokemonData.Pokemon[MoveHistoryScreen.pokemonID].name)
	Drawing.drawHeader(topboxX, topboxY - 1, pokemonName, Theme.COLORS[MoveHistoryScreen.Colors.text], shadowcolor)
	topboxY = topboxY + Constants.SCREEN.LINESPACING + 4

	MoveHistoryScreen.drawMovesLearnedBoxes(topboxX + 1, topboxY + 1)
	topboxY = topboxY + Constants.SCREEN.LINESPACING * 2 + 8

	-- Draw all moves in the tracked move history
	local offsetX = topboxX + 13
	local minColX, maxColX = 74, 99
	Drawing.drawText(offsetX - 8, topboxY, Resources.MoveHistoryScreen.HeaderMoves, Theme.COLORS[MoveHistoryScreen.Colors.headerMoves], shadowcolor)
	Drawing.drawText(offsetX + minColX, topboxY, Resources.MoveHistoryScreen.HeaderMin, Theme.COLORS[MoveHistoryScreen.Colors.headerMoves], shadowcolor)
	Drawing.drawText(offsetX + maxColX, topboxY, Resources.MoveHistoryScreen.HeaderMax, Theme.COLORS[MoveHistoryScreen.Colors.headerMoves], shadowcolor)
	topboxY = topboxY + Constants.SCREEN.LINESPACING

	if #MoveHistoryScreen.TemporaryButtons == 0 then
		Drawing.drawText(offsetX, topboxY + 5, Resources.MoveHistoryScreen.NoTrackedMoves, Theme.COLORS[MoveHistoryScreen.Colors.text], shadowcolor)
	else
		for _, button in ipairs(MoveHistoryScreen.TemporaryButtons) do
			Drawing.drawButton(button, shadowcolor)
		end
	end

	-- Draw all buttons
	for _, button in pairs(MoveHistoryScreen.Buttons) do
		Drawing.drawButton(button, shadowcolor)
	end
end

function MoveHistoryScreen.drawMovesLearnedBoxes(offsetX, offsetY)
	local shadowcolor = Utils.calcShadowColor(Theme.COLORS[MoveHistoryScreen.Colors.boxFill])

	local pokemon = PokemonData.Pokemon[MoveHistoryScreen.pokemonID]
	local movelvls = pokemon.movelvls[GameSettings.versiongroup]

	-- Used for highlighting which moves have already been learned, but only for the Pokémon actively being viewed
	local pokemonViewed = Tracker.getViewedPokemon() or Tracker.getDefaultPokemon()
	local viewedPokemonLevel
	if pokemonViewed.pokemonID == pokemon.pokemonID then
		viewedPokemonLevel = pokemonViewed.level
	else
		viewedPokemonLevel = 0
	end

	local boxWidth = 16
	local boxHeight = 13
	if #movelvls == 0 then -- If the Pokemon learns no moves at all
		Drawing.drawText(offsetX + 6, offsetY, Resources.MoveHistoryScreen.NoMovesLearned, Theme.COLORS[MoveHistoryScreen.Colors.text], shadowcolor)
	end
	for i, moveLvl in ipairs(movelvls) do -- 14 is the greatest number of moves a gen3 Pokemon can learn
		local nextBoxX = ((i - 1) % 8) * boxWidth -- 8 possible columns
		local nextBoxY = Utils.inlineIf(i <= 8, 0, 1) * boxHeight -- 2 possible rows
		local lvlSpacing = (2 - string.len(tostring(moveLvl))) * 3

		-- Draw the level box
		gui.drawRectangle(offsetX + nextBoxX + 5 + 1, offsetY + nextBoxY + 2, boxWidth, boxHeight, shadowcolor, shadowcolor)
		gui.drawRectangle(offsetX + nextBoxX + 5, offsetY + nextBoxY + 1, boxWidth, boxHeight, Theme.COLORS[MoveHistoryScreen.Colors.border], Theme.COLORS[MoveHistoryScreen.Colors.boxFill])

		-- Indicate which moves have already been learned if the Pokemon being viewed is one of the ones in battle (yours/enemy)
		local nextBoxTextColor
		if viewedPokemonLevel == 0 then
			nextBoxTextColor = Theme.COLORS[MoveHistoryScreen.Colors.text]
		elseif moveLvl <= viewedPokemonLevel then
			nextBoxTextColor = Theme.COLORS["Negative text"]
		else
			nextBoxTextColor = Theme.COLORS["Positive text"]
		end

		-- Draw the level inside the box
		Drawing.drawText(offsetX + nextBoxX + 7 + lvlSpacing, offsetY + nextBoxY + 2, moveLvl, nextBoxTextColor, shadowcolor)
	end

	return Utils.inlineIf(#movelvls <= 8, 1, 2) -- return number of lines drawn
end