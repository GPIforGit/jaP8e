--[[

	overArea is used in moduleMap, moduleSprite, moduleCharset and moduleLabel
	
	it handles the left "OVERview" (sprites / charset / label)
	
	and the right zoomed detail "AREA", since many function between the modules are shared.
	
--]]



-- overArea-Information controls, what should be displayed and handeld
local overArea = {
	-- copy-buffer. contains the sprite and color buffer (a)	
	copy = {
		icon = {								-- sprite buffer (copy, which sprites to edit)
			char = 0,								-- first selected sprite
			charEnd = 0,							-- second selected sprite (or -1 for "random" in cache) -- needed for select-border
			a = {{0}} 								-- a[y][x] - buffer for sprites
			},
		col = {									-- color buffer
			char = 1,								-- first selected color
			charEnd = 1,							-- second selected color (or -1 for "random" in cache)
			a = {{1}}								-- a[y][x] - buffer for colors
			},
		use = nil								-- which one used in areaRect - copy.icon or copy.col
	},
	oldCopyW = 1, oldCopyH = 1,					-- needed for detection of sel-sprite-change
			
	
	areaRect = { x = 0, y = 0, w = 0, h = 0},		-- Area position (map or sprite-detail)
	areaFullW = 0,								-- maximal areaRect size
	areaFullH = 0,
	cellRect = { x = 0, y = 0, w = 0, h = 0},		-- Area start position (x,y) and max size (w,h)
	
	page = { w = 0, h = 0},						-- Area visible size
	baroffset = 0,								-- for Area-scrollbars offset to mouse-position
	gridBlock = 16,								-- grid map = 16 sprite = 8
	doCharsetGrid = false,						-- special grid for charset
	csize = 32,									-- size of a cellRect in Area - zoom
	spriteCsize = 24,							-- save zoom for sprite
	charsetCsize = 24,							-- save zoom for charset
	labelCsize = 24,							-- save zoom for label
	
	areaSelect = { x = 0, y = 0, xEnd = 0, yEnd = 0},	-- used for selection in the areaRect 
	
	overviewRect = {x = 0, y = 0, w = 0, h = 0},		-- overview position
	osize = 32,									-- size of a overview - zoom
	OnOverviewPicoGenTex = nil,						-- function to the OverviewGen
	OnOverviewAdr = nil,						-- calculate ADR
	
	animRect = {x = 0, y = 0, w = 0, h = 0},		-- Sprite Animition
	animCount = 0,								-- framecount for animation
	animPose = 0,
		
	OnRecalc = nil, 							-- called, when overArea needs recalculated (size change)
	
	AreaSet = nil, 								-- function to set a "character" in areaRect	( x, y, char)
	AreaGet = nil, 								-- function to get a "character" in areaRect	( x, y)
	AreaGetInfo=nil,							-- get character for the info-areaRect or nil
	AreaDraw = nil,								-- function to draw a Character (for areaRect)	( x, y, char)
	AreaDrawFast = nil,							-- a fast function to draw the area. For example zoomed sprite
	
	lock = "",									-- lock the mouse-handling
	
	infoCoordRect = { x = 0, y = 0, w = 0, h = 0},	-- coordinates
	infoHexRect = { x = 0, y = 0, w = 0, h = 0},	-- hex code of info
	infoIconRect = { x = 0, y = 0, w = 0, h = 0},	-- icon of info
	infoChar = nil,								-- id of info
	infoActive = nil,							-- id for the button for manipulating flags
	infoPos = nil,								-- position
	infoAdr = nil,
	infoMapSize = {x=0, y=0},					-- mapsize
	infoMapSizeByte = {x=0, y=0},				-- mapsize in bytes
	colorBack = 0								-- backcolor
}


local overAreaMeta = {}
overAreaMeta.__index = overAreaMeta
setmetatable(overArea, overAreaMeta)


--===================================================================
--------------------------------------------------------drawing-tools
--===================================================================

-- plot a dot in areaRect - don't plot twice! - with pattern-correction
local _drawPointList = {}
local function _ToolPoint(preview,xx,yy)
	-- check if already drawn
	local s = xx.."."..yy
	if _drawPointList[s] then return false end	
	_drawPointList[s] = true	
	
	-- w,h is used to select a entry in overArea.copy.use
	local w, h = #overArea.copy.use.a[1], #overArea.copy.use.a
	if preview then
		-- preview in areaRect
		local drawx = (xx - overArea.cellRect.x) * overArea.csize + overArea.areaRect.x 
		local drawy = (yy - overArea.cellRect.y) * overArea.csize + overArea.areaRect.y 
		overArea.AreaDraw( drawx, drawy, overArea.copy.use.a[(yy-overArea.areaSelect.y) % h +1][(xx-overArea.areaSelect.x) % w +1],0x80)
	else
		-- actual change
		overArea.AreaSet( xx, yy, overArea.copy.use.a[(yy-overArea.areaSelect.y) % h + 1][(xx-overArea.areaSelect.x) % w + 1])
	end
	return true
end

-- fill - tool
local function _ToolFill(preview,xx,yy)	
	_drawPointList = {}
	
	-- which color should be overwritten
	local col = overArea.AreaGet(xx,yy)
	
	function f(preview,col,xx,yy)
		-- fail, if outside the visible area
		if xx < overArea.cellRect.x or xx >= overArea.page.w + overArea.cellRect.x or yy < overArea.cellRect.y or yy >= overArea.page.h + overArea.cellRect.y then
			return false
		end
		-- if the color is correct, overwrite it
		if overArea.AreaGet(xx,yy) == col and _ToolPoint(preview,xx,yy)	then
			-- draw the neighbors
			f(preview, col, xx - 1, yy)
			f(preview, col, xx + 1, yy)
			f(preview, col, xx , yy - 1)
			f(preview, col, xx , yy + 1)
		end
	end
	-- star filling 
	f(preview,col,xx,yy)	
end

-- line - tool
local function _ToolLine(preview,coord,offset)
	offset = offset or 0 
	_drawPointList = {}
	
	-- find longer size
	local a = math.max(
		math.abs(coord.xEnd - coord.x) ,
		math.abs(coord.yEnd - coord.y)
	)
	
	-- div vertical/horizontal over size
	local dx,dy
	dx = a == 0 and 0 or (coord.xEnd - coord.x) / a		
	dy = a == 0 and 0 or (coord.yEnd - coord.y) / a

	-- draw line
	for i = offset,a-offset do
		_ToolPoint(
			preview,
			math.floor(dx * i + 0.5) + coord.x, -- round coordinates
			math.floor(dy * i + 0.5) + coord.y
		)
	end
end

-- box - tool
local function _ToolBox(preview,filled)
	-- box with height/width == 1 is a line
	if overArea.areaSelect.x == overArea.areaSelect.xEnd or overArea.areaSelect.y == overArea.areaSelect.yEnd then
		return _ToolLine(preview,overArea.areaSelect)
	end	
	
	if filled then
		-- fill 
		for y = overArea.areaSelect.y, overArea.areaSelect.yEnd, overArea.areaSelect.y < overArea.areaSelect.yEnd and 1 or -1 do
			_ToolLine(
				preview,
				{ x = overArea.areaSelect.x, y = y, xEnd = overArea.areaSelect.xEnd , yEnd = y }
			)
		end
	else
		-- top
		_ToolLine(
			preview,
			{ x = overArea.areaSelect.x   , y = overArea.areaSelect.y   , xEnd = overArea.areaSelect.xEnd, yEnd = overArea.areaSelect.y    }
		)
		-- bottom
		_ToolLine(
			preview,
			{ x = overArea.areaSelect.x   , y = overArea.areaSelect.yEnd, xEnd = overArea.areaSelect.xEnd, yEnd = overArea.areaSelect.yEnd }
		)
		-- left (with offset, because top/bottom already drawn start/end point)
		_ToolLine(
			preview,
			{ x = overArea.areaSelect.x   , y = overArea.areaSelect.y   , xEnd = overArea.areaSelect.x   , yEnd = overArea.areaSelect.yEnd },
			1
		)
		-- right (with offset, because top/bottom already drawn start/end point)
		_ToolLine(
			preview,
			{ x = overArea.areaSelect.xEnd, y = overArea.areaSelect.y   , xEnd = overArea.areaSelect.xEnd, yEnd = overArea.areaSelect.yEnd }
			,
			1
		)
	end
