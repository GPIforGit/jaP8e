--[[

	Character-Creation
	
	CTRL + LMB in font -- Exchange Character
	
	CTRL + C -- copy character as print-string for pico8
	CTRL + V -- paste charater from print-string
	
	[keyboard] -- select entered key in charset

--]]

modules = modules or {}
local m = {
	name = "Font",
	sort = 70,	
}
table.insert(modules, m)

-- some example-texts
local _LAZYDOGTEXT =  {
	" the quick brown fox \n jumps over the lazy dog ",
	" THE QUICK BROWN FOX \n JUMPS OVER THE LAZY DOG ",
	" The Quick Brown Fox \n Jumps Over The Lazy Dog ",
	" tHE qUICK bROWN fOX \n jUMPS oVER tHE lAZY dOG ",
	" █▒🐱⬇️░✽●♥☉웃⌂⬅️😐 \n ♪🅾️◆…➡️★⧗⬆️ˇ∧❎▤▥ ",
	" 0123456789 !\"#$%'()*+ \n ,-./:;<=>?@[\\]^_`{|}~ "
}
local _lazyDogNb = 1
local _rectLazy = {}

-- set a color in char-areaRect
local function _CharsetSet(x, y, v)
	if x < 0 or x >= #overArea.copy.icon.a[1] * 8 or y < 0 or y >= #overArea.copy.icon.a * 8 then
		return false			-- outside the char
	end
	
	local char = overArea.copy.icon.a[ y \ 8 + 1 ][ x \ 8 + 1 ]	-- get the char out of icon

	activePico:CharsetSetPixel(
		(char & 0xf) * 8 + (x % 8),
		((char >> 4) & 0xf) * 8 + (y % 8),
		v
	)
	
	return true
end

-- get a color in char-areaRect
local function _CharsetGet(x,y)
	if x < 0 or x >= #overArea.copy.icon.a[1] * 8 or y < 0 or y >= #overArea.copy.icon.a * 8 then
		return 0				-- outside - always black
	end
	
	local char = overArea.copy.icon.a[ y \ 8 + 1 ][ x \ 8 + 1 ]	-- get the char out of copy.icon

	return activePico:CharsetGetPixel(
		(char & 0xf) * 8 + (x % 8),
		((char >> 4) & 0xf) * 8 + (y % 8)
	)
end

-- for "mutlicharacter"-selection get the actual character in the copy
local function _CharsetGetInfo(x,y)
	if x < 0 or x >= #overArea.copy.icon.a[1] * 8 or y < 0 or y >= #overArea.copy.icon.a * 8 then
		return nil
	end
	local c = overArea.copy.icon.a[ y \ 8 + 1 ][ x \ 8 + 1 ]
	--local xx,yy = c & 0xf, c >> 4 & 0xf
	return c, c*8 + Pico.CHARSET + (y % 8) 	-- char and adress
end

-- draw a color in char-areaRect
local function _CharsetDraw(x, y, v, alpha)
	if v != 0 then v = 7 else v= 0 end
	if v != 0 or overArea.buttons.AreaCopy00:IsSelected() then 
		DrawFilledRect({x, y, overArea.csize, overArea.csize}, Pico.RGB[v], alpha)
	end
end

