--[[

	buttons library
	
	when you need a button handling in a module, create a new container.
	
	you can add additional settings to a button by changing table values.
	
	.text = content of the button (readonly)
	.visible = is button visible true/false
	.selected = button is selected
	.rectBack = rectangle of the complete button (readonly)
	.shrinkOnDeselected = smaller when not selected (for radio buttons in Tab-style)
	.index = free to use
	.userdata = free to use
	.OnClick = function called when clicked
	.OnRightClick = function called when right button clicked
	.OnClickHex = function clicked hex button
	.hex = hex-value for hex-buttons
	.hexFilter = filter for button-rows (binary)
	.tooltip = show this text as tooltip
	

--]]


local lib = {}
local libMeta = {}

libMeta.__index = libMeta
setmetatable(lib,libMeta)

local _clicked = nil
local _clickedContainer = nil


--===================================================================
---------------------------------------------------hex popup handling
--===================================================================
local _hexButton = nil

-- open hex - popup in AddHex
local function _OpenPopUpHex(but,x,y)
	local yy = ppHex.offy
	
	_hexButton = but
	
	-- reposition lib in popup
	for y=0, 0xf do
		local v = (but.hexFilter & (1<<y)) != 0
		
		for x=0, 0xf do
			local b = ppHex.buttons["hex" .. (y*16 + x)]
			b:SetPos(x * b.rectBack.w + ppHex.offx, yy)
			b.visible = v				
		end
		
		if v then
			yy += ppHex.buttons.hex0.rectBack.h
		end
		
	end
	-- new hight
	ppHex.rect.h = yy - ppHex.offy
	
	-- display popup
	ppHex:Open(but.rectBack.x + (but.rectBack.w - ppHex.rect.w)/2, but.rectBack.y)
	-- activate current state
	ppHex.buttons:SetRadio(ppHex.buttons["hex" .. but.hex])
end

-- click in hex-popup - poke value in adr
local function _ClickOnHexAdrButton(but,x,y)
	activePico:Poke(but.hexadr,but.hex)
	ppHex:Close()
	MainWindowResize() -- recalculate window
end

--===================================================================
------------------------------------------------------button handling
--===================================================================

-- lib initalisieren
function libMeta.Init()
	-- hex popup
	local w2,h2 = SizeText("00")
	w2 += 10
	h2 += 10
	ppHex = popup:Add("buttonHex", w2 * 16,h2 * 16)
	
	local doHexClick = function(but,x,y)
		_hexButton.hex = but.index
		if _hexButton.OnClickHex then _hexButton:OnClickHex(x,y) end	
	end
		
	for y = 0, 0xf do
		for x = 0, 0xf do
			local i = x | (y<<4)
			ppHex.buttons:AddHex("hex"..i,nil,i,w2,h2,"hexvalue") : SetPos(x * w2, y * h2)
			ppHex.buttons["hex"..i].OnClick = doHexClick
			ppHex.buttons["hex"..i].index = i
		end
	end
	return true
end

-- deinitalize all
function libMeta.Quit(b)
	popup:Remove(ppHex)
	ppHex = nil
	b:DestroyContainer()
end

-- create a container
function libMeta.CreateContainer()
	local t = {}
	setmetatable(t, libMeta)
	return t
end

-- destroy container
function libMeta.DestroyContainer(t)
	while t:Remove(next(t)) do		
	end
end

-- add a button radio can a radio-button identifier or "TOOGLE"
function libMeta.Add(b, id, text, w, h, radio, colPresBack, colPresText, colBack, colBackText)
	text = tostring(text)
	local tw, th = SizeText(text)
	
	-- default size with border
	if w == nil then
		w = tw + 10
	elseif w <= 0 then
		w = tw - w	
	end
	if h == nil then
		h = th + 10
	elseif h <= 0 then
		h = th - h
	end

	b[id] = {
		id = id,
		text = text,
		rectBack = {x = 0, y = 0, w = w, h = h},
		rectText = {x = 0, y = 0, w = tw, h = th},
		visible = true,
		col = {
			normal 		= { text = colBackText                   or COLDARKWHITE, back = colBack                       or COLDARKGREY },
			highnormal 	= { text = ColorOffset(colBackText,0x33) or COLWHITE    , back = ColorOffset(colBack,0x33)     or COLGREY },
			pressed 	= { text = colPresText                   or Pico.RGB[9] , back = colPresBack                   or Pico.RGB[2] },
			highpressed = { text = ColorOffset(colPresText,0x33) or Pico.RGB[10], back = ColorOffset(colPresBack,0x33) or Pico.RGB[8] },
		},
		selected = false,
		radio = radio or "", -- group for radio-lib or "TOOGLE" for toogle-button
		pressed = false,
		OnClick = nil,
	}
	setmetatable(b[id],libMeta)
	return b[id]
end
	