end

-- Ellipse - tool
local function _ToolEllipse(preview, filled)
	-- with w/h = 1 it is a line, not a ellipse
	if overArea.areaSelect.x == overArea.areaSelect.xEnd or overArea.areaSelect.y == overArea.areaSelect.yEnd then
		return _ToolLine(preview,overArea.areaSelect)
	end
	
	_drawPointList = {}
	
	-- don't ask, it work...
	
	local x1 = overArea.areaSelect.x
	local x2 = overArea.areaSelect.xEnd
	local y1 = overArea.areaSelect.y
	local y2 = overArea.areaSelect.yEnd
	if x1>x2 then x1,x2 = x2,x1 end
	if y1>y2 then y1,y2 = y2,y1 end
		
	local mx = x2 + x1
	local my = y2 + y1
	local px, py
    local rx = (x2 - x1)
	local ry = (y2 - y1)
    local xc = (x1 + x2) / 2
	local yc = (y1 + y2) /2
    local dx, dy, d1, d2, x, y
 
	x = 0
	y = ry
  
	-- Initial decision parameter of region 1
	d1 = (ry * ry) - (rx * rx * ry) + (0.25 * rx * rx)
	dx = 2 * ry * ry * x
	dy = 2 * rx * rx * y
  
	-- For region 1
	while dx < dy do 
		-- Print points based on 4-way symmetry
		px = math.ceil( x / 2.0 + xc - 0.5)
		py = math.ceil( y / 2.0 + yc - 0.5)
		
		
		if filled then
			for xx = px, mx - px,px < mx - px and 1 or -1 do
				_ToolPoint(preview, xx, py)
				_ToolPoint(preview, xx, my - py)
			end
		else
			_ToolPoint(preview, px, py)
			_ToolPoint(preview, mx - px, py)
			_ToolPoint(preview, px, my - py)
			_ToolPoint(preview, mx - px, my - py)
		end
		-- Checking And updating value of
		-- decision parameter based on algorithm
		if d1 < 0 then
			x += 1
			dx = dx + (2 * ry * ry)
			d1 = d1 + dx + (ry * ry)
		else 
			x += 1
			y -= 1
			dx = dx + (2 * ry * ry)
			dy = dy - (2 * rx * rx)
			d1 = d1 + dx - dy + (ry * ry)
		end
	end
  
	-- Decision parameter of region 2
	d2 = ((ry * ry) * ((x + 0.5) * (x + 0.5))) + ((rx * rx) * ((y - 1) * (y - 1))) - (rx * rx * ry * ry)
  
	
	--Plotting points of region 2
	while y >= 0 do

		-- printing points based on 4-way symmetry
		px = math.ceil(x / 2.0 + xc - 0.5)
		py = math.ceil(y / 2.0 + yc - 0.5)

		if filled then
			for xx = px, mx - px,px < mx - px and 1 or -1 do
				_ToolPoint(preview, xx, py)
				_ToolPoint(preview, xx, my - py)
			end
		else
			_ToolPoint(preview, px, py)
			_ToolPoint(preview, mx - px, py)
			_ToolPoint(preview, px, my - py)
			_ToolPoint(preview, mx - px, my - py)
		end

		-- Checking And updating parameter
		-- value based on algorithm
		if d2 > 0 then
			y -= 1
			dy = dy - (2 * rx * rx)
			d2 = d2 + (rx * rx) - dy
		else 
			y -= 1
			x += 1
			dx = dx + (2 * ry * ry)
			dy = dy - (2 * rx * rx)
			d2 = d2 + dx - dy + (rx * rx)
		end
	end
	
end


--===================================================================
---------------------------------------------------------manipulating
--===================================================================

-- flip on x coordinates
local function _ButFlipX(but)
	local w,h = overArea.cellRect.w, overArea.cellRect.h
		
	for x = 0, w \ 2 - 1 do
		for y = 0, h - 1 do
			local s1,s2 = overArea.AreaGet(x,y), overArea.AreaGet(w - x - 1, y)
			overArea.AreaSet(x,y,s2)
			overArea.AreaSet(w - x - 1,y,s1)
		end
	end	
end

-- flip on y coordinates
local function _ButFlipY(but)
	local w,h = overArea.cellRect.w, overArea.cellRect.h
		
	for y = 0, h \ 2 - 1 do
		for x = 0, w - 1 do
			local s1,s2 = overArea.AreaGet(x,y), overArea.AreaGet(x,h - y - 1)
			overArea.AreaSet(x,y,s2)
			overArea.AreaSet(x,h - y - 1,s1)
		end
	end	
end

-- rotate to right
local function _ButTurnRight(but)
	local l = math.max(overArea.cellRect.w, overArea.cellRect.h)
	
	for z = 0, l \ 2 - 1 do
		for d = 0, l - z*2 - 2 do
			local s1 = overArea.AreaGet(z+d,z)
			local s2 = overArea.AreaGet(l-z-1,z+d)
			local s3 = overArea.AreaGet(l-z-1-d,l-z-1)
			local s4 = overArea.AreaGet(z,l-z-1-d)

			overArea.AreaSet(z+d,z,s4)
			overArea.AreaSet(l-z-1,z+d,s1)
			overArea.AreaSet(l-z-1-d,l-z-1,s2)
			overArea.AreaSet(z,l-z-1-d,s3)
		end
	end
end

-- rotate to left
local function _ButTurnLeft(but)
	local l = math.max(overArea.cellRect.w, overArea.cellRect.h)
	
	for z = 0, l \ 2 - 1 do
		for d = 0, l - z*2 - 2 do
			local s1 = overArea.AreaGet(z+d,z)
			local s2 = overArea.AreaGet(l-z-1,z+d)
			local s3 = overArea.AreaGet(l-z-1-d,l-z-1)
			local s4 = overArea.AreaGet(z,l-z-1-d)

			overArea.AreaSet(z+d,z,s2)
			overArea.AreaSet(l-z-1,z+d,s3)
			overArea.AreaSet(l-z-1-d,l-z-1,s4)
			overArea.AreaSet(z,l-z-1-d,s1)
		end
	end
end

-- Shift area
local function _AreaShift(dx,dy)
	local w,h = overArea.cellRect.w, overArea.cellRect.h
	local xs,xe
	local ys,ye
	
	if dx == -1 then
		xs = 0
		xe = w-2
	elseif dx == 1 then
		xs = w-2
		xe = 0
	else
		xs = 0
		xe = w-1
	end
	
	if dy == -1 then
		ys = 0
		ye = h-2
	elseif dy == 1 then
		ys = h-2
		ye = 0
	else
		ys = 0
		ye = h-1
	end

	for yy = ys, ye, (ys<ye and 1 or -1)  do
		for xx = xs, xe, (xs<xe and 1 or -1)  do
			local x2 = (xx + dx) % w
			local y2 = (yy + dy) % h
			local s1,s2 = overArea.AreaGet(xx,yy), overArea.AreaGet(x2,y2)
			overArea.AreaSet(xx,yy,s2)
			overArea.AreaSet(x2,y2,s1)
		end
	end
end

local function _ButShiftLeft(but)
	_AreaShift(-1,0)
end
local function _ButShiftRight(but)
	_AreaShift(1,0)
end
local function _ButShiftUp(but)
	_AreaShift(0,-1)
end
local function _ButShiftDown(but)
	_AreaShift(0,1)
end


--===================================================================
-----------------------------------------------Draw parts of OverArea
--===================================================================

