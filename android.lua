require "androidbutton"
local buttons = {}

local touchClicking = true -- is clicking allowed (ex: it shouldn't be allowed during gameplay, because there's dedicated clicking buttons)

local controllingPlayer = 1
local androidSetPlayer

local resettools = function()
	ANDROIDRIGHTCLICK = false
	eyedroppertool = false
	paintbuckettool = false
	replacetool = false
end

local editorButtons = {
	{function() HIDEANDROIDBUTTONS = not HIDEANDROIDBUTTONS end, function() return HIDEANDROIDBUTTONS end, 1},
	{function() editentities = false; currenttile = 1 end, nil, 2},
	{function() editentities = true; currenttile = 1 end, nil, 3},
	{function() ANDROIDRIGHTCLICK = not ANDROIDRIGHTCLICK end, function() return ANDROIDRIGHTCLICK end, 4},
	{function() ANDROIDSHOWTOOLS = not ANDROIDSHOWTOOLS end, function() return ANDROIDSHOWTOOLS end, 11},
	{function() undo_undo() end, nil, 6},
}

local editorToolButtons = {
	{function() local old = eyedroppertool; resettools(); eyedroppertool = not old end, function() return eyedroppertool end, 7},
	{function() local old = paintbuckettool; resettools(); paintbuckettool = not old end, function() return paintbuckettool end, 8},
	{function() local old = replacetool; resettools(); replacetool = not old end, function() return replacetool end, 9},
	{function() backgroundtilemode = not backgroundtilemode end, function() return backgroundtilemode end, 5},
}

local skin, skinData, skinImg, skinSpriteBatch
androidLowRes = false

