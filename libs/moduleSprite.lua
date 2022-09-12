
modules = modules or {}

local m = {
	name = "Sprite",
	sort = 30,
	Init = nil,
	Quit = nil,
	FocusGained = nil,
	FocusLost = nil,
	Draw = nil,
	onMouseUp = nil,
	onMouseDown = nil,
	onMouseMove = nil,
	ZoomChange = nil,
	Resize = nil,
	Copy = nil,
	Paste = nil,
	Delete = nil,
	Input = nil,
}


table.insert(modules, m)

-- set a color in sprite-areaRect
local function spriteSet(x, y, v)
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
local function spriteGet(x,y)
	if x < 0 or x >= #overArea.copy.icon.a[1] * 8 or y < 0 or y >= #overArea.copy.icon.a * 8 then
		return 0				-- outside - always black
	end
	
	local char = overArea.copy.icon.a[ y \ 8 + 1 ][ x \ 8 + 1 ]	-- get the sprite out of sprite-copy

	return activePico:SpriteGetPixel(
		(char & 0xf) * 8 + (x % 8),
		((char >> 4) & 0xf) * 8 + (y % 8)
	)
end

-- for "mutlisprite"-selection get the actual character in the copy
local function spriteGetInfo(x,y)
	if x < 0 or x >= #overArea.copy.icon.a[1] * 8 or y < 0 or y >= #overArea.copy.icon.a * 8 then
		return nil
	end
	local c = overArea.copy.icon.a[y \ 8 + 1][x \ 8 + 1]
	return c, activePico:SpriteAdr((c & 0xf)*8, (c >> 4)*8) 	-- get the sprite out of sprite-copy
end

-- draw a color in sprite-areaRect
local function spriteDraw(x, y, v, alpha)
	if v != 0 or overArea.buttons.AreaCopy00:IsSelected() then 
		DrawFilledRect({x, y, overArea.csize, overArea.csize}, activePico:PaletteGetRGB(v), alpha)
	end
end