-- draw areaRect-map
function overAreaMeta.DrawArea(oa, mx, my)	

	renderer:SetClipRect( oa.areaRect )
		
	-- draw background
	DrawFilledRect(oa.areaRect,Pico.RGB[ oa.colorBack ],255)
	
	-- draw areaRect-content	
	local maxx, maxy = oa.areaRect.x + oa.areaRect.w, oa.areaRect.y + oa.areaRect.h
	local showHex =  oa.buttons.AreaID:IsSelected() and oa.csize > (SizeText("++"))
	
	if oa.AreaDrawFast then
		-- draw area fast
		local alpha = (showHex or oa.buttons.AreaFlags:IsSelected()) and 0x80 or 0xFF 
		oa:AreaDrawFast(alpha)
	
		-- draw hex numbers
		if showHex then
			local yy,xx = oa.areaRect.y
			local s = oa.csize \ 8
			for y = oa.cellRect.y, oa.cellRect.y + oa.page.h - 1 do
				xx = oa.areaRect.x
						
				for x = oa.cellRect.x, oa.cellRect.x + oa.page.w - 1 do
					-- icon
					local char = oa.AreaGet(x,y)
								
					-- id 
					if char != 0 or oa.buttons.AreaCopy00:IsSelected() then 
						DrawHex(xx + 1, yy + 1, char)
					end
			
					xx += oa.csize
				end		
				yy += oa.csize
			end
		end
	
	else
		-- manual drawing the area
		local yy,xx = oa.areaRect.y
		local s = oa.csize \ 8
		for y = oa.cellRect.y, oa.cellRect.y + oa.page.h - 1 do
			xx = oa.areaRect.x
								
			for x = oa.cellRect.x, oa.cellRect.x + oa.page.w - 1 do
				-- icon
				local char = oa.AreaGet(x,y)
				
				-- default alpha-value
				local alpha = (showHex or oa.buttons.AreaFlags:IsSelected()) and 0x80 or 0xFF 

				-- flashing of selected icons
				local doFlash = false
				if oa.buttons.AreaHiSel:IsSelected() then
					for nb,t in pairs(oa.copy.use.a) do
						for nb,id in pairs(t) do
							if id == char then
								doFlash = true
							end
						end
					end
					if not doFlash then
						alpha = 0x40
					end			
				end
				
				-- draw icon
				oa.AreaDraw(xx,	yy, char, alpha)
							
				if doFlash then
					DrawFilledRect( {xx, yy, oa.csize, oa.csize}, COLWHITE, math.floor(0x60 + math.sin(SDL.Time.Get() * 2) * 0x30) & 0xff)
				end
							
				-- id / Flags
				if char != 0 or oa.buttons.AreaCopy00:IsSelected() then 
					if showHex then
						DrawHex(xx + 1, yy + 1, char)
					end
					
					if oa.buttons.AreaFlags:IsSelected() then
					
						if oa.buttons.AreaFlags:IsSelected() then			
							DrawFilledRect({xx + 0, yy + s*7 - 1, oa.csize, s + 2}, COLBLACK)
						end
					
						local info = oa.AreaGetInfo(x,y)
						for i=0,7 do
							if activePico:SpriteFlagGet(info, i) then
								DrawFilledRect({xx + s*i, yy + s*7, s, s}, Pico.RGB[i+8])
							end
						end				
					end
					
				end
		
				xx += oa.csize
			end		
			yy += oa.csize
		end
	end
		
	-- draw grid	
	if oa.buttons.AreaGrid:IsSelected() then
		for x = oa.areaRect.x, maxx, oa.csize do
			DrawFilledRect({x, oa.areaRect.y, 1, oa.areaRect.h}, COLDARKGREY)
		end
		for y = oa.areaRect.y, maxy, oa.csize do
			DrawFilledRect({oa.areaRect.x, y, oa.areaRect.w, 1}, COLDARKGREY)
		end
	end
		
	-- grid for charsets	
	if oa.doCharsetGrid then
		local yy,xx = oa.areaRect.y - (oa.cellRect.y % oa.gridBlock) * oa.csize
		
		local adjEnable = (activePico:Peek(Pico.CHARSET + 5) & 1) == 1
		local lw, hw = activePico:Peek(Pico.CHARSET+0), activePico:Peek(Pico.CHARSET+1)
		
		for y = oa.cellRect.y, oa.cellRect.y + oa.page.h - 1,oa.gridBlock do
			xx = oa.areaRect.x - (oa.cellRect.x % oa.gridBlock) * oa.csize
			
			DrawFilledRect( {xx, yy + activePico:Peek(Pico.CHARSET+2) * oa.csize, oa.areaRect.w, 1}, COLGREY)
			
			for x = oa.cellRect.x, oa.cellRect.x + oa.page.w - 1, oa.gridBlock do
				local info,w = oa.AreaGetInfo(x,y)
				
				local offw = 0
				if adjEnable then
					offw,_ = activePico:CharsetGetVariable(info)
				end
				
				if info < 0x80 then
					w = lw + offw
				else 
					w = hw + offw
				end
				
				DrawFilledRect({xx + math.min(8,w) * oa.csize, yy, 1, oa.gridBlock * oa.csize}, COLGREY)
				xx += oa.gridBlock * oa.csize
			end			
			yy += oa.gridBlock * oa.csize
		end
	end

	-- grid block (for example screensize)
	for x = oa.areaRect.x - (oa.cellRect.x % oa.gridBlock) * oa.csize, maxx, oa.csize * oa.gridBlock do
		DrawFilledRect({x, oa.areaRect.y, 1, oa.areaRect.h}, oa.doCharsetGrid and COLLIGHTGREY or COLGREY)
	end
	for y = oa.areaRect.y - (oa.cellRect.y % oa.gridBlock) * oa.csize, maxy, oa.csize * oa.gridBlock do
		DrawFilledRect({oa.areaRect.x, y, oa.areaRect.w, 1}, oa.doCharsetGrid and COLLIGHTGREY or COLGREY)
	end
	
	-- Stamp preview
	if oa.lock == "" and oa.buttons.AreaStamp:IsSelected() and SDL.Rect.ContainsPoint(oa.areaRect, {mx,my}) then
		-- lock mouse to cellRect
		xx = ((mx - oa.areaRect.x) \ oa.csize) * oa.csize + oa.areaRect.x 
		yy = ((my - oa.areaRect.y) \ oa.csize) * oa.csize + oa.areaRect.y 	
	
		-- border around preview
		DrawBorder(
			xx, 
			yy, 
			#oa.copy.use.a[1] * oa.csize, 
			#oa.copy.use.a * oa.csize, 
			COLWHITE
		)
	
		-- draw preview-content
		local py,px = yy
		for y=1, #oa.copy.use.a do 
			px = xx
			for x=1,#oa.copy.use.a[1] do
				oa.AreaDraw( px, py, oa.copy.use.a[y][x], 0x80)	-- transparent
				px += oa.csize
			end
			py += oa.csize
		end
		
	end
	
	-- Line preview
	if oa.lock == "AREALINE" then
		_ToolLine(true,oa.areaSelect)
	
	
	-- Box preview
	elseif oa.lock == "AREABOX" then
		_ToolBox(true)		
	
	elseif oa.lock == "AREAFILLEDBOX" then
		_ToolBox(true, true)		
		
	-- Ellipse preview
	elseif oa.lock == "AREAELLIPSE" then
		_ToolEllipse(true)
		
	elseif oa.lock == "AREAFILLEDELLIPSE" then
		_ToolEllipse(true, true)
	end
	
	renderer:SetClipRect()
		
	-- selection border
	if oa.lock == "AREASELECT" or oa.lock == "AREABOX" or oa.lock == "AREALINE" or oa.lock == "AREAELLIPSE" or oa.lock == "AREAFILLEDBOX" or oa.lock == "AREAFILLEDELLIPSE" then
		DrawGridBorder( oa.areaRect.x, oa.areaRect.y,
			(oa.areaSelect.x - oa.cellRect.x),
			(oa.areaSelect.y - oa.cellRect.y),
			(oa.areaSelect.xEnd - oa.cellRect.x),
			(oa.areaSelect.yEnd - oa.cellRect.y),
			oa.csize,
			COLRED,
			true			
		)		
		
	end
	
	-- get char-info under mouse cursor
	if SDL.Rect.ContainsPoint(oa.areaRect, {mx,my}) then
		oa.infoPos = {
			x = (mx - oa.areaRect.x) \ oa.csize + oa.cellRect.x,
			y = (my - oa.areaRect.y) \ oa.csize + oa.cellRect.y
		}
			
		oa.infoChar, oa.infoAdr = oa.AreaGetInfo(
			oa.infoPos.x,
			oa.infoPos.y
		)
	end
		
end

