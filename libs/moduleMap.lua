--[[

	map module
	
	CTRL+CLICK on Spritesheet - exchange sprite with map correction
	CTRL+SHIFT+Click on Spritesheet - exchange sprite without correction
	A/W/D/S - move Cursor in Spritesheet
	


--]]
modules = modules or {}
local m = {
		name = "Map",
		sort = 20,
	}
table.insert(modules, m)
	
-- set a character in map-areaRect
local function _MapSet(x, y, v)
	if (v == 0 and overArea.buttons.AreaCopy00:IsSelected() == false) or x < overArea.cellRect.x or x >= overArea.page.w + overArea.cellRect.x or y < overArea.cellRect.y or y >= overArea.page.h + overArea.cellRect.y then
		return false				-- out of visible areaRect
	end
	
	return activePico:MapSet(x, y, v)
end

-- Get a character in map-areaRect
local function _MapGet(x, y)
	return activePico:MapGet(x, y)
end

-- here same as _MapGet
local function _MapGetInfo(x, y)
	return activePico:MapGet(x, y), activePico:MapAdr(x,y)
end

-- Draw a character in map-areaRect
local function _MapDraw(x,y,char,alpha)
	tex = TexturesGetSprite()
	tex:SetAlphaMod(alpha)
	tex:SetBlendMode("BLEND")
	
	if char != 0 or overArea.buttons.AreaCopy00:IsSelected() then 
		renderer:Copy(
			tex,
			{x = (char & 0xf) * 8, y = ((char >> 4) & 0xf) * 8, w = 8, h = 8},
			{x, y, overArea.csize, overArea.csize}
		)	
	end
end

-- activate map editing
local function _EnableMapEditing()
		
	overArea.OnRecalc = _EnableMapEditing
	
	-- a screen in Pico8 has 16x16 blocks
	overArea.gridBlock = 16

	-- size of the map
	_,overArea.cellRect.w,overArea.cellRect.h = activePico:MapSize()
					
	-- set handling functions
	overArea.AreaSet = _MapSet
	overArea.AreaGet = _MapGet
	overArea.AreaGetInfo = _MapGetInfo
	overArea.AreaDrawFast = nil
	overArea.AreaDraw = _MapDraw
	overArea.copy.use = overArea.copy.icon
	
	overArea.OnOverviewPicoGenTex = TexturesGetSprite
	overArea.OnOverviewAdr = function(x,y)
		return activePico:SpriteAdr(x*8,y*8)
	end
	
	overArea:BasicLayout()
	
	overArea.buttons.AreaFlags.visible = true
	overArea.buttons.AreaBackground.visible = true
	overArea.buttons.MAPPOS.visible = true
	overArea.buttons.MAPWIDTH.visible = true
	overArea.buttons.OverviewFlags.visible = true
	overArea.buttons.OverviewCount.visible = true
	overArea.buttons.OverviewId.visible = true
	overArea.buttons.AreaHiSel.visible = true
	
end

-- free everything
function m.Quit(m)
	overArea:Quit()
end

-- Initalize
function m.Init(m)
	overArea:Init()
	m.menuBar = overArea.menuBar
	m.buttons = overArea.buttons
	m.inputs = overArea.inputs
	m.scrollbar = overArea.scrollbar
	return true
end

-- Focus got
function m.FocusLost(m)
	-- save some values
	m.oa_size = overArea.csize
	m.oa_cell_x = overArea.cellRect.x
	m.oa_cell_y = overArea.cellRect.y
end

-- Focus lost
function m.FocusGained(m)
	-- restore old settings
	overArea.cellRect.x = m.oa_cell_x or 0
	overArea.cellRect.y = m.oa_cell_y or 0
	overArea.csize = m.oa_size or 32
	_EnableMapEditing()
	MenuSetZoom(overArea.csize)
	m:Resize()
end

-- wheel change zoom
function m.ZoomChange(m, zoom)
	overArea.csize = zoom
	m:Resize()
end

-- Resize
function m.Resize(m)
	if overArea.OnRecalc then overArea.OnRecalc() end
end

-- draw
function m.Draw(m,mx,my)
	overArea:DrawOverview(mx,my)
	overArea:DrawArea(mx,my)		
	overArea:DrawInfoBar()
	
	-- draw map size
	local size,w,h = activePico:MapSize()
	DrawText(overArea.infoMapSize.x, overArea.infoMapSize.y, string.format("%03dx%03d",w,h))		
	DrawText(overArea.infoMapSizeByte.x, overArea.infoMapSizeByte.y, string.format( config.sizeAsHex and " %04x/%04x " or "%05i/%05i", w * h , size))
	
end