-- add label "button"
function libMeta.AddLabel(b, id, text, w, h, col)	
	text = tostring(text)
	local tw, th = SizeText(text)
	
	-- default size with border
	if w == nil then
		w = tw
	elseif w <= 0 then
		w = tw - w	
	end
	if h == nil then
		h = th
	elseif h <= 0 then
		h = th - h
	end
	
	b[id] = {
		id = id,
		text = text,
		rectBack = {x = 0, y = 0, w = w, h = h},
		rectText = {x = 0, y = 0, w = tw, h = th},
		visible = true,
		col = {
			normal 		= { text = col or COLDARKWHITE, back = COLDARKGREY },
		},
		isLabel = true,
		selected = false,
		radio = "", 
		pressed = false,
		OnClick = nil,
	}
	setmetatable(b[id],libMeta)
	return b[id]
end

-- Add a Hex-Button (hexadr can be a address in activePico OR a radio identifier)
function libMeta.AddHex(b,id, text, hex, w, h, hexadr, colPresBack, colPresText, colBack, colBackText)	
	text = text or ""
	-- render text
	local surface
	local tex
	local tw, th = SizeText(text .. "00")
	
	-- default size with border
	if w == nil then
		w = tw + 10
	elseif w <= 0 then
		w = tw - w	
	end
	if h == nil then
		h = th + 10
	elseif h <= 0 then
		h = th - h
	end
	
	b[id] = {
		hex = hex or 0,
		id = id,
		text = text,
		rectBack = {x = 0, y = 0, w = w, h = h},
		rectText = {x = 0, y = 0, w = tw, h = th},
		visible = true,		
		col = {
			normal 		= { text = colBackText                   or COLDARKWHITE, back = colBack                       or COLDARKGREY },
			highnormal 	= { text = ColorOffset(colBackText,0x33) or COLWHITE    , back = ColorOffset(colBack,0x33)     or COLGREY },
			pressed 	= { text = colPresText                   or Pico.RGB[9] , back = colPresBack                   or Pico.RGB[2] },
			highpressed = { text = ColorOffset(colPresText,0x33) or Pico.RGB[10], back = ColorOffset(colPresBack,0x33) or Pico.RGB[8] },
		},
		selected = false,
		pressed = false,
		
	}
	
	if type(hexadr)=="string" then
		b[id].radio = hexadr
		
	elseif hexadr != nil then
		b[id].OnClick = _OpenPopUpHex
		b[id].OnClickHex = _ClickOnHexAdrButton
		b[id].hexadr = hexadr
		b[id].hexFilter = 0xffff
		b[id].radio = ""
		
	else
		b[id].OnClick = _OpenPopUpHex
		b[id].hexFilter = 0xffff
		b[id].radio = ""
	end	
	
	setmetatable(b[id],libMeta)
	return b[id]
end

-- Add Color-Button
function libMeta.AddColor(b,id, col, w, h, radio)
	b[id] = {
		id = id,
		rectBack = {x = 0, y = 0, w = w, h = h},
		isColor = true,
		rectText = {x = 0, y = 0, w = w - 6, h = h - 6},
		visible = true,		
		selected = false,
		radio = radio or "", -- group for radio-lib or "TOOGLE" for toogle-button
		pressed = false,	
		OnClick = nil,
		OnRightClick = nil,
	}	
	setmetatable(b[id],libMeta)
	b[id]:SetColor(col)
	return b[id]
end

-- Remove a button
function libMeta.Remove(b,but)
	if but and b[but.id] then 
		b[but.id]=nil
		return true
	end
	return false	
end

-- return theoretical size of a button with a text
function libMeta.GetSize(b,text)
	local w,h = SizeText(text)
	return w + 10, h + 10
end

-- change color of a color-button
function libMeta.SetColor(b,col)
	if b.isColor then
		b.col= {
			normal 		= { text = col, back = COLDARKGREY },
			highnormal 	= { text = col, back = COLGREY },
			pressed 	= { text = col, back = col },
			highpressed = { text = col, back = col },
		}
	end
end

-- set active radio button (and release other lib) / toggle-handling
function libMeta.SetRadio(b,sBut)
	if sBut.radio == "TOOGLE" then
		sBut.selected = not sBut.selected

	elseif sBut.radio != "" then
		for id,but in pairs(b) do
			if but.radio == sBut.radio then
				but.selected = false
			end			
		end
		sBut.selected = true
	end
end

-- get active radio-button (only the first one!)
function libMeta.GetRadio(b,radio)
	for id,but in pairs(b) do
		if but.radio == radio and but.selected and but.visible then
			return but
		end
	end
	return nil
end

-- change button-text
function libMeta.SetText(but,text,optimizeSize)
	if but.text == text then return true end
	but.text = text
	text = tostring(text)
	but.rectText.w, but.rectText.h = SizeText(text)
	
	if optimizeSize then
		but.rectBack.w = but.rectText.w + 10
		but.rectBack.h = but.rectText.h + 10
	end
	
	but:SetPos() -- update text-position
end