-- Draw overview
function overAreaMeta.DrawOverview(oa, mx, my)
	local tex = oa.OnOverviewPicoGenTex()
	
	-- draw all sprites/charset
	DrawFilledRect(oa.overviewRect, COLBLACK,255)
	tex:SetBlendMode("BLEND")
	tex:SetAlphaMod( (oa.buttons.OverviewId:IsSelected() or oa.buttons.OverviewFlags:IsSelected() or oa.buttons.OverviewCount:IsSelected())
					 and 0x80 or 0xFF )
	
	renderer:Copy(tex, nil, oa.overviewRect)
	
	-- draw id / flags / count	
	if oa.buttons.OverviewId:IsSelected() or oa.buttons.OverviewFlags:IsSelected() or oa.buttons.OverviewCount:IsSelected() then
		local yy = oa.overviewRect.y
		local s = oa.osize \ 8
		local charw,charh = SizeText("+")
		
		for y = 0, 0xf do
			local xx = oa.overviewRect.x
			
			if oa.buttons.OverviewFlags:IsSelected() then
				DrawFilledRect({xx, yy + s*7 - 1, oa.overviewRect.w, s + 2 }, COLBLACK)
			end
			
			for x = 0, 0xf do
				local icon = x + (y << 4)
			
				if oa.buttons.OverviewId:IsSelected() then
					DrawHex(xx + 1, yy + 1, icon,Pico.RGB[7])
				end
								
				if oa.buttons.OverviewFlags:IsSelected() then		
					for i=0,7 do
						if activePico:SpriteFlagGet(icon, i) then
							DrawFilledRect({xx + s*i, yy + s*7, s, s}, Pico.RGB[i+8])
						end
					end
				end
				
				if oa.buttons.OverviewCount:IsSelected() then
					local c = math.min(99,activePico:MapCount(icon))
			
					if c > 0 then 
						DrawText(xx + 1, yy + 1 + charh,"x"..c,Pico.RGB[10])
					end
				end
				
				xx += oa.osize
			end
			
			yy += oa.osize
		end
	end
	
	-- draw grid	
	if oa.buttons.OverviewGrid:IsSelected() then
		renderer:SetClipRect(oa.overviewRect)	
		for x = oa.overviewRect.x-1, oa.overviewRect.x + oa.overviewRect.w, oa.osize do
			DrawFilledRect({x, oa.overviewRect.y, 1, oa.overviewRect.h}, COLGREY)
		end
		for y = oa.overviewRect.y-1, oa.overviewRect.y + oa.overviewRect.h, oa.osize do
			DrawFilledRect({oa.overviewRect.x, y, oa.overviewRect.w, 1}, COLGREY)
		end
		renderer:SetClipRect(nil)
	
		if oa.doCharsetGrid then
			local adjEnable = (activePico:Peek(Pico.CHARSET + 5) & 1) == 1
			local lw, hw = activePico:Peek(Pico.CHARSET+0), activePico:Peek(Pico.CHARSET+1)
			
			local yy = oa.overviewRect.y
			for y = 0, 15 do
				local xx = oa.overviewRect.x
				for x = 0, 15 do
					local char = x + (y << 4)
					local offw = 0
					if adjEnable then
						offw,_ = activePico:CharsetGetVariable(char)
					end
					local w = math.clamp(0,8, (char < 0x80 and lw or hw) + offw)
					
					
					DrawFilledRect({xx + w * oa.osize \ 8, yy,  (8-w) * oa.osize \ 8, oa.osize}, COLGREY)
					
					
					
					xx += oa.osize
				end
				yy += oa.osize
			end
					
		end
	end
	
	-- draw selection	
	if oa.copy.icon.charEnd >= 0 then 
		-- block selection
		DrawGridBorder( oa.overviewRect.x, oa.overviewRect.y,
			(oa.copy.icon.char & 0xf),
			((oa.copy.icon.char >> 4) & 0xf),
			(oa.copy.icon.charEnd & 0xf),
			((oa.copy.icon.charEnd >> 4) & 0xf),
			oa.osize,
			COLWHITE
		)
		
	else
		-- "random" selection
		for y = 1,#oa.copy.icon.a do
			for x = 1,#oa.copy.icon.a[1] do
				DrawBorder(
					(oa.copy.icon.a[y][x] & 0xf) * oa.osize + oa.overviewRect.x,
					((oa.copy.icon.a[y][x] >>4) & 0xf) * oa.osize + oa.overviewRect.y,
					oa.osize,
					oa.osize,
					COLWHITE
				)
			end
		end
		
	end
	
	if SDL.Rect.ContainsPoint(oa.overviewRect, {mx, my})  then		
		-- Get the character under mouse-cursor for info
		local x = (mx - oa.overviewRect.x) \ oa.osize
		local y = (my - oa.overviewRect.y) \ oa.osize
		oa.infoChar = x + (y << 4)
		oa.infoAdr = oa.OnOverviewAdr(x,y)
	elseif oa.copy.icon.char == oa.copy.icon.charEnd then
		-- set info to singel-character-selection
		oa.infoChar = oa.copy.icon.char
	end
end

-- draw info field (sprite/map)
function overAreaMeta.DrawInfoBar(oa)
	--- icon, flags, count
	if oa.infoChar != nil then
		DrawHex( oa.infoHexRect.x, oa.infoHexRect.y, oa.infoChar  )
		local tex = TexturesGetSprite()
		tex:SetAlphaMod(255)
		tex:SetBlendMode("NONE")
		renderer:Copy( 
			tex,
			{x = (oa.infoChar  & 0xf) * 8, y = ((oa.infoChar  >> 4) & 0xf) * 8, w = 8, h = 8},
			oa.infoIconRect
		)
		for i=0,7 do 
			oa.buttons["Flag"..i].selected = activePico:SpriteFlagGet( oa.infoChar, i)
			oa.buttons["Flag"..i].visible = true
		end
		
		local count = activePico:MapCount( oa.infoChar )
		if count > 0 then 
			DrawText( oa.infoIconRect.x + oa.infoIconRect.w + 5, oa.infoHexRect.y, string.format("x%d",count) )
		end
		
		
	else	
		for i=0,7 do 
			oa.buttons["Flag"..i].visible = false
		end
	end
	
	local str
	
	if oa.infoAdr then
		str = string.format("%04x ", oa.infoAdr)
	else
		str = "    "
	end
	if oa.infoPos then
		str ..= string.format("%03dx%03d", oa.infoPos.x, oa.infoPos.y)
	end
	
	DrawText(oa.infoCoordRect.x, oa.infoCoordRect.y, str)
	
	-- set the active-character for flag overArea	
	oa.infoActive = oa.infoChar
	
	-- reset - set by the draw-routines
	oa.infoChar = nil
	oa.infoPos = nil
	oa.infoAdr = nil
	oa.infoCount = nil
	
end

-- draw info field (charset)
function overAreaMeta.DrawInfoBarCharset(oa)
	if oa.infoChar != nil then
		DrawHex( oa.infoHexRect.x, oa.infoHexRect.y, oa.infoChar  )
		local tex = TexturesGetCharset()
		tex:SetAlphaMod(255)
		tex:SetBlendMode("NONE")
		renderer:Copy( 
			tex,
			{x = (oa.infoChar  & 0xf) * 8, y = ((oa.infoChar  >> 4) & 0xf) * 8, w = 8, h = 8},
			oa.infoIconRect
		)
		
		DrawText(oa.infoIconRect.x + oa.infoIconRect.w + 5, oa.infoHexRect.y, activePico.CHARNAME[oa.infoChar])
	end
		
	local str
	
	if oa.infoAdr then
		str = string.format("%04x ", oa.infoAdr)
	else
		str = "    "
	end
	if oa.infoPos then
		str ..= string.format("%03dx%03d", oa.infoPos.x, oa.infoPos.y)
	end
	
	DrawText(oa.infoCoordRect.x, oa.infoCoordRect.y, str)

	-- reset - set by the draw-routines
	oa.infoChar = nil
	oa.infoPos = nil
	oa.infoAdr = nil
	
end

-- draw info field (label)
function overAreaMeta.DrawInfoBarLabel(oa)
	local str
	
	if oa.infoAdr then
		str = string.format("%04x ", oa.infoAdr)
	else
		str = "    "
	end
	if oa.infoPos then
		str ..= string.format("%03dx%03d", oa.infoPos.x, oa.infoPos.y)
	end
	
	DrawText(oa.infoCoordRect.x, oa.infoCoordRect.y, str)

	-- reset - set by the draw-routines
	oa.infoChar = nil
	oa.infoPos = nil
	oa.infoAdr = nil
	
