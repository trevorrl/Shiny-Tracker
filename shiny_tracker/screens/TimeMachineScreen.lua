TimeMachineScreen = {
	Colors = {
		text = "Default text",
		border = "Upper box border",
		boxFill = "Upper box background",
	},
	rpCount = 0,
	maxRestorePoints = 10,
	timeLastCreatedRP = 0,
	timeToWaitPerRP = 5 * 60, -- 5 minutes * 60 seconds/min
}

-- A collection of temporary save states created in memory through Bizhawk
TimeMachineScreen.RestorePoints = {}

TimeMachineScreen.Pager = {
	Buttons = {},
	currentPage = 0,
	totalPages = 0,
	realignButtonsToGrid = function(self, x, y, colSpacer, rowSpacer)
		table.sort(self.Buttons, self.defaultSort)
		local cutoffX = Constants.SCREEN.WIDTH + Constants.SCREEN.RIGHT_GAP - Constants.SCREEN.MARGIN
		local cutoffY = Constants.SCREEN.HEIGHT - 20
		local totalPages = Utils.gridAlign(self.Buttons, x, y, colSpacer, rowSpacer, true, cutoffX, cutoffY)
		self.currentPage = 1
		self.totalPages = totalPages or 1
	end,
	defaultSort = function(a, b) return a.timestamp > b.timestamp end, -- sorts newest to oldest
	getPageText = function(self)
		if self.totalPages > 1 then
			return string.format("%s %s/%s", Resources.AllScreens.Page, self.currentPage, self.totalPages)
		end
		return Resources.AllScreens.Page
	end,
	prevPage = function(self)
		if self.totalPages <= 1 then return end
		self.currentPage = ((self.currentPage - 2 + self.totalPages) % self.totalPages) + 1
	end,
	nextPage = function(self)
		if self.totalPages <= 1 then return end
		self.currentPage = (self.currentPage % self.totalPages) + 1
	end,
}

TimeMachineScreen.Buttons = {
	EnableRestorePoints = {
		type = Constants.ButtonTypes.CHECKBOX,
		optionKey = "Enable restore points",
		getText = function() return " " .. Resources.TimeMachineScreen.OptionEnableRestorePoints end,
		clickableArea = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 4, Constants.SCREEN.MARGIN + 14, Constants.SCREEN.RIGHT_GAP - 12, 8 },
		box = {	Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 4, Constants.SCREEN.MARGIN + 14, 8, 8 },
		toggleState = true, -- update later in initialize
		updateSelf = function(self) self.toggleState = (Options[self.optionKey] == true) end,
		onClick = function(self)
			self.toggleState = Options.toggleSetting(self.optionKey)
			Program.redraw(true)
		end,
	},
	CurrentPage = {
		type = Constants.ButtonTypes.NO_BORDER,
		getText = function() return TimeMachineScreen.Pager:getPageText() end,
		box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 53, Constants.SCREEN.MARGIN + 135, 50, 10, },
		isVisible = function() return TimeMachineScreen.Pager.totalPages > 1 end,
	},
	PrevPage = {
		type = Constants.ButtonTypes.PIXELIMAGE,
		image = Constants.PixelImages.LEFT_ARROW,
		box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 39, Constants.SCREEN.MARGIN + 136, 10, 10, },
		isVisible = function() return TimeMachineScreen.Pager.totalPages > 1 end,
		onClick = function(self)
			TimeMachineScreen.Pager:prevPage()
			Program.redraw(true)
		end
	},
	NextPage = {
		type = Constants.ButtonTypes.PIXELIMAGE,
		image = Constants.PixelImages.RIGHT_ARROW,
		box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 98, Constants.SCREEN.MARGIN + 136, 10, 10, },
		isVisible = function() return TimeMachineScreen.Pager.totalPages > 1 end,
		onClick = function(self)
			TimeMachineScreen.Pager:nextPage()
			Program.redraw(true)
		end
	},
	CreateNewRestorePoint = {
		type = Constants.ButtonTypes.FULL_BORDER,
		getText = function(self) return Resources.TimeMachineScreen.ButtonCreate end,
		box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 4, Constants.SCREEN.MARGIN + 135, 30, 11 },
		onClick = function(self)
			TimeMachineScreen.createRestorePoint()
			TimeMachineScreen.buildOutPagedButtons()
			Program.redraw(true)
		end
	},
	Back = Drawing.createUIElementBackButton(function()
		TimeMachineScreen.refreshButtons()
		Program.changeScreenView(ExtrasScreen)
	end),
}

function TimeMachineScreen.initialize()
	for _, button in pairs(TimeMachineScreen.Buttons) do
		if button.textColor == nil then
			button.textColor = TimeMachineScreen.Colors.text
		end
		if button.boxColors == nil then
			button.boxColors = { TimeMachineScreen.Colors.border, TimeMachineScreen.Colors.boxFill }
		end
	end

	-- First restore point to be made at the 8 second mark, for second chance at choosing a diff starter
	TimeMachineScreen.timeLastCreatedRP = os.time() - (TimeMachineScreen.timeToWaitPerRP - 8)

	TimeMachineScreen.refreshButtons()