-- set Position of a button
_lastButOrInput = nil
function libMeta.SetPos(but, x, y)
	but.rectBack.x = x or but.rectBack.x
	but.rectBack.y = y or but.rectBack.y
	but.rectText.x = but.rectBack.x + (but.rectBack.w - but.rectText.w) \ 2
	but.rectText.y = but.rectBack.y + (but.rectBack.h - but.rectText.h) \ 2
	_lastButOrInput = but
	return but	
end

-- set button right from but2
function libMeta.SetRight(but, but2, space)
	if type(but2) != "table" then
		space = but2
		but2 = _lastButOrInput
	end
	return but:SetPos(but2.rectBack.x + but2.rectBack.w + (space or 5), but2.rectBack.y)
end

-- set button left from but2
function libMeta.SetLeft(but, but2, space)
if type(but2) != "table" then
		space = but2
		but2 = _lastButOrInput
	end
	return but:SetPos(but2.rectBack.x - (space or 5) - but.rectBack.w, but2.rectBack.y)
end

-- set button below but2
function libMeta.SetDown(but, but2, space)
	if type(but2) != "table" then
		space = but2
		but2 = _lastButOrInput
	end
	return but:SetPos(but2.rectBack.x, but2.rectBack.y + but2.rectBack.h + (space or 5))
end

-- draw all lib
function libMeta.Draw(b, mx, my)
	local p = {mx, my}
	local offset
	
	isLocked = _clicked != nil and _clickedContainer == b 
	
	for nb, but in pairs(b) do
		if but.visible then 
			if but.shrinkOnDeselected and not but.selected then
				offset = 2
			else
				offset = 0 
			end
		
			-- update from adr
			if but.hexadr then
				but.hex = activePico:Peek(but.hexadr)
			end
		
			-- choose color
			local col
			local isMouseIn = false
			if but.isLabel then
				col = but.col.normal
			else
				
				if _clicked == but or not isLocked then
					isMouseIn = SDL.Rect.ContainsPoint(but.rectBack,p) 
				end
			
				col = 
					isMouseIn
					and	( ((but.pressed or but.selected) and not but.pressed == but.selected) and but.col.highpressed or but.col.highnormal)
					or	( ((but.pressed or but.selected) and not but.pressed == but.selected) and but.col.pressed or but.col.normal)
			end
			
			-- draw background 
			if not but.isLabel then
				DrawFilledRect({but.rectBack.x + offset\2, but.rectBack.y + offset, but.rectBack.w - offset , but.rectBack.h - offset}, col.back,255,true)
			end
			
			if but.isColor then 
				-- color button
				DrawFilledRect(but.rectText, col.text)
				
			elseif but.hex != nil then
				-- hex button
				DrawText(
					but.rectText.x, 
					but.rectText.y + offset\2,
					string.format("%s%02x",but.text or "",but.hex),
					col.text
				)
				
			elseif but.text != "" and but.text != nil then
				-- normal button
				DrawText(but.rectText.x, but.rectText.y + offset\2,but.text,col.text)				
			end
				
			if but.tooltip and isMouseIn then
				TooltipText(but.tooltip, but.rectBack)
			end
				
			
		end
	end
	
	return isLocked
	
end

-- button start click
function libMeta.MouseDown(b,mx, my, mb)	
	if mb == "LEFT" or mb == "RIGHT" then
		for id,but in pairs(b) do
			if not but.isLabel and but.visible and SDL.Rect.ContainsPoint(but.rectBack, {mx, my}) then				
				but.pressed =  (mb == "LEFT")
				_clicked = but
				_clickedContainer = b
				return true
			end			
		end
	end
	return false
end

-- mouse move button
function libMeta.MouseMove(b, mx, my, mb)
	if _clicked != nil and _clickedContainer == b then
		_clicked.pressed = SDL.Rect.ContainsPoint(_clicked.rectBack, {mx, my}) 
	end
	return false
end


-- button click
function libMeta.Click(b,clicked)
	if clicked.isLabel or not clicked.visible then return false end
	b:SetRadio(clicked) -- radio button handling
	if clicked.OnClick then clicked.OnClick(clicked,mx,my) end
	clicked.pressed = false
end

-- button end click
function libMeta.MouseUp(b, mx, my, mb)	
	if _clicked != nil and _clickedContainer == b and (mb == "LEFT" or mb == "RIGHT") then
		
		if SDL.Rect.ContainsPoint(_clicked.rectBack, {mx, my}) then
			if mb == "LEFT" then 
				b:SetRadio(_clicked) -- radio button handling
				if _clicked.OnClick then _clicked.OnClick(_clicked,mx,my) end
			else
				if _clicked.OnRightClick then _clicked.OnRightClick(_clicked,mx,my) end
			end
		end
		_clicked.pressed = false
		_clicked = nil
		_clickedContainer = nil
		return true
	end
	return false
end

-- return true, if the button is visible and selected
function libMeta.IsSelected(b)
	return b.visible and b.selected
end

return lib