local function spriteDrawFast(oa, alpha)
	local cx = math.clamp(oa.cellRect.x \ 8 + 1, 1, #overArea.copy.icon.a[1])
	local cy = math.clamp(oa.cellRect.y \ 8 + 1, 1, #overArea.copy.icon.a)
	local cx2 = math.clamp( cx + (oa.page.w + 7) \ 8, 1, #overArea.copy.icon.a[1])
	local cy2 = math.clamp( cy + (oa.page.h + 7) \ 8, 1, #overArea.copy.icon.a)
	local xx = oa.areaRect.x - (oa.cellRect.x % 8) * overArea.csize
	local yy = oa.areaRect.y - (oa.cellRect.y % 8) * overArea.csize
	
	local tex = TexturesGetSprite()
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

-- Draw Animation
local function draw_animation()
	if not overArea.buttons.AnimStart:IsSelected() then
		overArea.inputs.AnimSpeed.visible = false
		overArea.buttons.AnimSwing.visible = false
		overArea.buttons.AnimWidth.visible = false
		return
	end
	
	overArea.inputs.AnimSpeed.visible = true
	overArea.buttons.AnimSwing.visible = true
	overArea.buttons.AnimWidth.visible = true
	
	local w = overArea.buttons.AnimWidth.selected and 2 or 1
	local h = math.clamp(1, #overArea.copy.icon.a, 2)
	local speed = math.clamp(1, tonumber( overArea.inputs.AnimSpeed.text), 20)		
	overArea.inputs.AnimSpeed.text = tostring(speed)
		
	local ax = math.max(1, #overArea.copy.icon.a[1] \ w)
	local tex = TexturesGetSprite()
	tex:SetAlphaMod(255)
	tex:SetBlendMode("NONE")
	
	overArea.animCount = (overArea.animCount + 1) % speed
	if overArea.animCount == 0 then		
		overArea.animPose = (overArea.animPose + 1) % ( overArea.buttons.AnimSwing.selected and math.max(1,ax * 2 - 2) or ax )
	end
	
	local pose = overArea.animPose
	
	if pose >= ax then
		pose = ax - (pose - ax + 2 )
	end
					
	local mx = overArea.animRect.x + (overArea.animRect.w - overArea.osize * w) / 2
	local my = overArea.animRect.y + (overArea.animRect.h - overArea.osize * h) / 2
	DrawBorder(mx, my, w * overArea.osize, h * overArea.osize, COLGREY)
					
	local yy = my
	for y = 1, h do
		local xx = mx
		
		for x = 1,w do 
		
			local t = overArea.copy.icon.a[y]
			if t then
				local char = t[x + pose * w]
				if char != nil and char >= 0 and char <= 255 then
					renderer:Copy( 
						tex,
						{x = (char  & 0xf) * 8, y = ((char  >> 4) & 0xf) * 8, w = 8, h = 8},
						{xx,yy, overArea.osize, overArea.osize}								
					)						
				end
			end
			xx += overArea.osize
			
		end
		yy += overArea.osize
	end
end

-- activate sprite editing
local function enableSpriteEditing()
	
	overArea.OnRecalc = enableSpriteEditing
	
	-- a sprite is 8x8 pixels
	overArea.gridBlock = 8

	-- we use the copy.icon to render the areaRect
	overArea.cellRect.w,overArea.cellRect.h = #overArea.copy.icon.a[1] * 8, #overArea.copy.icon.a * 8
	
	-- Set handling-functions
	overArea.AreaSet = spriteSet
	overArea.AreaGet = spriteGet
	overArea.AreaGetInfo = spriteGetInfo
	overArea.AreaDraw = spriteDraw	
	overArea.AreaDrawFast = spriteDrawFast
	overArea.copy.use = overArea.copy.col
		
	overArea.OnOverviewPicoGenTex = TexturesGetSprite
	overArea.OnOverviewAdr = function(x,y)
		return activePico:SpriteAdr(x*8,y*8)
	end
	
	m.oldCopyW, m.oldCopyH = #overArea.copy.icon.a[1], #overArea.copy.icon.a
	
	
	overArea:BasicLayout()
	
	for i=0,0xf do
		overArea.buttons["Color"..i].visible = true
	end
	
	overArea.buttons.OverviewFlags.visible = true
	overArea.buttons.OverviewCount.visible = true
	overArea.buttons.AnimStart.visible = true
	overArea.buttons.OverviewId.visible = true	
	
	overArea.buttons.SPRITEPOS.visible = true
	overArea.buttons.SPRFLAGPOS.visible = true
	overArea.buttons.sprIcon.visible = true 
	
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

-- Allow other modules to switch the current sprite
function m.API_SetSprite(m, nb)
	ModuleActivate(m)
	overArea.copy.icon.char = math.clamp(0, 255, nb) 
	overArea.copy.icon.charEnd = overArea.copy.icon.char 
	overArea.copy.icon.a = {{overArea.copy.icon.char}}
end


function m.Quit(m)
	overArea:Quit()
end

function m.Init(m)
	overArea:Init()

	m.menuBar = overArea.menuBar
	m.buttons = overArea.buttons
	m.inputs = overArea.inputs
	m.scrollbar = overArea.scrollbar
	return true
end

function m.FocusLost(m)
	-- save some values
	m.oa_size = overArea.csize
	m.oa_cell_x = overArea.cellRect.x
	m.oa_cell_y = overArea.cellRect.y
end

function m.FocusGained(m)
	overArea.cellRect.x = m.oa_cell_x or 0
	overArea.cellRect.y = m.oa_cell_y or 0
	overArea.csize = m.oa_size or 32
	enableSpriteEditing()		
	if config.doAutoOverviewZoom then 
		overArea:OverviewBestZoom()		
	else
		MenuSetZoom(overArea.csize)
	end
	m:Resize()
end

function m.ZoomChange(m, zoom)
	overArea.csize = zoom
	m:Resize()
end

function m.Resize(m)
	if overArea.OnRecalc then overArea.OnRecalc() end
	
	overArea.animRect.x = overArea.buttons.OverviewCount.rectBack.x + overArea.buttons.OverviewCount.rectBack.w + 5
	overArea.animRect.y = overArea.buttons.OverviewCount.rectBack.y 
	overArea.animRect.w = overArea.overviewRect.x + overArea.overviewRect.w - overArea.animRect.x
	overArea.animRect.h = overArea.buttons.OverviewCount.rectBack.h * 2 + 5

end

function m.Draw(m, mx, my)
	--update Color-Buttons
	local selColor = {}
	for nb,t in pairs( overArea.copy.col.a ) do
		for nb, id in pairs(t) do
			selColor[id] = true
		end
	end
	
	for i = 0, 0xf do
		local b,c = overArea.buttons["Color" .. i], activePico:PaletteGetColor(i)
		b.selected = selColor[i] and true or false
		if b.ColorIndex != c then
			b.ColorIndex = c
			b:SetColor( Pico.RGB[c] )
		end
	end
	
	-- selection-size changed?
	if m.oldCopyW != #overArea.copy.icon.a[1] or m.oldCopyH != #overArea.copy.icon.a then
		-- copy.icon size has changed -> autozoom
		if config.doAutoOverviewZoom then 
			overArea:OverviewBestZoom()
		else
			m:Resize()
		end
	end
		
	overArea:DrawOverview(mx,my)
	overArea:DrawArea(mx,my)		
	overArea:DrawInfoBar()
	draw_animation()
end
	
function m.MouseDown(m, mx, my, mb, mbclicks)
	if SDL.Keyboard.GetModState():hasflag("CTRL") > 0 then
		if overArea.copy.icon.charEnd >=0 and SDL.Rect.ContainsPoint(overArea.overviewRect, {mx, my}) then
			local doMapChange = SDL.Keyboard.GetModState():hasflag("SHIFT") == 0
			local x = (mx - overArea.overviewRect.x) \ overArea.osize
			local y = (my - overArea.overviewRect.y) \ overArea.osize
			local cw,ch
			_,cw,ch = activePico:MapSize()

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
						for yy = 0, ch -1 do
							for xx = 0, cw - 1 do
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

function m.MouseMove(m, mx, my, mb)
	overArea:MouseMoveOverview(mx, my, mb)
	overArea:MouseMoveArea(mx, my, mb)
end

function m.MouseUp(m, mx,my,mb, mbclicks)
	if not overArea.scrollbar:MouseUp(mx, my, mb, mbclicks) then
		overArea.buttons:MouseUp(mx, my, mb, mbclicks)
		overArea:MouseUpOverview(mx, my, mb, mbclicks)
		overArea:MouseUpArea(mx, my, mb, mbclicks)
	end
end

function m.Copy(m)
	local w,h = math.min(128,#overArea.copy.icon.a[1] * 8) , math.min(128, #overArea.copy.icon.a * 8)
	local ret = string.format("[gfx]%02x%02x",w,h )
	for y = 0, h - 1 do 
		for x = 0, w - 1 do
			ret ..= string.format("%01x", spriteGet(x,y))
		end
	end
	
	ret ..="[/gfx]"
	
	InfoBoxSet("Copied "..w.."x"..h.." sprite.")
	
	return ret
end

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
			spriteSet(x, y, tonumber("0x"..str:sub(pos,pos)) or 0 )
			pos += 1
		end
	end
	
	if config.doAutoOverviewZoom then 
		overArea:OverviewBestZoom()		
	end
	m:Resize()
end

function m.Delete(m)	
	local w,h = math.min(128,#overArea.copy.icon.a[1] * 8) , math.min(128, #overArea.copy.icon.a * 8)
	for y = 0, h - 1 do 
		for x = 0, w - 1 do
			spriteSet(x, y, 0)
		end
	end
end

function m.MouseWheel(m,x,y,mx,my)
	MenuRotateZoom(y > 0) 
end

function m.KeyDown(m, sym, scan, mod)
	if mod:hasflag("CTRL ALT GUI") > 0 then return nil end
	
	
	local off, coff
	if scan == "A" then
		off = -1
	elseif scan == "D" then
		off = 1
	elseif scan == "W" then
		off = -16
	elseif scan == "S" then
		off = 16
	elseif scan == "Q" then
		coff = -1
	elseif scan == "E" then
		coff = 1
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
	
	if coff then
		overArea.copy.col.char = (overArea.copy.col.char + coff) % 16
		overArea.copy.col.charEnd = overArea.copy.col.char 
		overArea.copy.col.a = {{overArea.copy.col.char}}
	end
	
	-- hack ^ = 0
	if scan == "GRAVE" then sym = "0" end
	if sym >= "0" and sym <= "7" then
		if mod:hasflag("SHIFT")== 0 then
			overArea.copy.col.char = tonumber(sym) 
		else
			overArea.copy.col.char = tonumber(sym) + 8
		end
		overArea.copy.col.charEnd = overArea.copy.col.char 
		overArea.copy.col.a = {{overArea.copy.col.char}}
	end
	
	
end

return m