function androidLoad()
	-- Skin Files setup
	local skinjsonfile = "android/skin.json"
	local skinimgfile = "android/skin.png"
	if love.filesystem.getInfo("alesans_entities/skin.zip") then
		love.filesystem.mount("alesans_entities/skin.zip", "alesans_entities", true)
	end

	if love.filesystem.getInfo("alesans_entities/skin.json") then
		skinjsonfile = "alesans_entities/skin.json"
	end
	if love.filesystem.getInfo("alesans_entities/skin.png") then
		skinimgfile = "alesans_entities/skin.png"
	end

	local s = love.filesystem.read(skinjsonfile)
	skinData = JSON:decode(s)
	local t = skinData

	if t.image then
		skin = {}
		skinImg = love.graphics.newImage(skinimgfile, {mipmaps = t.mipmaps})
		skinImg:setFilter("linear", "linear")
		local skinButtonCount = 0
		local offset = t.offset or skinImg:getHeight() / 3
		for name, data in pairs(t) do
			if type(data) == "table" then
				skinButtonCount = skinButtonCount + 1
				skin[name] = {}
				for i = 1, 3 do
					skin[name][i] = love.graphics.newQuad(data[5], data[6] + offset * (i - 1), data[7], data[8], skinImg:getWidth(), skinImg:getHeight())
				end
			end
		end
		skinSpriteBatch = love.graphics.newSpriteBatch(skinImg, skinButtonCount * 2)
	end
	androidLowRes = t.lowres

	-- Game controls initialization
	buttons["jump"] = touchButton:new("jump", "A", t["jump"][1], t["jump"][2], t["jump"][3], t["jump"][4], "round")
	buttons["jump"].autoscrollGone = true
	buttons["run"] = touchButton:new("run", "B", t["run"][1], t["run"][2], t["run"][3], t["run"][4], "round")
	buttons["run"].autoscrollGone = true
	buttons["run"].highlightFunc = function() return touchRunLock end
	buttons["runlock"] = touchButton:new("runlock", "+", t["runlock"][1], t["runlock"][2], t["runlock"][3], t["runlock"][4], "round")
	buttons["runlock"].autoscrollGone = true
	buttons["runlock"].highlightFunc = buttons["run"].highlightFunc
	buttons["use"] = touchButton:new("use", "U", t["use"][1], t["use"][2], t["use"][3], t["use"][4], "round")
	buttons["use"].autoscrollGone = true
	buttons["use"].gameOnly = true

	buttons["left"] = touchButton:new("left", "", t["left"][1], t["left"][2], t["left"][3], t["left"][4])
	buttons["right"] = touchButton:new("right", "", t["right"][1], t["right"][2], t["right"][3], t["right"][4])
	buttons["up"] = touchButton:new("up", "", t["up"][1], t["up"][2], t["up"][3], t["up"][4])
	buttons["down"] = touchButton:new("down", "", t["down"][1], t["down"][2], t["down"][3], t["down"][4])

	buttons["start"] = touchButton:new("start", "START", t["start"][1], t["start"][2], t["start"][3], t["start"][4])

	buttons["reload"] = touchButton:new("reload", "R", t["reload"][1], t["reload"][2], t["reload"][3], t["reload"][4], "round")
	buttons["reload"].autoscrollGone = true
	buttons["reload"].gameOnly = true
	buttons["portal1"] = touchButton:new("l", "1", t["portal1"][1], t["portal1"][2], t["portal1"][3], t["portal1"][4], "round")
	buttons["portal1"].portal = true
	buttons["portal2"] = touchButton:new("r", "2", t["portal2"][1], t["portal2"][2], t["portal2"][3], t["portal2"][4], "round")
	buttons["portal2"].portal = true
	
	-- LÖVE 11.0+ Color values normalized to 0.0 - 1.0
	buttons["portal1"].color = {60/255, 188/255, 252/255}
	buttons["portal2"].color = {232/255, 130/255, 30/255}
	
	-- Shift keys to left for 4:3 viewports
	if fourbythree then
		local skip = {"left", "right", "up", "down", "reload", "portal1", "portal2"}
		for i, v in pairs(buttons) do
			if not tablecontains(skip, i) then 
				v.x = v.x - 144
			end
		end
	end

	-- Level Editor Buttons Setup
	local editorButtonsimg = love.graphics.newImage("graphics/GUI/androideditorbuttons.png")
	local editorButtonsq = {}
	local imgHeight = editorButtonsimg:getHeight()
	for i = 1, math.floor(editorButtonsimg:getWidth() / imgHeight) do
		editorButtonsq[i] = love.graphics.newQuad(imgHeight * (i - 1), 0, imgHeight, imgHeight, editorButtonsimg:getWidth(), imgHeight)
	end
	
	local bx, by, bw, bh = t["editor"][1], t["editor"][2], t["editor"][3], t["editor"][4]
	for i = 1, #editorButtons do
		local btnData = editorButtons[i]
		buttons["editor" .. i] = touchButton:new(btnData[1], {editorButtonsimg, editorButtonsq[math.min(#editorButtonsq, btnData[3] or i)]}, bx + (bw + 2) * (i - 1), by, bw, bh)
		buttons["editor" .. i].editor = true
		if i == 1 then buttons["editor" .. i].hideButton = true end
		if btnData[2] then buttons["editor" .. i].highlightFunc = btnData[2] end
	end
	
	for i = 1, #editorToolButtons do
		local btnData = editorToolButtons[i]
		buttons["editorTool" .. i] = touchButton:new(btnData[1], {editorButtonsimg, editorButtonsq[math.min(#editorButtonsq, btnData[3] or i)]}, bx + (bw + 2) * (5 - 1), by + (bh + 2) * i, bw, bh)
		buttons["editorTool" .. i].editor = true
		buttons["editorTool" .. i].editorTool = true
		if btnData[2] then buttons["editorTool" .. i].highlightFunc = btnData[2] end
	end

	-- Multiplayer Setup
	for i = 1, 4 do
		buttons["player" .. i] = touchButton:new(function() androidSetPlayer(i) end, i, bx + (bw + 1) * (i - 1), by, bw, bh)
		buttons["player" .. i].playeri = i
		buttons["player" .. i].highlightFunc = function() if controllingPlayer == i then return true end end
		buttons["player" .. i].drawText = true
		buttons["player" .. i].multiplayerOnly = true
		buttons["player" .. i].gameOnly = true
	end
end

function androidUpdate(dt)
	if androidHIDE then return false end

	for _, b in pairs(buttons) do
		b:update(dt)
	end

	touchClicking = true
	if gamestate == "game" and (not editormode) then
		touchClicking = false
	end

	-- Return to player 1 outside game state
	if gamestate ~= "game" and controllingPlayer ~= 1 then
		controllingPlayer = 1
		buttons["player1"].i()
	end

	-- Update dynamic portal colors from player object
	if objects and objects["player"] and objects["player"][controllingPlayer] then
		buttons["portal1"].color = objects["player"][controllingPlayer].portal1color
		buttons["portal2"].color = objects["player"][controllingPlayer].portal2color
	end
end

function androidDraw()
	if androidHIDE then return false end

	if not androidLowRes then
		love.graphics.push()
		if resizable and letterboxfullscreen then
			local cw, ch = canvas:getWidth(), canvas:getHeight()
			local tw, th = winwidth, winheight
			local s = (cw / tw > ch / th) and (tw / cw) or (th / ch)
			love.graphics.translate(-(((tw * 0.5) - (cw * s * 0.5))), -(((th * 0.5) - (ch * s * 0.5))))
			love.graphics.scale(s, s)
		else
			love.graphics.scale(winwidth / gamewidth, winheight / gameheight)
		end
	end

	if skin then
		skinSpriteBatch:clear()
		for name, b in pairs(buttons) do
			if b.drawText or b.editor then
				b:draw(skinSpriteBatch, skin["editor"])
			else
				b:draw(skinSpriteBatch, skin[name])
			end
		end
		if skin["center"] then
			local _, _, w, h = skin["center"][1]:getViewport()
			skinSpriteBatch:add(skin["center"][1], skinData["center"][1], skinData["center"][2], 0, skinData["center"][3] / w, skinData["center"][4] / h)
		end
		love.graphics.setColor(1, 1, 1) -- LÖVE 11.0+ Compatibility range
		love.graphics.draw(skinSpriteBatch, 0, 0)
		for _, b in pairs(buttons) do
			if skinData.highlightonpress or not b.held then
				b:postDraw()
			end
		end
	else
		for _, b in pairs(buttons) do
			b:draw()
		end
	end

	if not androidLowRes then
		love.graphics.pop()
	end
end

mouseTouchX = gamewidth / 2
mouseTouchY = gameheight / 2
mouseTouchId = false
touchRunLock = false

local touchKey = {}
local touches = {}
local touchesStillDrag = {}

local function getButton(id, x, y)
	for _, b in pairs(buttons) do
		if b.active and b:over(x, y) then
			return b
		end
	end
	return false
end

function androidGetCoords(tx, ty, delta)
	if resizable and letterboxfullscreen then
		local cw, ch = canvas:getWidth(), canvas:getHeight()
		local tw, th = winwidth, winheight
		local s = (cw / tw > ch / th) and (tw / cw) or (th / ch)
		if delta then
			return tx / s, ty / s
		else
			return math.max(0, math.min(cw * s, tx - ((tw * 0.5) - (cw * s * 0.5)))) / s, math.max(0, math.min(ch * s, ty - ((th * 0.5) - (ch * s * 0.5)))) / s
		end
	else
		return tx / (winwidth / gamewidth), ty / (winheight / gameheight)
	end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
	local ox, oy = x, y
	local compX, compY = androidGetCoords(x, y)

	local button = getButton(id, compX, compY)
	if button then
		if button:testPress(id, compX, compY) then
			if button.key then
				touchKey[button.i] = id
			end
			touches[id] = button
			return
		end
		return
	end
	
	if editormode and (not editormenuopen) and ((not rightclickmenuopen) or (customrcopen and customrcopen == "trackpath")) and ANDROIDRIGHTCLICK then
		mouseTouchX = ox
		mouseTouchY = oy
		editor_mousepressed(compX, compY, "r", "simulated")
		return
	end

	mouseTouchX = ox
	mouseTouchY = oy
	mouseTouchId = id
	if touchClicking then
		for _, v in pairs(guielements) do
			v:update(0)
		end
		love.mousepressed(compX, compY, 1, "simulated")
	end
end

function love.touchmoved(id, x, y, dx, dy, pressure)
	local ox, oy = x, y
	local compX, compY = androidGetCoords(x, y)
	local realdx, realdy = androidGetCoords(dx, dy, "delta")

	if mouseTouchId == id and ((not touches[id]) or touchesStillDrag[id]) then
		mouseTouchX = ox
		mouseTouchY = oy
		if touchClicking then
			love.mousemoved(compX, compY, realdx, realdy, "simulated")
		end
	end

	-- Instant optimization: Check if a dynamic sliding gesture hit a new button
	local button1 = getButton(id, compX, compY)
	if button1 and (not button1.held) and button1.editor == false then
		-- Fast track release using our lookup table instead of looping all buttons
		local activeButton = touches[id]
		if activeButton then
			activeButton:release(id, compX, compY)
			if activeButton.key then
				touchKey[activeButton.i] = false
			end
		end
		
		button1:press(id, compX, compY)
		if button1.key then
			touchKey[button1.i] = id
		end
		touches[id] = button1
		touchesStillDrag[id] = true
	end
end

function love.touchreleased(id, x, y, dx, dy, pressure)
	local ox, oy = x, y
	local compX, compY = androidGetCoords(x, y)

	-- Optimized lookup via touch ID mapping table instead of standard 'pairs' loop
	local activeIdxButton = touches[id]
	if activeIdxButton then
		activeIdxButton:release(id, compX, compY)
		if activeIdxButton.key then
			touchKey[activeIdxButton.i] = false
		end
		touches[id] = false
		touchesStillDrag[id] = false
	end

	if mouseTouchId == id then
		mouseTouchX = ox
		mouseTouchY = oy
		mouseTouchId = false
		if touchClicking then
			love.mousereleased(compX, compY, 1, "simulated")
		end
	end
end

function androidButtonDown(i, n)
	if n == "run" and touchRunLock then return true end
	if buttons[n] and buttons[n].player == i and buttons[n].held then return true end
	return false
end

function androidMouseDown(b)
	if mouseTouchId and touchClicking then
		if ANDROIDRIGHTCLICK and b == 2 then return true
		elseif b == 1 then return true end
	end
	if b == 1 and buttons["portal1"].held then return true end
	if b == 2 and buttons["portal2"].held then return true end
	return false
end

function androidGetMouse()
	if resizable and letterboxfullscreen then
		local cw, ch = gamewidth, gameheight
		local tw, th = winwidth, winheight
		local s = (cw / tw > ch / th) and (tw / cw) or (th / ch)
		return math.max(0, math.min(cw * s, mouseTouchX - ((tw * 0.5) - (cw * s * 0.5)))) / s, math.max(0, math.min(ch * s, mouseTouchY - ((th * 0.5) - (ch * s * 0.5)))) / s
	else
		return mouseTouchX / (winwidth / gamewidth), mouseTouchY / (winheight / gameheight)
	end
end

function androidSetPlayer(i)
	controllingPlayer = i
	for _, b in pairs(buttons) do
		b.player = controllingPlayer
	end
end