end

function TimeMachineScreen.refreshButtons()
	for _, button in pairs(TimeMachineScreen.Buttons) do
		if type(button.updateSelf) == "function" then
			button:updateSelf()
		end
	end
	for _, button in pairs(TimeMachineScreen.Pager.Buttons) do
		if button.confirmedRestore then
			button.confirmedRestore = false
		end
		if type(button.updateSelf) == "function" then
			button:updateSelf()
		end
	end
end

function TimeMachineScreen.checkCreatingRestorePoint()
	-- Reasons not to create a restore point; once it's okay to make one (i.e. start the game or finish a battle) time catches up and a new state is created
	if not Options["Enable restore points"] or not Program.isValidMapLocation() or Battle.inBattle or Battle.battleStarting then
		return
	end

	local secSinceLastRP = os.time() - TimeMachineScreen.timeLastCreatedRP

	-- Only create a restore point if enough time has elapsed
	if secSinceLastRP >= TimeMachineScreen.timeToWaitPerRP then
		TimeMachineScreen.createRestorePoint()
	end
end

-- Creates a temporary save state in memory with an associated label(optional); returns ID of created save state
function TimeMachineScreen.createRestorePoint(label)
	if not Main.IsOnBizhawk() then return end

	local restorePointId = memorysavestate.savecorestate()
	TimeMachineScreen.timeLastCreatedRP = os.time()
	TimeMachineScreen.rpCount = TimeMachineScreen.rpCount + 1

	if label == nil then
		local mapLocationName
		if RouteData.hasRoute(Program.GameData.mapId) then
			mapLocationName = RouteData.Info[Program.GameData.mapId].name
			mapLocationName = Utils.formatSpecialCharacters(mapLocationName)
		else
			mapLocationName = Resources.TimeMachineScreen.LocationUnknownArea
		end
		label = string.format("# %s - %s", TimeMachineScreen.rpCount, mapLocationName)
	end

	local restorePoint = {
		id = restorePointId,
		label = label,
		timestamp = os.time(),
		playtime = Tracker.Data.playtime
	}
	table.insert(TimeMachineScreen.RestorePoints, restorePoint)

	TimeMachineScreen.cleanupOldRestorePoints()

	return restorePointId
end

function TimeMachineScreen.loadRestorePoint(restorePointId)
	if not Main.IsOnBizhawk() or restorePointId == nil then return end
	memorysavestate.loadcorestate(restorePointId)
	-- Battle.resetBattle()
end

function TimeMachineScreen.cleanupOldRestorePoints(forceRemoveAll)
	if not Main.IsOnBizhawk() then return end

	if forceRemoveAll then
		for _, rp in pairs(TimeMachineScreen.RestorePoints) do
			if rp.id ~= nil then
				memorysavestate.removestate(rp.id)
			end
		end
		TimeMachineScreen.RestorePoints = {}
		return
	elseif #TimeMachineScreen.RestorePoints <= TimeMachineScreen.maxRestorePoints then
		return
	elseif Program.currentScreen == TimeMachineScreen then
		-- Don't remove anything if the user is viewing the restore points, as they may use one of them
		return
	end

	-- Otherwise, keep removing excess restore points until under the max
	table.sort(TimeMachineScreen.RestorePoints, TimeMachineScreen.Pager.defaultSort)
	while #TimeMachineScreen.RestorePoints > TimeMachineScreen.maxRestorePoints do
		local rp = table.remove(TimeMachineScreen.RestorePoints, TimeMachineScreen.maxRestorePoints + 1)
		if rp ~= nil and rp.id ~= nil then
			memorysavestate.removestate(rp.id)
		end
	end
end

function TimeMachineScreen.backupCurrentPointInTime()
	if #TimeMachineScreen.RestorePoints == 0 then
		return
	end
	local returnBackLabel = string.format(">>  %s", Resources.TimeMachineScreen.UndoAndReturnBack)

	-- Determine if the most recently created restore point was the original point in the future
	table.sort(TimeMachineScreen.RestorePoints, TimeMachineScreen.Pager.defaultSort)
	if TimeMachineScreen.RestorePoints[1].label ~= returnBackLabel then
		-- First remove any "future" restore to avoid confusion
		local oldFutureRP = nil
		for index, rp in ipairs(TimeMachineScreen.RestorePoints) do
			if rp.label == returnBackLabel then
				oldFutureRP = index
				break
			end
		end
		if oldFutureRP ~= nil then
			table.remove(TimeMachineScreen.RestorePoints, oldFutureRP)
		end

		-- Then create a backup restore point and label it as "from the future"
		TimeMachineScreen.createRestorePoint(returnBackLabel)
	end
end

