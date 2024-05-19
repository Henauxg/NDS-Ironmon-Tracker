local function CoverageCalcScreen(initialSettings, initialTracker, initialProgram)
	local Frame = dofile(Paths.FOLDERS.UI_BASE_CLASSES .. "/Frame.lua")
	local Box = dofile(Paths.FOLDERS.UI_BASE_CLASSES .. "/Box.lua")
	local Component = dofile(Paths.FOLDERS.UI_BASE_CLASSES .. "/Component.lua")
	local TextLabel = dofile(Paths.FOLDERS.UI_BASE_CLASSES .. "/TextLabel.lua")
	local TextField = dofile(Paths.FOLDERS.UI_BASE_CLASSES .. "/TextField.lua")
	local TextStyle = dofile(Paths.FOLDERS.UI_BASE_CLASSES .. "/TextStyle.lua")
	local Layout = dofile(Paths.FOLDERS.UI_BASE_CLASSES .. "/Layout.lua")
	local MouseClickEventListener = dofile(Paths.FOLDERS.UI_BASE_CLASSES .. "/MouseClickEventListener.lua")
	local SettingToggleButton = dofile(Paths.FOLDERS.UI_BASE_CLASSES .. "/SettingToggleButton.lua")
	local settings = initialSettings
	local tracker = initialTracker
	local program = initialProgram
	local constants = {
		MAIN_FRAME_HEIGHT = 42,
		BUTTON_SIZE = 10
	}
	local ui = {}
	local eventListeners = {}
	local self = {}
	local moveSelectors = {}
	local selectedMoves = {}
	local moveTypeToSelector = {}
	local effectivenessTable = {}
	local effectivenessSelectorFrames = {}

	local function clearEffectivenessTable()
		effectivenessTable = {
			[0.0] = {
				ids = {},
				total = 0
			},
			[0.25] = {
				ids = {},
				total = 0
			},
			[0.5] = {
				ids = {},
				total = 0
			},
			[1.0] = {
				ids = {},
				total = 0
			},
			[2.0] = {
				ids = {},
				total = 0
			},
			[4.0] = {
				ids = {},
				total = 0
			}
		}
	end

	local function readTotals()
		for key, data in pairs(effectivenessTable) do
			local matchingFrame = effectivenessSelectorFrames[key]
			local total = data.total
			local text = "---"
			local xOffset = 6
			if total > 0 then
				text = tostring(total)
				local width = matchingFrame.frame.getSize().width
				xOffset = (width - DrawingUtils.calculateWordPixelLength(text)) / 2 - 1
			end
			matchingFrame.numberLabel.setText(text)
			matchingFrame.numberLabel.setTextOffset({ x = xOffset, y = 0 })
		end
	end

	local function getMoveEffectivenessAgainstPokemon(moveType, pokemonData)
		local effectiveness = 1.0
		for _, defenseType in pairs(pokemonData.type) do
			if defenseType ~= PokemonData.POKEMON_TYPES.EMPTY and MoveData.EFFECTIVE_DATA[moveType][defenseType] then
				effectiveness = effectiveness * MoveData.EFFECTIVE_DATA[moveType][defenseType]
			end
		end
		if pokemonData.name == "Shedinja" and effectiveness < 2.0 then
			return 0.0
		end
		return effectiveness
	end

	local function calculateMovesAgainstPokemon(selectedMoveTypes, pokemonID)
		local max = 0.0
		for _, moveType in pairs(selectedMoveTypes) do
			local pokemonData = PokemonData.POKEMON[pokemonID]
			local effectiveness = getMoveEffectivenessAgainstPokemon(moveType, pokemonData)
			if effectiveness > max then
				max = effectiveness
			end
		end
		table.insert(effectivenessTable[max].ids, pokemonID)
		effectivenessTable[max].total = effectivenessTable[max].total + 1
	end

	local function calculateMovesAgainstAllPokemon(selectedMoveTypes)
		for index, pokemon in pairs(PokemonData.POKEMON) do
			local valid = index > 1
			-- Quick & dirty: forcing fully evolved
			if settings.coverageCalc.FULLY_EVOLVED_ONLY then
				valid = valid and (pokemon.evolution == PokemonData.EVOLUTION_TYPES.NONE)
			end
			if PokemonData.ALTERNATE_FORMS[pokemon.name] and PokemonData.ALTERNATE_FORMS[pokemon.name].cosmetic == true then
				valid = false
			end
			if valid then
				calculateMovesAgainstPokemon(selectedMoveTypes, index)
			end
		end
		for _, data in pairs(effectivenessTable) do
			table.sort(
				data.ids,
				function(id1, id2)
					return PokemonData.POKEMON[id1].bst > PokemonData.POKEMON[id2].bst
				end
			)
		end
	end

	local function calculateCurrentEffectiveness()
		clearEffectivenessTable()
		local selectedMoveTypes = {}
		for selectedMove, selected in pairs(selectedMoves) do
			if selected then
				table.insert(selectedMoveTypes, selectedMove)
			end
		end
		if #selectedMoveTypes > 0 then
			calculateMovesAgainstAllPokemon(selectedMoveTypes)
		end
		readTotals()
		program.drawCurrentScreens()
	end

	local function onFullyEvolvedClick(button)
		button.onClick()
		calculateCurrentEffectiveness()
	end

	local function toggleBrightness(moveSelector, override, calculateNewCoverage)
		if calculateNewCoverage == nil then
			calculateNewCoverage = true
		end
		local moveType = moveSelector.moveType
		local on = selectedMoves[moveType] or false
		on = not on
		if override ~= nil then
			on = override
		end
		selectedMoves[moveType] = on
		if calculateNewCoverage then
			calculateCurrentEffectiveness()
		end
	end

	local function initMoveSelectors()
		for index, moveType in pairs(PokemonData.FULL_TYPE_LIST) do
			moveSelectors[index] = {}
			moveSelectors[index].moveType = moveType
			moveTypeToSelector[moveType] = moveSelectors[index]
		end
	end

	local function initFullyEvolvedButton()
		local frame =
			Frame(
				Box({ x = 0, y = 0 }, { width = 0, height = 0 }),
				Layout(Graphics.ALIGNMENT_TYPE.VERTICAL, 2, { x = Graphics.SIZES.MAIN_SCREEN_WIDTH, y = 5 }),
				ui.frames.mainInnerFrame
			)
		local toggle =
			SettingToggleButton(
				Component(
					frame,
					Box(
						{ x = 0, y = 0 },
						{ width = constants.BUTTON_SIZE, height = constants.BUTTON_SIZE },
						"Top box background color",
						"Top box border color",
						true,
						"Top box background color"
					)
				),
				settings.coverageCalc,
				"FULLY_EVOLVED_ONLY",
				nil,
				false,
				true,
				program.saveSettings
			)
		TextLabel(
			Component(frame, Box({ x = 0, y = 0 }, { width = 0, height = 0 }, nil, nil, false)),
			TextField(
				"Full evo only",
				{ x = -18, y = 0 },
				TextStyle(
					Graphics.FONT.DEFAULT_FONT_SIZE,
					Graphics.FONT.DEFAULT_FONT_FAMILY,
					"Top box text color",
					"Top box background color"
				)
			)
		)
		table.insert(eventListeners, MouseClickEventListener(toggle, onFullyEvolvedClick, toggle))
	end

	local function createEffectivenessFrame(tableKey, labelText)
		local frameInfo = {
			["tableKey"] = tableKey
		}
		local frameWidth = 22
		frameInfo.frame =
			Frame(
				Box({ x = 0, y = 0 }, { width = frameWidth, height = 30 }),
				Layout(Graphics.ALIGNMENT_TYPE.VERTICAL, 0, { x = 0, y = 2 }),
				ui.frames.effectivenessSelectorFrame
			)
		local textOffset = ((frameWidth - DrawingUtils.calculateWordPixelLength(labelText)) / 2)
		frameInfo.effectivenessLabel =
			TextLabel(
				Component(frameInfo.frame, Box({ x = 0, y = 0 }, { width = 0, height = 14 })),
				TextField(
					labelText,
					{ x = textOffset, y = 0 },
					TextStyle(
						Graphics.FONT.DEFAULT_FONT_SIZE,
						Graphics.FONT.DEFAULT_FONT_FAMILY,
						"Top box text color",
						"Top box background color"
					)
				)
			)
		frameInfo.numberLabel =
			TextLabel(
				Component(frameInfo.frame, Box({ x = 0, y = 0 }, { width = 0, height = 20 })),
				TextField(
					"---",
					{ x = 6, y = 0 },
					TextStyle(
						Graphics.FONT.DEFAULT_FONT_SIZE,
						Graphics.FONT.DEFAULT_FONT_FAMILY,
						"Top box text color",
						"Top box background color"
					)
				)
			)
		effectivenessSelectorFrames[tableKey] = frameInfo
	end

	local function initEffectivenessUI()
		local effectivenessKeyToLabel = {
			[0.0] = "0x",
			[0.25] = "1/4x",
			[0.5] = "1/2x",
			[1.0] = "1x",
			[2.0] = "2x",
			[4.0] = "4x"
		}
		local ordered = { 0.0, 0.25, 0.5, 1.0, 2.0, 4.0 }
		ui.frames.effectivenessSelectorFrame =
			Frame(
				Box({ x = 0, y = 0 }, { width = 0, height = 36 }),
				Layout(Graphics.ALIGNMENT_TYPE.HORIZONTAL, 0, { x = 1, y = 2 }),
				ui.frames.mainInnerFrame
			)
		for _, tableKey in pairs(ordered) do
			local labelText = effectivenessKeyToLabel[tableKey]
			createEffectivenessFrame(tableKey, labelText)
		end
	end

	local function initUI()
		ui.controls = {}
		ui.frames = {}
		ui.frames.mainFrame =
			Frame(
				Box(
					{
						x = Graphics.SIZES.SCREEN_WIDTH,
						y = Graphics.SIZES.MAIN_SCREEN_HEIGHT -
							Graphics.SIZES.BORDER_MARGIN
					},
					{ width = Graphics.SIZES.MAIN_SCREEN_WIDTH, height = constants.MAIN_FRAME_HEIGHT },
					"Main background color",
					nil
				)
			)
		ui.frames.mainInnerFrame =
			Frame(
				Box(
					{ x = 5, y = 5 },
					-- TODO Main screen + 2 x badge + 2 x padding ?
					{ width = Graphics.SIZES.MAIN_SCREEN_WIDTH + 38, height = constants.MAIN_FRAME_HEIGHT - 10 },
					"Top box background color",
					"Top box border color"
				),
				Layout(Graphics.ALIGNMENT_TYPE.VERTICAL, 0, { x = 3, y = 0 }),
				ui.frames.mainFrame
			)
		initFullyEvolvedButton()
		initMoveSelectors()
		initEffectivenessUI()
	end

	local function reset()
		clearEffectivenessTable()
		for _, selector in pairs(moveSelectors) do
			toggleBrightness(selector, false, false)
		end
	end

	function self.initialize(playerMoves)
		reset()
		if playerMoves == nil or next(playerMoves) == nil then
			return
		end
		for _, moveID in pairs(playerMoves) do
			if moveID ~= 0 then
				local moveData = MoveData.MOVES[moveID + 1]
				local moveType = moveData.type
				if moveData.name == "Hidden Power" then
					moveType = tracker.getCurrentHiddenPowerType()
				end
				if moveData.category ~= MoveData.MOVE_CATEGORIES.STATUS and moveData.power ~= "---" then
					toggleBrightness(moveTypeToSelector[moveType], true, false)
				end
			end
		end
		calculateCurrentEffectiveness()
	end

	function self.runEventListeners()
		for _, eventListener in pairs(eventListeners) do
			eventListener.listen()
		end
	end

	function self.show()
		ui.frames.mainFrame.show()
	end

	initUI()
	return self
end

return CoverageCalcScreen
