--[[
	label module
	
	very basic module to edit labels

--]]


modules = modules or {}
local m = {
		name = "Label",
		sort = 60,	
	}
table.insert(modules, m)

-- set a color in label-areaRect
local function _LabelSet(x, y, v)
	if x < 0 or x >= #overArea.copy.icon.a[1] * 8 or y < 0 or y >= #overArea.copy.icon.a * 8 then
		return false			-- outside the label
	end
	
	local char = overArea.copy.icon.a[ y \ 8 + 1 ][ x \ 8 + 1 ]	

	activePico:LabelSetPixel(
		(char & 0xf) * 8 + (x % 8),
		((char >> 4) & 0xf) * 8 + (y % 8),
		v
	)
	
	return true
end

-- get a color in label-areaRect
local function _LabelGet(x,y)
	if x < 0 or x >= #overArea.copy.icon.a[1] * 8 or y < 0 or y >= #overArea.copy.icon.a * 8 then
		return 0 -- outside - always black
	end
	
	local char = overArea.copy.icon.a[ y \ 8 + 1 ][ x \ 8 + 1 ]	

	return activePico:LabelGetPixel(
		(char & 0xf) * 8 + (x % 8),
		((char >> 4) & 0xf) * 8 + (y % 8)
	)
end

-- for "mutlisprite"-selection get the actual character in the copy
local function _LabelGetInfo(x,y)
	if x < 0 or x >= #overArea.copy.icon.a[1] * 8 or y < 0 or y >= #overArea.copy.icon.a * 8 then
		return nil
	end
	local c = overArea.copy.icon.a[ y \ 8 + 1 ][ x \ 8 + 1 ]
	local xx,yy = c & 0xf, c >> 4 & 0xf
	return c, xx*4 + yy*64*8 + (x%8)\2 + (y%8)*64  + activePico.Label
end

-- draw a color in sprite-areaRect
local function _LabelDraw(x, y, v, alpha)
	if v != 0 or overArea.buttons.AreaCopy00:IsSelected() then 
		DrawFilledRect({x, y, overArea.csize, overArea.csize}, Pico.RGB[v & 0xff], alpha)
	end
end

-- draw area fast - we strecht parts of the label instead of drawing every pixel
local function _LabelDrawFast(oa, alpha)
	local cx = math.clamp(oa.cellRect.x \ 8 + 1, 1, #overArea.copy.icon.a[1])
	local cy = math.clamp(oa.cellRect.y \ 8 + 1, 1, #overArea.copy.icon.a)
	local cx2 = math.clamp( cx + (oa.page.w + 7) \ 8, 1, #overArea.copy.icon.a[1])
	local cy2 = math.clamp( cy + (oa.page.h + 7) \ 8, 1, #overArea.copy.icon.a)
	local xx = oa.areaRect.x - (oa.cellRect.x % 8) * overArea.csize
	local yy = oa.areaRect.y - (oa.cellRect.y % 8) * overArea.csize
	
	local tex = TexturesGetLabel()
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

-- activate label editing
function _EnableLabelEditing()
	
	overArea.OnRecalc = _EnableLabelEditing
	
	-- a label-block is 8x8 pixels
	overArea.gridBlock = 8

	-- we use the copy.icon to render the areaRect
	overArea.cellRect.w,overArea.cellRect.h = #overArea.copy.icon.a[1] * 8, #overArea.copy.icon.a * 8
	
	-- Set handling-functions
	overArea.AreaSet = _LabelSet
	overArea.AreaGet = _LabelGet
	overArea.AreaGetInfo = _LabelGetInfo
	overArea.AreaDraw = _LabelDraw	
	overArea.AreaDrawFast = _LabelDrawFast
	overArea.copy.use = overArea.copy.col
	
	overArea.OnOverviewPicoGenTex = TexturesGetLabel
	overArea.OnOverviewAdr = function(x,y)
		return x * 4 + y * 64 * 8 + activePico.Label
	end
	
	m.oldCopyW, m.oldCopyH = #overArea.copy.icon.a[1], #overArea.copy.icon.a
		
	overArea:BasicLayout()
	
	for i=0,0xf do
		overArea.buttons["Color"..i].visible = true
	end
	
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

-- free up all resources
function m.Quit(m)
	overArea:Quit()
end

-- intialize 
function m.Init(m)
	overArea:Init()
	m.menuBar = overArea.menuBar
	m.buttons = overArea.buttons
	m.inputs = overArea.inputs
	m.scrollbar = overArea.scrollbar
	m.shortcut = overArea.shortcut
	

	return true
end

-- we lost focus
function m.FocusLost(m)
	-- save some values
	m.oa_size = overArea.csize
	m.oa_cell_x = overArea.cellRect.x
	m.oa_cell_y = overArea.cellRect.y
	
	-- reset selected icon
	overArea.copy.icon.a = {{0}}
	overArea.copy.icon.char = 0
	overArea.copy.icon.charEnd = 0
end

-- go focus
function m.FocusGained(m)
	overArea.cellRect.x = m.oa_cell_x or 0
	overArea.cellRect.y = m.oa_cell_y or 0
	overArea.csize = m.oa_size or 16
	-- select the complete label!
	overArea.copy.icon.a = {}
	for y=0,0xf do
		local t = {}
		for x = 0,0xf do
			table.insert(t, x + (y<<4))
		end
		table.insert(overArea.copy.icon.a, t)
	end	
	overArea.copy.icon.char = 0
	overArea.copy.icon.charEnd = 0xff
		
	_EnableLabelEditing()		
	MenuSetZoom(overArea.csize)
	
	m.oldCopyW, m.oldCopyH = #overArea.copy.icon.a[1], #overArea.copy.icon.a
			
	m:Resize()
end

-- zoom handle
function m.ZoomChange(m, zoom)
	overArea.csize = zoom
	m:Resize()
end

-- resize
function m.Resize(m)
	if overArea.OnRecalc then overArea.OnRecalc() end
end

-- draw the module
function m.Draw(mx,my)
	--update Color-Buttons
	local selColor = {}
	for nb,t in pairs( overArea.copy.col.a ) do
		for nb, id in pairs(t) do
			selColor[id] = true
		end
	end
	
	for i = 0, 0xf do
		local b,c = overArea.buttons["Color" .. i], i
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
	overArea:DrawInfoBarLabel()
end

-- mouse handling
function m.MouseDown(m, mx, my, mb, mbclicks)
	overArea:MouseDownOverview(mx, my, mb, mbclicks)
	overArea:MouseDownArea(mx, my, mb, mbclicks)
end

function m.MouseMove(m, mx, my, mb)
	overArea:MouseMoveOverview(mx, my, mb)
	overArea:MouseMoveArea(mx, my, mb)
end

function m.MouseUp(m, mx,my,mb, mbclicks)
	overArea:MouseUpOverview(mx, my, mb, mbclicks)
	overArea:MouseUpArea(mx, my, mb, mbclicks)
end

-- wheel to zoom
function m.MouseWheel(m,x,y,mx,my)
	MenuRotateZoom(y > 0) 
end


function m.SelectAll(m)
	overArea.copy.icon.char = 0
	overArea.copy.icon.charEnd = 255
	overArea:CreateListCopyIconA()
end

-- copy complete label to hex
function m.CopyHex(m)
	local adr,size = Pico.LABEL, Pico.LABELLEN
	return moduleHex:API_CopyHex(adr,size)
end

-- paste complete label 
function m.PasteHex(m,str)
	local adr,size = Pico.LABEL, Pico.LABELLEN
	return moduleHex:API_PasteHex(str,adr,size)
end

return m