-- mouse click
function m.MouseDown(m, mx, my, mb, mbclicks)
	if SDL.Keyboard.GetModState():hasflag("CTRL") > 0 then
		if mb == "LEFT" and overArea.copy.icon.charEnd >=0 and SDL.Rect.ContainsPoint(overArea.overviewRect, {mx, my}) then
			-- CTRL + Click EXCANGE
			-- CTRL + SHIFT + CLICK without map change
			local doMapChange = SDL.Keyboard.GetModState():hasflag("SHIFT") == 0
			local x = (mx - overArea.overviewRect.x) \ overArea.osize
			local y = (my - overArea.overviewRect.y) \ overArea.osize

			for dy = 1,#overArea.copy.icon.a do
				for dx =1, #overArea.copy.icon.a[1] do					
					local posFrom = overArea.copy.icon.a[dy][dx]
					local posTo = (x + (y<<4) + (dy - 1) * 16 + (dx - 1)) % 255
					local adrFrom = activePico:SpriteAdr(posFrom)
					local adrTo = activePico:SpriteAdr(posTo)
					
					for m =0,7 do
						local a = activePico:Peek32(adrFrom)
						activePico:Poke32(adrFrom, activePico:Peek32(adrTo) )
						activePico:Poke32(adrTo, a)
						adrFrom += 64
						adrTo += 64
					end
					
					if doMapChange then 
						for yy = 0, overArea.cellRect.h -1 do
							for xx = 0, overArea.cellRect.w - 1 do
								local a = activePico:MapGet(xx,yy)
								if a == posTo then
									activePico:MapSet(xx,yy,posFrom)
								elseif a == posFrom then
									activePico:MapSet(xx,yy,posTo)
								end
							end
						end
					end
					
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

-- set a color in sprite-areaRect
local function _SpriteSet(x, y, v)
	if x < 0 or x >= #overArea.copy.icon.a[1] * 8 or y < 0 or y >= #overArea.copy.icon.a * 8 then
		return false			-- outside the sprite
	end
	
	local char = overArea.copy.icon.a[ y \ 8 + 1 ][ x \ 8 + 1 ]	-- get the sprite out of sprite-copy

	activePico:SpriteSetPixel(
		(char & 0xf) * 8 + (x % 8),
		((char >> 4) & 0xf) * 8 + (y % 8),
		v
	)
	
	return true
end

-- get a color in sprite-areaRect
local function _SpriteGet(x,y)
	if x < 0 or x >= #overArea.copy.icon.a[1] * 8 or y < 0 or y >= #overArea.copy.icon.a * 8 then
		return 0				-- outside - always black
	end
	
	local char = overArea.copy.icon.a[ y \ 8 + 1 ][ x \ 8 + 1 ]	-- get the sprite out of sprite-copy

	return activePico:SpriteGetPixel(
		(char & 0xf) * 8 + (x % 8),
		((char >> 4) & 0xf) * 8 + (y % 8)
	)
end

-- copy sprite to clipboard
function m.Copy(m)
	local w,h = math.min(128,#overArea.copy.icon.a[1] * 8) , math.min(128, #overArea.copy.icon.a * 8)
	local ret = string.format("[gfx]%02x%02x",w,h )
	for y = 0, h - 1 do 
		for x = 0, w - 1 do
			ret ..= string.format("%01x", _SpriteGet(x,y))
		end
	end
	
	ret ..="[/gfx]"
	
	InfoBoxSet("Copied "..w.."x"..h.." sprite.")
	
	return ret
end

-- paste sprite from clipboard
function m.Paste(m,str)
	if str:sub(1,5) != "[gfx]" or str:sub(-6,-1) != "[/gfx]" then
		return nil
	end
	local w, h = tonumber("0x" .. str:sub(6,7)) or 0, tonumber("0x" .. str:sub(8,9)) or 0
	
	local xs,ys = overArea.copy.icon.char & 0xf , overArea.copy.icon.char >> 4 
	local xe,ye = math.clamp(0, 15, xs + w \ 8 - 1), math.clamp(0,15, ys + h \ 8 - 1)
	overArea.copy.icon.charEnd = xe + (ye << 4)
	
	overArea.copy.icon.a = {}
	for y = ys, ye do
		local t = {}
		for x = xs, xe do
			table.insert(t, x + (y << 4))
		end
		table.insert(overArea.copy.icon.a, t)
	end
	
	local pos = 10	
	for y = 0,  h - 1 do
		for x = 0,  w - 1 do
			_SpriteSet(x, y, tonumber("0x"..str:sub(pos,pos)) or 0 )
			pos += 1
		end
	end

end

-- Delete sprites
function m.Delete(m)	
	local w,h = math.min(128,#overArea.copy.icon.a[1] * 8) , math.min(128, #overArea.copy.icon.a * 8)
	for y = 0, h - 1 do 
		for x = 0, w - 1 do
			_SpriteSet(x, y, 0)
		end
	end
end

-- wheel change zoom
function m.MouseWheel(m,x,y,mx,my)
	MenuRotateZoom(y > 0) 
end

-- Keyboard handling
function m.KeyDown(m, sym, scan, mod)
	if mod:hasflag("CTRL ALT GUI") > 0 then return nil end
	
	local off
	if scan == "A" then
		off = -1
	elseif scan == "D" then
		off = 1
	elseif scan == "W" then
		off = -16
	elseif scan == "S" then
		off = 16
	end
	
	if off then 
		if mod:hasflag("SHIFT") == 0 then
			if overArea.copy.icon.char + off >= 0 and overArea.copy.icon.char + off <= 255 then
				overArea.copy.icon.char += off
				overArea.copy.icon.charEnd = overArea.copy.icon.char
				overArea:CreateListCopyIconA()
			end
		elseif overArea.copy.icon.charEnd >= 0 then
			if overArea.copy.icon.charEnd + off >= 0 and overArea.copy.icon.charEnd + off <= 255 then
				overArea.copy.icon.charEnd += off
				overArea:CreateListCopyIconA()
			end
		end
	end
	
end


return m