end


--===================================================================
-------------------------------------------------------Mouse-handling
--===================================================================

-- click on overview
function overAreaMeta.MouseDownOverview(oa, mx, my, mb)
	if mb == "LEFT" and oa.lock == "" and SDL.Rect.ContainsPoint(oa.overviewRect, {mx, my}) then
		local x = (mx - oa.overviewRect.x) \ oa.osize
		local y = (my - oa.overviewRect.y) \ oa.osize
		
		if SDL.Keyboard.GetModState():hasflag("SHIFT") == 0 then
			oa.copy.icon.char = x + (y << 4)
			oa.copy.icon.charEnd = oa.copy.icon.char
			oa.lock = "OVERVIEW"
		else
			oa.copy.icon.charEnd = x + (y << 4)
			oa:CreateListCopyIconA()
		end
	end
end

-- move on overview
function overAreaMeta.MouseMoveOverview(oa, mx, my, mb)	
	if oa.lock == "OVERVIEW" and SDL.Rect.ContainsPoint(oa.overviewRect, {mx, my})  then		
		local x = (mx - oa.overviewRect.x) \ oa.osize
		local y = (my - oa.overviewRect.y) \ oa.osize
		oa.copy.icon.charEnd = x + (y << 4)
		--oa:CreateListCopyIconA()
	end
end

-- end click on overview
function overAreaMeta.MouseUpOverview(oa, mx, my, mb)
	if oa.lock == "OVERVIEW" and mb == "LEFT" then
		oa.lock = ""
		oa:CreateListCopyIconA()		
	end
end

-- click on areaRect
function overAreaMeta.MouseDownArea(oa, mx, my, mb)
	if oa.lock == "" and SDL.Rect.ContainsPoint(oa.areaRect, {mx, my}) then
	
		if mb == "MIDDLE" then
			-- free scroll
			oa.scroll = { mx = mx, my = my, cx = oa.cellRect.x, cy = oa.cellRect.y }
			oa.lock = "AREASCROLL"
			SDL.Cursor.Set(cursorHand)
			return
		end
	
		-- lock on cellRect
		local x = (mx - oa.areaRect.x) \ oa.csize + oa.cellRect.x
		local y = (my - oa.areaRect.y) \ oa.csize + oa.cellRect.y
		
		if mb == "LEFT" then			
			-- draw
			if oa.buttons.AreaStamp:IsSelected() then
				x -= 1
				y -= 1
				for yy = 1, #oa.copy.use.a do
					for xx = 1, #oa.copy.use.a[1] do
						oa.AreaSet( x + xx, y + yy, oa.copy.use.a[yy][xx] )
					end
				end
				oa.lock = "AREASTAMP"
				
			elseif oa.buttons.AreaLine:IsSelected() then
				oa.areaSelect = {x = x, y = y, xEnd = x, yEnd = y}
				oa.lock = "AREALINE"
				
			elseif oa.buttons.AreaLines:IsSelected() then
				oa.areaSelect = {x = x, y = y, xEnd = x, yEnd = y}
				oa.lock = "AREALINES"
				
			elseif oa.buttons.AreaBox:IsSelected() then 
				oa.areaSelect = {x = x, y = y, xEnd = x, yEnd = y}
				oa.lock = "AREABOX"
				
			elseif oa.buttons.AreaFilledBox:IsSelected() then 
				oa.areaSelect = {x = x, y = y, xEnd = x, yEnd = y}
				oa.lock = "AREAFILLEDBOX"
				
			elseif oa.buttons.AreaEllipse:IsSelected() then 
				oa.areaSelect = {x = x, y = y, xEnd = x, yEnd = y}
				oa.lock = "AREAELLIPSE"
				
			elseif oa.buttons.AreaFilledEllipse:IsSelected() then 
				oa.areaSelect = {x = x, y = y, xEnd = x, yEnd = y}
				oa.lock = "AREAFILLEDELLIPSE"
				
			elseif oa.buttons.AreaFill:IsSelected() then
				_ToolFill(false, x, y)
				oa.lock = "AREAFILL"
			end
				
		elseif mb == "RIGHT" then
			-- select/copy
			oa.areaSelect = {x = x, y = y, xEnd = x, yEnd = y}
			-- copy one char in buffer
			oa.copy.use.char = oa.AreaGet( x, y )
			oa.copy.use.charEnd = oa.copy.use.char
			oa.copy.use.a = {{oa.copy.use.char}}
			oa.lock = "AREASELECT"
		end		
	end
end

-- move in areaRect
function overAreaMeta.MouseMoveArea(oa, mx, my, mb)
	
	if oa.lock == "AREASCROLL" then
		oa.cellRect.x = (oa.scroll.mx-mx) \ (oa.csize \ 2) + oa.scroll.cx
		oa.cellRect.y = (oa.scroll.my-my) \ (oa.csize \ 2) + oa.scroll.cy
		oa:LimitCellToScreen()	

	elseif oa.lock == "AREASTAMP" and SDL.Rect.ContainsPoint(oa.areaRect, {mx, my}) then
		-- lock to cellRect
		local xx = (mx - oa.areaRect.x) \ oa.csize + oa.cellRect.x -1
		local yy = (my - oa.areaRect.y) \ oa.csize + oa.cellRect.y -1
			
		for y = 1, #oa.copy.use.a do
			for x = 1, #oa.copy.use.a[1] do
				oa.AreaSet( xx + x, yy + y, oa.copy.use.a[y][x] )
			end
		end
		
	elseif oa.lock == "AREALINES" or oa.lock == "AREALINE" or oa.lock == "AREABOX" or oa.lock == "AREAELLIPSE" or oa.lock == "AREAFILLEDBOX" or oa.lock == "AREAFILLEDELLIPSE" then
		if SDL.Rect.ContainsPoint(oa.areaRect, {mx, my}) then
			oa.areaSelect.xEnd = (mx - oa.areaRect.x) \ oa.csize + oa.cellRect.x
			oa.areaSelect.yEnd = (my - oa.areaRect.y) \ oa.csize + oa.cellRect.y
		else
			oa.areaSelect.xEnd = oa.areaSelect.x
			oa.areaSelect.yEnd = oa.areaSelect.y
		end
		if oa.lock == "AREALINES" and (oa.areaSelect.x != oa.areaSelect.xEnd or oa.areaSelect.y != oa.areaSelect.yEnd) then
			_ToolLine(false,oa.areaSelect)
			oa.areaSelect.x = oa.areaSelect.xEnd
			oa.areaSelect.y = oa.areaSelect.yEnd			
		end		
		
	elseif oa.lock == "AREASELECT" and SDL.Rect.ContainsPoint(oa.areaRect, {mx, my}) then
		local cx = (mx - oa.areaRect.x) \ oa.csize + oa.cellRect.x
		local cy = (my - oa.areaRect.y) \ oa.csize + oa.cellRect.y
			
		-- only update on change
		if oa.areaSelect.xEnd != cx or oa.areaSelect.yEnd != cy then 
			oa.areaSelect.xEnd = cx
			oa.areaSelect.yEnd = cy

			-- max/min x,y
			local x,xx = oa.areaSelect.x, oa.areaSelect.xEnd
			local y,yy = oa.areaSelect.y, oa.areaSelect.yEnd
			if x>xx then x,xx = xx,x end
			if y>yy then y,yy = yy,y end

			-- copy
			oa.copy.use.a={}
			for iy=y,yy do
				local t={}
				for ix=x,xx do
					table.insert(t, oa.AreaGet(ix,iy))
				end
				table.insert(oa.copy.use.a,t)
			end		
			
			-- set one character or random
			if x == xx and y == yy then
				oa.copy.use.charEnd = oa.copy.use.char
			else
				oa.copy.use.charEnd = -1
			end
		end		
	end
	
end