function TimeMachineScreen.buildOutPagedButtons()
	TimeMachineScreen.Pager.Buttons = {}

	for _, restorePoint in pairs(TimeMachineScreen.RestorePoints) do
		local button = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function(self)
				if self.confirmedRestore then
					return Resources.TimeMachineScreen.ConfirmationRestore
				else
					return restorePoint.label
				end
			end,
			textColor = TimeMachineScreen.Colors.text,
			boxColors = { TimeMachineScreen.Colors.border, TimeMachineScreen.Colors.boxFill, },
			restorePointId = restorePoint.id or 0,
			timestamp = restorePoint.timestamp or os.time(),
			confirmedRestore = false,
			dimensions = { width = 124, height = 11, },
			isVisible = function(self) return TimeMachineScreen.Pager.currentPage == self.pageVisible end,
			updateSelf = function(self)
				if self.confirmedRestore then
					self.textColor = "Negative text"
				else
					self.textColor = TimeMachineScreen.Colors.text
				end
			end,
			draw = function(self, shadowcolor)
				local minutesAgo = math.ceil((os.time() - restorePoint.timestamp) / 60)
				local timestampText
				if minutesAgo == 1 then
					timestampText = Resources.TimeMachineScreen.RestorePointAgeSingular
				else
					timestampText = string.format(Resources.TimeMachineScreen.RestorePointAgePlural, minutesAgo)
				end
				local rightAlignOffset = self.box[3] - Utils.calcWordPixelLength(timestampText) - 2
				Drawing.drawText(self.box[1] + rightAlignOffset, self.box[2] + self.box[4] + 1, timestampText, Theme.COLORS[TimeMachineScreen.Colors.text], shadowcolor)
			end,
			onClick = function(self)
				if self.confirmedRestore then
					TimeMachineScreen.backupCurrentPointInTime()
					Tracker.Data.playtime = restorePoint.playtime or 0
					TimeMachineScreen.loadRestorePoint(self.restorePointId)
					self.confirmedRestore = false
					TimeMachineScreen.buildOutPagedButtons()
				else
					self.confirmedRestore = true
				end
				self:updateSelf()
				Program.redraw(true)
			end,
		}
		table.insert(TimeMachineScreen.Pager.Buttons, button)
	end

	local x = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 8
	local y = Constants.SCREEN.MARGIN + 48
	local colSpacer = 1
	local rowSpacer = Constants.SCREEN.LINESPACING + 7
	TimeMachineScreen.Pager:realignButtonsToGrid(x, y, colSpacer, rowSpacer)

	return true
end

-- USER INPUT FUNCTIONS
function TimeMachineScreen.checkInput(xmouse, ymouse)
	Input.checkButtonsClicked(xmouse, ymouse, TimeMachineScreen.Buttons)
	Input.checkButtonsClicked(xmouse, ymouse, TimeMachineScreen.Pager.Buttons)
end

-- DRAWING FUNCTIONS
function TimeMachineScreen.drawScreen()
	Drawing.drawBackgroundAndMargins()
	gui.defaultTextBackground(Theme.COLORS[TimeMachineScreen.Colors.boxFill])

	local topBox = {
		x = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN,
		y = Constants.SCREEN.MARGIN + 10,
		width = Constants.SCREEN.RIGHT_GAP - (Constants.SCREEN.MARGIN * 2),
		height = Constants.SCREEN.HEIGHT - (Constants.SCREEN.MARGIN * 2) - 10,
		text = Theme.COLORS[TimeMachineScreen.Colors.text],
		border = Theme.COLORS[TimeMachineScreen.Colors.border],
		fill = Theme.COLORS[TimeMachineScreen.Colors.boxFill],
		shadow = Utils.calcShadowColor(Theme.COLORS[TimeMachineScreen.Colors.boxFill]),
	}
	local headerText = Utils.toUpperUTF8(Resources.TimeMachineScreen.Title)
	local headerShadow = Utils.calcShadowColor(Theme.COLORS["Main background"])
	Drawing.drawText(topBox.x, Constants.SCREEN.MARGIN - 2, headerText, Theme.COLORS["Header text"], headerShadow)

	-- Draw top border box
	gui.drawRectangle(topBox.x, topBox.y, topBox.width, topBox.height, topBox.border, topBox.fill)
	local textLineY = topBox.y + Constants.SCREEN.LINESPACING + 3 -- make room for first checkbox

	local wrappedDesc = Utils.getWordWrapLines(Resources.TimeMachineScreen.DescInstructions, 32)
	for _, line in pairs(wrappedDesc) do
		Drawing.drawText(topBox.x + 3, textLineY, line, topBox.text, topBox.shadow)
		textLineY = textLineY + Constants.SCREEN.LINESPACING - 1
	end

	if #TimeMachineScreen.Pager.Buttons == 0 then
		wrappedDesc = Utils.getWordWrapLines(Resources.TimeMachineScreen.DescNoRestorePoints, 32)
		textLineY = textLineY + Constants.SCREEN.LINESPACING - 1
		for _, line in pairs(wrappedDesc) do
			Drawing.drawText(topBox.x + 3, textLineY, line, Theme.COLORS["Negative text"], topBox.shadow)
			textLineY = textLineY + Constants.SCREEN.LINESPACING - 1
		end
	end

	-- Draw all buttons
	for _, button in pairs(TimeMachineScreen.Buttons) do
		Drawing.drawButton(button, topBox.shadow)
	end
	for _, button in pairs(TimeMachineScreen.Pager.Buttons) do
		Drawing.drawButton(button, topBox.shadow)
	end
end