-- faster draw. Instead of drawing each pixel, we strecht the Charset-Texture
local function _CharsetDrawFast(oa, alpha)
	local cx = math.clamp(oa.cellRect.x \ 8 + 1, 1, #overArea.copy.icon.a[1])
	local cy = math.clamp(oa.cellRect.y \ 8 + 1, 1, #overArea.copy.icon.a)
	local cx2 = math.clamp( cx + (oa.page.w + 7) \ 8, 1, #overArea.copy.icon.a[1])
	local cy2 = math.clamp( cy + (oa.page.h + 7) \ 8, 1, #overArea.copy.icon.a)
	local xx = oa.areaRect.x - (oa.cellRect.x % 8) * overArea.csize
	local yy = oa.areaRect.y - (oa.cellRect.y % 8) * overArea.csize
	
	local tex = TexturesGetCharset()
	local size = overArea.csize * 8
	
	tex:SetAlphaMod(alpha)
	tex:SetBlendMode("BLEND")
	
	local py = yy
	for y=cy, cy2 do
		local px = xx
		for x=cx, cx2 do
			char = overArea.copy.icon.a[y][x]
		
			renderer:Copy(tex, {(char & 0xf) * 8, (char >>4) * 8, 8,8}, {px, py, size,size})
			px += size
		end
		py += size
	end
end

-- draw lazy-dog text
local function _DrawLazyDog()
	renderer:SetClipRect( _rectLazy )
	DrawFilledRect( _rectLazy, COLBLACK)
	local t1,t2 = "",""
	t1 = activePico:StringUTF8toPico(_LAZYDOGTEXT[_lazyDogNb]:match("(.+)\n.+"))
	t2 = activePico:StringUTF8toPico(_LAZYDOGTEXT[_lazyDogNb]:match(".+\n(.+)"))
		
	local w1,h1 = SizePicoText(t1)	
	local w2,h2 = SizePicoText(t2)	
	
	local x,y = DrawPicoText(_rectLazy.x + (_rectLazy.w - w1) / 2, _rectLazy.y + (_rectLazy.h - h1 - h2) / 2, t1)
				DrawPicoText(_rectLazy.x + (_rectLazy.w - w2) / 2, y, t2)
	renderer:SetClipRect( nil )
end

-- activate charset editing
local function _EnableCharsetEditing()
	-- set for recalculation
	overArea.OnRecalc = _EnableCharsetEditing
	
	-- a char is 8x8 pixels
	overArea.gridBlock = 8

	-- we use the copy.icon to render the areaRect
	overArea.cellRect.w,overArea.cellRect.h = #overArea.copy.icon.a[1] * 8, #overArea.copy.icon.a * 8
	
	-- Set handling-functions
	overArea.AreaSet = _CharsetSet
	overArea.AreaGet = _CharsetGet
	overArea.AreaGetInfo = _CharsetGetInfo
	overArea.AreaDraw = _CharsetDraw
	overArea.AreaDrawFast = _CharsetDrawFast
	overArea.copy.use = overArea.copy.col
	
	overArea.OnOverviewPicoGenTex = TexturesGetCharset
	overArea.OnOverviewAdr = function(x,y)
		return (x + (y<<4)) * 8 + Pico.CHARSET
	end
	
	m.oldCopyW, m.oldCopyH = #overArea.copy.icon.a[1], #overArea.copy.icon.a
	
	
	overArea:BasicLayout()
	
	-- we need the color-button
	for i=0,0xf do
		overArea.buttons["Color"..i].visible = true
	end
	
	-- and some buttons / inputs
	overArea.inputs.CharLowWidth.visible = true
	overArea.inputs.CharHighWidth.visible = true
	overArea.inputs.CharHeight.visible = true
	overArea.inputs.CharOffsetX.visible = true
	overArea.inputs.CharOffsetY.visible = true
	overArea.buttons.OverviewId.visible = true
	overArea.inputs.CharAdjust.visible = true
	overArea.buttons.CharAdjustEnable.visible = true
	overArea.buttons.CharOneUp.visible = true

	-- rearange to settings-buttons
	overArea.buttons.OverviewId:SetLeft( overArea.buttons.AreaCopy00)
	overArea.buttons.OverviewGrid:SetLeft()
	
	-- Activvate special grid
	overArea.doCharsetGrid = true
	
	-- only visible, when not a random set of characters are selected
	if overArea.copy.icon.charEnd >= 0 then
		overArea.buttons.AreaFlipX.visible = true
		overArea.buttons.AreaFlipY.visible = true
		if overArea.cellRect.w == overArea.cellRect.h then 
			overArea.buttons.AreaTurnLeft.visible = true
			overArea.buttons.AreaTurnRight.visible = true
		end
		overArea.buttons.AreaShiftLeft.visible = true
		overArea.buttons.AreaShiftRight.visible = true
		overArea.buttons.AreaShiftUp.visible = true
		overArea.buttons.AreaShiftDown.visible = true
	end
	
end

-- Allow other modules to switch on character
function m.API_SetCharacter(m, nb)
	ModuleActivate(m)
	overArea.copy.icon.char = math.clamp(0, 255, nb) 
	overArea.copy.icon.charEnd = overArea.copy.icon.char 
	overArea.copy.icon.a = {{overArea.copy.icon.char}}
end

-- release all resources
function m.Quit(m)
	overArea:Quit()
end

-- initalize
function m.Init(m)
	overArea:Init()
	-- we use the overArea controls/menu
	m.menuBar = overArea.menuBar
	m.buttons = overArea.buttons
	m.inputs = overArea.inputs
	m.scrollbar = overArea.scrollbar
	return true
end

-- lost focus
function m.FocusLost(m)
	-- save some values
	m.oa_size = overArea.csize -- zoom factor
	m.oa_cell_x = overArea.cellRect.x -- scroll-position
	m.oa_cell_y = overArea.cellRect.y
end

-- get focus
function m.FocusGained(m)
	overArea.cellRect.x = m.oa_cell_x or 0
	overArea.cellRect.y = m.oa_cell_y or 0
	overArea.csize = m.oa_size or 32
	_EnableCharsetEditing()		
	if config.doAutoOverviewZoom then 
		overArea:OverviewBestZoom()		
	else
		MenuSetZoom(overArea.csize)
	end
	m:Resize()
end

-- Zoom handling
function m.ZoomChange(m, zoom)
	overArea.csize = zoom
	m:Resize()
end

-- resize
function m.Resize(m)
	if overArea.OnRecalc then overArea.OnRecalc() end
	
	-- lazy dog
	local ow, oh = renderer:GetOutputSize()
	local _,s = overArea.buttons:GetSize("+")
	local ButtonAreaHeight = 5 + (s + 1) * 4
	local downY = oh - ButtonAreaHeight
	_rectLazy.x = overArea.overviewRect.x
	_rectLazy.y = downY - BARSIZE
	_rectLazy.w = overArea.overviewRect.w
	_rectLazy.h = oh - overArea.buttons.Flag0.rectBack.h - 5 -10 - _rectLazy.y
	
end

-- draw mmodule
function m.Draw(m, mx, my)
	-- update adjust
	local char = overArea.copy.icon.a[1][1]
	local adjust,oneup = activePico:CharsetGetVariable(char)
	if not m.inputs:HasFocus() then
		overArea.inputs.CharAdjust.text = tostring(adjust)
	end
	overArea.buttons.CharAdjustEnable.selected = activePico:Peek(Pico.CHARSET + 5) & 1 == 1
	overArea.buttons.CharOneUp.selected = oneup


	--update Color-Buttons
	local selColor = {}
	for nb,t in pairs( overArea.copy.col.a ) do
		for nb, id in pairs(t) do
			selColor[(id > 0) and 1 or 0] = true
		end
	end
	
	for i = 0, 0xf do
		local b,c = overArea.buttons["Color" .. i], (i > 0) and 7 or 0
		b.selected = selColor[(i>0) and 1 or 0] and true or false
		if b.ColorIndex != c then
			b.ColorIndex = c
			b:SetColor( Pico.RGB[c] )
		end
	end
		
	-- selection-size changed?	
	if m.oldCopyW != #overArea.copy.icon.a[1] or m.oldCopyH != #overArea.copy.icon.a then
		-- copy.icon size has changed -> autozoom
		if config.doAutoOverviewZoom then 
			overArea:OverviewBestZoom(overArea)
		else
			m:Resize()
		end
	end
	
	-- draw everything
	overArea:DrawOverview(mx,my)
	overArea:DrawArea(mx,my)		
	overArea:DrawInfoBarCharset()
	_DrawLazyDog()
	overArea.buttons:Draw(mx,my)
	overArea.inputs:Draw(mx,my)
	overArea.scrollbar:Draw(mx,my)
end

-- mouse handling
function m.MouseDown(m, mx, my, mb, mbclicks)

	if SDL.Keyboard.GetModState():hasflag("CTRL") > 0 then
		-- exchange chars
		if overArea.copy.icon.charEnd >=0 and SDL.Rect.ContainsPoint(overArea.overviewRect, {mx, my}) then
			local x = (mx - overArea.overviewRect.x) \ overArea.osize
			local y = (my - overArea.overviewRect.y) \ overArea.osize

			for dy = 1,#overArea.copy.icon.a do
				for dx =1, #overArea.copy.icon.a[1] do					
					local posFrom = overArea.copy.icon.a[dy][dx]
					local posTo = (x + (y<<4) + (dy - 1) * 16 + (dx - 1)) % 255
					local adrFrom = Pico.CHARSET + posFrom * 8
					local adrTo = Pico.CHARSET + posTo * 8
					
					
					local a = activePico:Peek32(adrFrom)
					activePico:Poke32(adrFrom, activePico:Peek32(adrTo) )
					activePico:Poke32(adrTo, a)
					adrFrom += 4
					adrTo += 4
					a = activePico:Peek32(adrFrom)
					activePico:Poke32(adrFrom, activePico:Peek32(adrTo) )
					activePico:Poke32(adrTo, a)
										
					if overArea.copy.icon.char == posFrom then
						overArea.copy.icon.char = posTo
					end
					if overArea.copy.icon.charEnd == posFrom then
						overArea.copy.icon.charEnd = posTo
					end
					overArea.copy.icon.a[dy][dx] = posTo
					
				end
			end
			
			
			
		end

	else
		overArea:MouseDownOverview(mx, my, mb, mbclicks)
		overArea:MouseDownArea(mx, my, mb, mbclicks)
		
		if SDL.Rect.ContainsPoint(_rectLazy, {mx, my}) then
			_lazyDogNb = math.rotate(_lazyDogNb + (mb == "LEFT" and 1 or -1), 1, #_LAZYDOGTEXT)
		end
		
	end

end

-- mouse move
function m.MouseMove(m, mx, my, mb)
	overArea:MouseMoveOverview(mx, my, mb)
	overArea:MouseMoveArea(mx, my, mb)
end

-- mouse up
function m.MouseUp(m, mx,my,mb, mbclicks)
	overArea:MouseUpOverview(mx, my, mb, mbclicks)
	overArea:MouseUpArea(mx, my, mb, mbclicks)
end

-- paste to clipboard
function m.Paste(m, str)
	if str:sub(1,1) == "\"" and str:sub(-1,-1) == "\"" then
		str = str:sub(2,-2)
	end

	if str:sub(1,3) == "\\^:" then
		local c = overArea.copy.icon.a[1][1]
		if c <= 0 or c > 255 then return nil end
		local adr = c * 8 + Pico.CHARSET
		
		activePico:PokeHex(adr, str:sub(4), 8)
				
		overArea.copy.icon.a={{c}}
		overArea.copy.icon.char = c
		overArea.copy.icon.charEnd = c
		if config.doAutoOverviewZoom then 
			overArea:OverviewBestZoom()		
		end
		m:Resize()
		
	elseif str:sub(1,3) == "\\^." then
		local c = overArea.copy.icon.a[1][1]
		if c <= 0 or c > 255 then return nil end
		local adr = c * 8 + Pico.CHARSET
		
		activePico:PokeChar(adr, str:sub(4), 8)
				
		overArea.copy.icon.a={{c}}
		overArea.copy.icon.char = c
		overArea.copy.icon.charEnd = c
		if config.doAutoOverviewZoom then 
			overArea:OverviewBestZoom()		
		end
		m:Resize()
		
	end	
end

-- copy character to clipboard
function m.Copy(m)
	local c = overArea.copy.icon.a[1][1]
	if c <= 0 or c > 255 then return nil end
	local adr = c * 8 + Pico.CHARSET
	local str
	if config.clipboardAsHex then 
		str = "\\^:".. activePico:PeekHex(adr,8)
	else
		str = "\\^.".. activePico:PeekChar(adr,8)
	end
	
	overArea.copy.icon.a={{c}}
	overArea.copy.icon.char = c
	overArea.copy.icon.charEnd = c
	if config.doAutoOverviewZoom then 
		overArea:OverviewBestZoom()		
	end
	m:Resize()
	
	InfoBoxSet("Copied character.")
	
	return str
end

-- delete characters from charset
function m.Delete(m)
	if overArea.inputs:HasFocus() then return end

	for _,t in pairs(overArea.copy.icon.a) do
		for _,c in pairs(t) do
			if c > 0 and c <= 255 then 
				local adr = c * 8 + Pico.CHARSET
				activePico:MemorySet(adr, 0, 8)
			end
		end
	end
	
end

-- input
function m.Input(m, str)
	if overArea.inputs:Input(str) then
		return true
	end

	-- select entered character
	local c = activePico:StringUTF8toPico(str):byte(1) or 0
	
	overArea.copy.icon.a={{c}}
	overArea.copy.icon.char = c
	overArea.copy.icon.charEnd = c
	if config.doAutoOverviewZoom then 
		overArea:OverviewBestZoom()		
	end
	m:Resize()	
	
end

-- mousewheel change zoom
function m.MouseWheel(m,x,y,mx,my)
	MenuRotateZoom(y > 0) 
end

	
return m