-- end click on areaRect
function overAreaMeta.MouseUpArea(oa, mx, my, mb)
	if oa.lock == "AREASTAMP" and mb == "LEFT" then
		oa.lock = ""
	
	elseif oa.lock == "AREALINE" and mb == "LEFT" then
		_ToolLine(false,oa.areaSelect)
		oa.lock = ""
		
	elseif oa.lock == "AREALINES" and mb == "LEFT" then
		oa.lock = ""
	
	elseif oa.lock == "AREABOX" and mb == "LEFT" then
		_ToolBox(false)
		oa.lock = ""
	
	elseif oa.lock == "AREAFILLEDBOX" and mb == "LEFT" then
		_ToolBox(false,true)
		oa.lock = ""
	
	elseif oa.lock == "AREAELLIPSE" and mb == "LEFT" then
		_ToolEllipse(false)
		oa.lock = ""
	
	elseif oa.lock == "AREAFILLEDELLIPSE" and mb == "LEFT" then
		_ToolEllipse(false,true)
		oa.lock = ""
	
	elseif oa.lock == "AREAFILL" and mb == "LEFT" then
		oa.lock = ""
	
	elseif oa.lock == "AREASELECT" and mb == "RIGHT" then
		oa.lock = ""
	
	elseif oa.lock == "AREASCROLL" and mb == "MIDDLE" then
		oa.lock = ""
		SDL.Cursor.Set(cursorArrow)
	end
end


--===================================================================
-----------------------------------------------------------------MISC
--===================================================================

-- create the overArea.copy.icon.a
function overAreaMeta.CreateListCopyIconA(oa)
	-- copy selection in the copy-buffer
	local x, y = oa.copy.icon.char & 0xf, (oa.copy.icon.char >> 4) & 0xf	
	local xx, yy = oa.copy.icon.charEnd & 0xf, (oa.copy.icon.charEnd >> 4) & 0xf	

	-- x,y always left/top
	if x > xx then x,xx = xx,x end 
	if y > yy then y,yy = yy,y end
	
	oa.copy.icon.a = {}
	for iy = y,yy do
		local t = {}
		for ix = x,xx do
			table.insert(t, ix + (iy << 4))
		end
		table.insert(oa.copy.icon.a, t)
	end		
end

-- correct cellRect-position to visible screen areaRect
function overAreaMeta.LimitCellToScreen(oa)
	oa.cellRect.x = math.clamp(oa.cellRect.x, 0, oa.cellRect.w - oa.page.w)
	oa.cellRect.y = math.clamp(oa.cellRect.y, 0, oa.cellRect.h - oa.page.h)
	if oa.scrollbar.AreaW then 
		oa.scrollbar.AreaW:SetValues(oa.cellRect.x)
	end
	if oa.scrollbar.AreaH then 
		oa.scrollbar.AreaH:SetValues(oa.cellRect.y)
	end
end

-- overArea - basic layout
function overAreaMeta.BasicLayout(oa)
	local ow, oh = renderer:GetOutputSize()
		
	-- calculate some layout positions
	local s
	_,s	= oa.buttons:GetSize("+")
	
	
	local ButtonAreaHeight = 5 + (s + 1) * 4
	local midX = oa.overviewRect.x + oa.overviewRect.w + 5
	local downY = oh - ButtonAreaHeight
	
	
	
	oa.doCharsetGrid = false		-- special grid for charset
	oa.lock = ""					-- unlock mouse
	oa.osize = 32					-- overview-size to default 32
	
	-- debug - calculate the perfect size for the window
	local perfectHeight = topLimit +  oa.osize * 16 + 1 + BARSIZE + 5 + ButtonAreaHeight
	local perfectWidth = midX + 32 * (16+8) +1 + BARSIZE + 5
	
	--[[
	if perfectHeight != MINHEIGHT then
		PrintDebug("WRONG MIN HEIGHT:",perfectHeight, MINHEIGHT)
	end
	if perfectWidth != MINWIDTH then
		PrintDebug("WRONG MIN WIDTH:",perfectWidth, MINWIDTH)
	end
	--]]
	
	-- Area-Settings
	oa.areaRect.x = midX
	oa.areaRect.y = topLimit
	oa.areaFullW = (ow - oa.areaRect.x - 5 - BARSIZE - 1)
	oa.areaFullH = (oh - oa.areaRect.y - 5 - BARSIZE - 1 - ButtonAreaHeight)
	
	oa.areaRect.w = math.min( oa.areaFullW \ oa.csize * oa.csize, oa.cellRect.w * oa.csize)
	oa.areaRect.h = math.min( oa.areaFullH \ oa.csize * oa.csize, oa.cellRect.h * oa.csize)
	
	-- move area to the button
	oa.areaRect.y = oa.areaRect.y + (oa.areaFullH - oa.areaRect.h)

	-- overview center
	oa.overviewRect.x = 5
	oa.overviewRect.y = topLimit + (oa.areaFullH - oa.osize * 16) \ 2
	oa.overviewRect.w = oa.osize * 16
	oa.overviewRect.h = oa.osize * 16
	
	-- displaysize of the areaRect
	oa.page.w = math.min(oa.areaRect.w \ oa.csize, oa.cellRect.w)
	oa.page.h = math.min(oa.areaRect.h \ oa.csize, oa.cellRect.h)

	-- be sure that the areaRect is filled completeLimitCellToScreen
	oa:LimitCellToScreen()
	
	-- Position of the scroll bars
	oa.scrollbar.AreaH:SetPos(
		oa.areaRect.x + oa.areaRect.w + 1, 
		oa.areaRect.y, 
		BARSIZE, 
		oa.areaRect.h
	)
	oa.scrollbar.AreaH:SetValues(
		oa.cellRect.y,
		oa.page.h,
		oa.cellRect.h
	)
	
	oa.scrollbar.AreaW:SetPos(
		oa.areaRect.x, 
		oa.areaRect.y + oa.areaRect.h + 1, 
		oa.areaRect.w, 
		BARSIZE
	)
	oa.scrollbar.AreaW:SetValues(
		oa.cellRect.x,
		oa.page.w,
		oa.cellRect.w
	)
		
	-- Position of the  buttons	
	
	-- overview
	local b
	b = oa.buttons.OverviewGrid:SetPos(oa.overviewRect.x, downY)
	oa.buttons.OverviewId:SetRight()
	oa.buttons.OverviewFlags:SetRight()
	oa.buttons.OverviewCount:SetRight()
		
	b = oa.buttons.AnimStart:SetDown(b)
	oa.buttons.AnimSwing:SetRight()
	oa.buttons.AnimWidth:SetRight()
	oa.inputs.AnimSpeed:SetRight()
	
		
	-- area
		
	b = oa.buttons.AreaGrid:SetPos(oa.areaRect.x, downY)
	oa.buttons.AreaID:SetDown(1)
	oa.buttons.AreaHiSel:SetDown(1)		
	oa.buttons.AreaCopy00:SetDown(1)
	
	b = oa.buttons.AreaStamp:SetRight(b)
	oa.buttons.AreaLine:SetDown(1)
	oa.buttons.AreaBox:SetDown(1)
	oa.buttons.AreaEllipse:SetDown(1)
	
	b = oa.buttons.AreaFill:SetRight(b,1)
	oa.buttons.AreaLines:SetDown(1)
	oa.buttons.AreaFilledBox:SetDown(1)
	oa.buttons.AreaFilledEllipse:SetDown(1)
	
	-- label / sprite / charset
	b = oa.buttons.Color0:SetRight(b,7)
	for i = 1,Pico.PALLEN - 1 do
		if (i % 4) == 0 then
			b = oa.buttons["Color" .. i]:SetDown(b,1)
		else
			oa.buttons["Color" .. i]:SetRight(1)
		end
	end
	
	-- map
	b = oa.buttons.MAPPOS:SetRight(oa.buttons.AreaFill)
	oa.buttons.MAPWIDTH:SetDown(1)
	
	b = oa.buttons.AreaFlags:SetRight(b)
	oa.buttons.AreaBackground:SetDown(1)
	
	-- sprite
	b = oa.buttons.AreaFlipX:SetRight(oa.buttons.MAPPOS)
	oa.buttons.AreaFlipY:SetDown(1)
	oa.buttons.AreaTurnLeft:SetDown(1)
	oa.buttons.AreaTurnRight:SetDown(1)
	
	b = oa.buttons.AreaShiftLeft:SetRight(b)
	oa.buttons.AreaShiftRight:SetDown(1)
	oa.buttons.AreaShiftUp:SetDown(1)
	oa.buttons.AreaShiftDown:SetDown(1)
	
	b= oa.buttons.SPRITEPOS:SetRight(b)
	oa.buttons.SPRFLAGPOS:SetDown(1)
	oa.buttons.sprIcon:SetDown()
	
	--charset
	b = oa.inputs.CharLowWidth:SetRight(oa.buttons.AreaShiftLeft)
	oa.inputs.CharHighWidth:SetDown(1)
	oa.inputs.CharHeight:SetDown(1)
	oa.inputs.CharOffsetX:SetDown(1)
	oa.inputs.CharOffsetY:SetRight(1)
	b = oa.buttons.CharAdjustEnable:SetRight(b)
	oa.inputs.CharAdjust:SetDown(1)
	oa.buttons.CharOneUp:SetDown(1)
		
		
	local w1,h1 = SizeText("+")
	
	oa.infoMapSize.x = oa.buttons.MAPWIDTH.rectBack.x + (oa.buttons.MAPWIDTH.rectBack.w - w1 * 7) \ 2
	oa.infoMapSize.y = oa.buttons.MAPWIDTH.rectBack.y + oa.buttons.MAPWIDTH.rectBack.h + 1 + (oa.buttons.MAPWIDTH.rectBack.h - h1 ) \ 2

	oa.infoMapSizeByte.x = oa.buttons.MAPWIDTH.rectBack.x + (oa.buttons.MAPWIDTH.rectBack.w - w1 * 11) \ 2
	oa.infoMapSizeByte.y = oa.buttons.MAPWIDTH.rectBack.y + (oa.buttons.MAPWIDTH.rectBack.h + 1)*2 + (oa.buttons.MAPWIDTH.rectBack.h - h1 )\ 2
	
	-- Position of the info field
	local y, h = oh - oa.buttons.Flag0.rectBack.h - 5 , oa.buttons.Flag0.rectBack.h
		
	oa.infoCoordRect.x = 5
	oa.infoCoordRect.y = y + (h - h1)\2
	oa.infoCoordRect.w = w1 * 12-- 12 characters
	oa.infoCoordRect.h = h1
		
	oa.infoHexRect.x = oa.infoCoordRect.x + oa.infoCoordRect.w + 15
	oa.infoHexRect.y = y + (h - h1)\2
	oa.infoHexRect.w = w1 * 2-- 2 characters
	oa.infoHexRect.h = h1	
		
	oa.infoIconRect.x = oa.infoHexRect.x + oa.infoHexRect.w + 5
	oa.infoIconRect.y = y
	oa.infoIconRect.w = h
	oa.infoIconRect.h = h
		
	oa.buttons.Flag0:SetPos(
		oa.infoIconRect.x + oa.infoIconRect.w + 5 + w1 * 7 + 5, 
		y
	)
	
	for i=1,7 do
		oa.buttons["Flag"..i]:SetRight(oa.buttons["Flag"..(i-1)],1)
	end
	
	-- disable special buttons
	
	oa.buttons.AreaFlags.visible = false
	
	for i=0,0xf do
		oa.buttons["Color"..i].visible = false
	end
	for i=0,7 do 
		oa.buttons["Flag"..i].visible = false
	end
	
	oa.buttons.SPRITEPOS.visible = false	
	oa.buttons.SPRFLAGPOS.visible = false
	oa.buttons.sprIcon.visible = false 
	
	oa.buttons.MAPPOS.visible = false
	oa.buttons.MAPWIDTH.visible = false
	
	oa.buttons.AreaBackground.visible = false
	
	oa.inputs.CharLowWidth.visible = false
	oa.inputs.CharHighWidth.visible = false
	oa.inputs.CharHeight.visible = false
	oa.inputs.CharOffsetX.visible = false
	oa.inputs.CharOffsetY.visible = false
	oa.inputs.CharAdjust.visible = false
	oa.buttons.CharAdjustEnable.visible = false
	oa.buttons.CharOneUp.visible = false
	
	oa.buttons.OverviewFlags.visible = false
	oa.buttons.OverviewCount.visible = false
	oa.buttons.OverviewId.visible = false
	
	oa.buttons.AnimStart.visible = false
	oa.inputs.AnimSpeed.visible = false
	oa.buttons.AnimSwing.visible = false
	oa.buttons.AnimWidth.visible = false
	
	oa.buttons.AreaFlipX.visible = false
	oa.buttons.AreaFlipY.visible = false
	oa.buttons.AreaTurnLeft.visible = false
	oa.buttons.AreaTurnRight.visible = false
	
	oa.buttons.AreaShiftLeft.visible = false
	oa.buttons.AreaShiftRight.visible = false
	oa.buttons.AreaShiftUp.visible = false
	oa.buttons.AreaShiftDown.visible = false
	
	oa.buttons.AreaHiSel.visible = false
	
end

-- set optimal zoom level for sprites
function overAreaMeta.OverviewBestZoom(oa)
	if not config.doAutoOverviewZoom then return false end
		
	local sel = zoomLevels[1][1]
	
	local w,h = #oa.copy.icon.a[1] * 8, #oa.copy.icon.a * 8 
	local maxZoom = 64
	if h >= 16 then
		maxZoom = 32
	elseif h >= 32 then
		maxZoom =9999
	end
		
	for nb,z in pairs(zoomLevels) do
		if z[2] * w <= oa.areaFullW and z[2] * h <= oa.areaFullH and z[2] <= maxZoom then
			sel = z[1]
		end			
	end

	return MenuSetZoom(sel)
end

-- free all resources
function overAreaMeta.Quit(oa)
	if not oa.hasInit then return end
	oa.buttons:DestroyContainer()
	oa.inputs:DestroyContainer()
	oa.menuBar:Destroy()
	
	popup:Remove(ppColor)
	oa.hasInit = false
end

-- initalize everything
function overAreaMeta.Init(oa)
	if oa.hasInit then return end
	
	-- additional configuration
	config.clipboardAsHex = config.clipboardAsHex != nil and config.clipboardAsHex or false
	configComment.clipboardAsHex = "use hex-values instead of characters - currently only used by charset"
	
	-- we need some buttons, inputs and scrollbars
	oa.buttons = buttons:CreateContainer()
	oa.inputs = inputs:CreateContainer()
	oa.scrollbar = scrollbar:CreateContainer()
	
	-- we have a custom menu
	oa.menuBar = SDL.Menu.Create()	
	MenuAddFile(oa.menuBar)
	local men = MenuAddEdit(oa.menuBar)	
	men:Add()
	MenuAdd(men, "clipboardAsHex", "Use hex values for clipboard", 
		function (e)	
			config.clipboardAsHex = not config.clipboardAsHex
			men:SetCheck("clipboardAsHex", config.clipboardAsHex)
		end
	)
	MenuAddPico8(oa.menuBar)
	MenuAddZoom(oa.menuBar)
	MenuAddSettings(oa.menuBar)
	MenuAddDebug(oa.menuBar)

	oa.MenuUpdate = function (m, men)
		men:SetCheck("clipboardAsHex", config.clipboardAsHex)
	end
		
	-- some buttons
	local b
	local bsize = 95
	oa.buttons:Add("AreaGrid","Grid",bsize,nil,"TOOGLE")
	oa.buttons:Add("AreaID","ID",bsize,nil,"TOOGLE")
	oa.buttons:Add("AreaFlags","Flags",bsize,nil,"TOOGLE")
	
	oa.buttons:Add("AreaHiSel","Find",bsize,nil,"TOOGLE")
	
	b = oa.buttons:Add("AreaCopy00","Show ID00",bsize,nil,"TOOGLE")
	b.selected = true
	
	b = oa.buttons:Add("AreaBackground","Background", bsize,nil)
	b.OnClick = function (but,mx,my)  
		ppColor.index = -1
		ppColor:Open(but.rectBack.x + (but.rectBack.w - ppColor.rect.w)\2,but.rectBack.y)
	end
		
	oa.buttons:Add("AreaStamp","Stamp",bsize,nil,"areatool")
	oa.buttons:Add("AreaLine","Line",bsize,nil,"areatool")
	oa.buttons:Add("AreaLines","Lines",bsize,nil,"areatool")
	oa.buttons:Add("AreaBox","Box",bsize,nil,"areatool")
	oa.buttons:Add("AreaEllipse","Ellipse",bsize,nil,"areatool")
	oa.buttons:Add("AreaFill","Fill",bsize,nil,"areatool")
	oa.buttons:Add("AreaFilledBox","Filled box",bsize,nil,"areatool")
	oa.buttons:Add("AreaFilledEllipse","Filled oval",bsize,nil,"areatool")
	oa.buttons:SetRadio(oa.buttons.AreaStamp)
	
	oa.buttons:Add("OverviewGrid","Grid",bsize,nil,"TOOGLE")
	oa.buttons:Add("OverviewId","Id",bsize,nil,"TOOGLE")
	oa.buttons:Add("OverviewFlags","Flags",bsize,nil,"TOOGLE")
	oa.buttons:Add("OverviewCount","Count",bsize,nil,"TOOGLE")
		
	b = oa.buttons:AddHex("MAPPOS","POS:",0,bsize,nil,Pico.MAPPOS)
	b.hexFilter = 0xff06
	oa.buttons:AddHex("MAPWIDTH","WIDTH:",0,bsize,nil,Pico.MAPWIDTH)
	
	
	b = oa.buttons:AddHex("SPRITEPOS","POS:",0,bsize,nil,Pico.SPRITEPOS)	
	b.hexFilter = 0xff01
	b = oa.buttons:AddHex("SPRFLAGPOS","Flag:",0,bsize,nil,Pico.SPRFLAGPOS)
	b.hexFilter = 0xff08
	
	b = oa.buttons:Add("sprIcon","Set Icon",bsize)
	b.OnClick = function(but)
		local icon = math.min(oa.copy.icon.char,oa.copy.icon.charEnd)
		if icon > 0 then
			local para =  "-i ".. icon .." "
			local w,h = #oa.copy.icon.a[1], #oa.copy.icon.a
			if w == h then
				para ..= "-s ".. w .." "
			end
			activePico:SaveDataSet("pico8", "binaryOptions", para)
			
			InfoBoxSet("Set export icon to sprite "..icon.." " .. (w == h and (w.."x"..w) or "1x1") .. ".")
		else
			activePico:SaveDataSet("pico8","binaryOptions", nil)
			InfoBoxSet("Set export icon to label.")
		end
	end
		
	b = oa.buttons:Add("AreaFlipX","Flip x",bsize,nil)
	b.OnClick = _ButFlipX
	
	b = oa.buttons:Add("AreaFlipY","Flip y",bsize,nil)
	b.OnClick = _ButFlipY
	
	b = oa.buttons:Add("AreaTurnLeft","Turn left",bsize,nil)
	b.OnClick = _ButTurnLeft
	b = oa.buttons:Add("AreaTurnRight","Turn right",bsize,nil)
	b.OnClick = _ButTurnRight
	
	b = oa.buttons:Add("AreaShiftLeft","Shift left",bsize,nil)
	b.OnClick = _ButShiftLeft
	b = oa.buttons:Add("AreaShiftRight","Shift right",bsize,nil)
	b.OnClick = _ButShiftRight
	b = oa.buttons:Add("AreaShiftUp","Shift up",bsize,nil)
	b.OnClick = _ButShiftUp
	b = oa.buttons:Add("AreaShiftDown","Shift down",bsize,nil)
	b.OnClick = _ButShiftDown
		
	-- charset settings
	b = oa.inputs:Add("CharLowWidth",  "Lo wd:", "\0@"..Pico.CHARSET)
	b.min = 0
	b.max = 255
	b = oa.inputs:Add("CharHighWidth", "Hi wd:","\0@"..Pico.CHARSET + 1)
	b.min = 0
	b.max = 255
	b = oa.inputs:Add("CharHeight",    "Hgt  :", "\0@"..Pico.CHARSET + 2)	
	b.min = 0
	b.max = 255
	b = oa.inputs:Add("CharOffsetX",   "Off:", "\0@"..Pico.CHARSET + 3)
	b.min = 0
	b.max = 255
	b = oa.inputs:Add("CharOffsetY",   "", "\0@"..Pico.CHARSET + 4)		
	b.min = 0
	b.max = 255
	b = oa.inputs:Add("CharAdjust","Adj:","-4",85)
	b.min = -4
	b.max = 3
	b.OnTextChange = function(b,text)
		local adjust = math.clamp(-4,3, (tonumber(text) or 0)\1)
		local oneup = oa.buttons.CharOneUp.selected
		local char = oa.copy.icon.a[1][1]
		activePico:CharsetSetVariable(char,adjust,oneup)
	end
	b = oa.buttons:Add("CharOneUp", "One up", oa.inputs.CharAdjust.rectBack.w,nil,"TOOGLE")
	b.OnClick = function(b)
		local adjust = math.clamp(-4,3, (tonumber(oa.inputs.CharAdjust.text) or 0)\1)
		local oneup = b.selected
		local char = oa.copy.icon.a[1][1]
		activePico:CharsetSetVariable(char,adjust,oneup)
	end
	b = oa.buttons:Add("CharAdjustEnable", "Adj.Enable", oa.inputs.CharAdjust.rectBack.w,nil,"TOOGLE")
	b.OnClick = function(b)
		if b.selected then
			activePico:Poke( Pico.CHARSET + 5, activePico:Peek(Pico.CHARSET + 5) | 1)
		else
			activePico:Poke( Pico.CHARSET + 5, activePico:Peek(Pico.CHARSET + 5) & ~1)
		end
	end
	
	
	-- sprite animation
	oa.buttons:Add("AnimStart","Animation",bsize,nil,"TOOGLE")
	oa.buttons:Add("AnimSwing","Swing",bsize,nil,"TOOGLE")
	b = oa.inputs:Add("AnimSpeed","Speed:","6",bsize)
	b.min = 1
	b.max = 20
	oa.buttons:Add("AnimWidth","Wide",bsize,nil,"TOOGLE")
	
	-- sprite flags
	local function flagClick(but)
		if overArea.infoActive then 
			activePico:SpriteFlagSet(overArea.infoActive, but.index, but.selected)
		end
	end
	for i=0,7 do 
		oa.buttons:Add("Flag"..i,i,16,nil,"TOOGLE",Pico.RGB[i + 8],COLBLACK, nil, Pico.RGB[i + 8])		
		oa.buttons["Flag"..i].OnClick = flagClick
		oa.buttons["Flag"..i].index = i
	end
	
	-- color buttons
	local s
	_,s	= oa.buttons:GetSize("+")

	local colorClick = function(but)
		overArea.copy.col.a = {{but.index}}
		overArea.copy.col.char = but.index
		overArea.copy.col.charEnd = but.index
	end
	
	local colorRightClick = function (but)
		ppColor.index = but.index
		ppColor:Open(but.rectBack.x + (but.rectBack.w - ppColor.rect.w)\2, but.rectBack.y)
	end	
	
	for i=0,0xf do
		b = oa.buttons:AddColor("Color" .. i, Pico.RGB[i], s, s)
		b.index = i
		b.OnClick = colorClick
		b.OnRightClick = colorRightClick
	end
	
	-- scrollbars		
	b = oa.scrollbar:Add("AreaW",1,1,true,1,1,1)
	b.onChange = function (sb,value,page,max) overArea.cellRect.x = value \ 1 end
	b = oa.scrollbar:Add("AreaH",1,1,false,1,1,1)
	b.onChange = function (sb,value,page,max) overArea.cellRect.y = value \ 1 end
	
	-- color popup
	local ppClick = function (but)		
		if ppColor.index >= 0 then
			-- set color palette
			activePico:PaletteSetColor( ppColor.index, but.index )
			ppColor:Close()
		else
			-- change backgroundcolor
			overArea.colorBack = but.index
			ppColor:Close()
		end
		--buttons["Color"..ppColor.index]:SetColor( Pico.RGB[but.index] )
	end
		
	ppColor = popup:Add("oaColor", s * 8, s * 4)
	for i=0,0xf do
	  b = ppColor.buttons:AddColor("pset"..i , Pico.RGB[       i], s, s) : SetPos((    i % 4) * s, (i \ 4) * s)
	  b.index = i
	  b.OnClick = ppClick
	  b = ppColor.buttons:AddColor("psetA"..i, Pico.RGB[0x80 + i], s, s) : SetPos((4 + i % 4) * s, (i \ 4) * s)
	  b.index = 0x80 + i
	  b.OnClick = ppClick
	end
	
	
	oa.hasInit = true
end



return overArea