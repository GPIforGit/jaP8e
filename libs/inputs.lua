--[[

	input-field library
	
	you can add additional settings to a input by changing table values.

	.text = current text
	.textLimit = limit text size
	.rectBack = rectange contain the complete input (readonly)
	.visible = is the input visible true/false
	.OnTextChange = text changed (only after finish editing)
	.OnReturn = return has pressed
	.OnLostFocus = input lost focus
	.OnGainedFocus = input got focus
	.min = minimum value (only for mouse wheel)
	.max = maximum value (only for mouse wheel)

--]]
local lib = {}
local libMeta = {}
libMeta.__index = libMeta
setmetatable(lib, libMeta)

local _hasFocus = nil
local _hasClicked = nil
local _hasRightClicked = nil
local _hasLib = nil
local _oldtext = nil

-- limit Input text and correct cursor pos
function _Limit(inp)
	if #inp.text > inp.textLimit then inp.text = inp.text:sub(1,inp.textLimit) end
	inp.cursor = math.clamp(0, #inp.text, inp.cursor)
	inp.cursorEnd = math.clamp(0, #inp.text, inp.cursorEnd)	
end
	
-- initaliize inputs
function libMeta.Init(l)
	-- nothing to do
end

-- quit inputs
function libMeta.Quit(l)
	l:DestroyContainer()
end

-- create Input container
function libMeta.CreateContainer()
	local t = {}
	setmetatable(t, libMeta)
	return t
end

-- remove Input container
function libMeta.DestroyContainer(t)
	while t:Remove(next(t)) do		
	end
end

-- add a Input
function libMeta.Add(l, id, label, text, w, h, col, colBack, colSel, colLabel, colBackInput)
	label = label or ""
	
	local adr
	local ww,hh = SizeText("+")
	local labelOff = #label * ww
	
	if label != "" then labelOff +=5 end
	
	if text and text:sub(1,2) == "\0@" then
		adr = tonumber(text:sub(3))
		text = "000"
	end
	
	if w then
		if w <= 0 then
			w = (#text + 1) * ww - w + labelOff
		end
	else
		w = (#text + 1) * ww + 10 + labelOff
	end
	if h then
		if h <= 0 then
			h = hh - h
		end
	else
		h = hh + 10
	end
		
	l[id] = {
		text = text,
		label = label,
		labelOff = labelOff,
		adr = adr,
		col = col or Pico.RGB[7],
		colBack = colBack or Pico.RGB[5],
		colSel = colSel or Pico.RGB[8],
		colLabel = colLabel or Pico.RGB[6],
		colBackInput = colBackInput or COLDARKGREY,
		cursor = #text,
		cursorEnd = #text,
		rectBack = {x = 0, y = 0, w = w, h = h},
		rectText = {x = labelOff, y = 0, w = w - labelOff-10, h = h-10},
		textLimit = (w - labelOff-10)\ww - 1,
		visible = true,
	}
	setmetatable(l[id], libMeta)
	return l[id]
end

-- resize input
function libMeta.Resize(inp, w, h)
	local ww,hh = SizeText("+")
	inp.rectBack.w = w or inp.rectBack.w
	inp.rectBack.h = h or inp.rectBack.h
	inp.rectText.w = inp.rectBack.w - inp.labelOff - 10
	inp.rectText.h = inp.rectBack.h - 10
	inp.textLimit = (w - inp.labelOff - 10) \ ww - 1
	inp:SetPos()	
end

-- remove Input
function libMeta.Remove(l, inp)
	if inp and l[inp.id] then 
		l[inp.id] = nil
		return true
	end
	return false	
end

-- position Input
_lastButOrInput = nil
function libMeta.SetPos(inp, x, y)
	inp.rectBack.x = x or inp.rectBack.x
	inp.rectBack.y = y or inp.rectBack.y
	
	inp.rectText.x = inp.rectBack.x + 5 + inp.labelOff
	inp.rectText.y = inp.rectBack.y + 5	
	_lastButOrInput = inp
	return inp
end

-- set right
function libMeta.SetRight(inp, I2, space)
	if type(I2) != "table" then
		space = I2
		I2 = _lastButOrInput
	end
	return inp:SetPos(I2.rectBack.x + I2.rectBack.w + (space or 5), I2.rectBack.y)
end

-- set left
function libMeta.SetLeft(inp, I2, space)
	if type(I2) != "table" then
		space = I2
		I2 = _lastButOrInput
	end
	return inp:SetPos(I2.rectBack.x - (space or 5) - inp.rectBack.w, I2.rectBack.y)
end

-- set down
function libMeta.SetDown(inp, I2, space)
	if type(I2) != "table" then
		space = I2
		I2 = _lastButOrInput
	end
	return inp:SetPos(I2.rectBack.x, I2.rectBack.y + I2.rectBack.h + (space or 5))
end

-- draw
function libMeta.Draw(l)
	local ww,hh = SizeText("+")
	for nb,inp in pairs(l) do
		if inp.visible then
			DrawFilledRect(inp.rectBack, inp.colBack, 255, true)
			DrawFilledRect( {inp.rectText.x - 2,inp.rectText.y - 2, inp.rectText.w + 4, inp.rectText.h +4}, inp.colBackInput, 255, true )
			
			if _hasFocus == inp then
				-- draw cursor
				local s,e = inp.cursor, inp.cursorEnd
				if s > e then s,e = e,s end			
				DrawFilledRect( {inp.rectText.x + s * ww , inp.rectText.y , (e - s + 1) * ww, hh}, inp.colSel )
				
			elseif inp.adr then
				-- update from adress
				inp.text = tostring(activePico:Peek(inp.adr))
			end
			
			-- draw label und text
			DrawText(inp.rectText.x - inp.labelOff, inp.rectText.y, inp.label, inp.col)
			DrawText(inp.rectText.x, inp.rectText.y, inp.text, inp.colLabel)
						
		end
	end
end

-- remove focus from Input
function libMeta.RemoveFocus(l,forced,doreturn)
	local onRet,onLost,onChange
	if _hasFocus then 
		if _hasFocus.adr then
			-- update memory
			activePico:Poke(_hasFocus.adr, tonumber(_hasFocus.text) or activePico:Peek(_hasFocus.adr))
		end
		if _hasFocus.text != _oldtext or forced then
			if _hasFocus.OnTextChange then onChange = _hasFocus end 
		end
		if doreturn then
			if _hasFocus.OnReturn then onRet = _hasFocus end
		end
		
		if _hasFocus.OnLostFocus then onLost = _hasFocus  end	
	end
	_hasFocus = nil
	_hasLib = nil
	_hasClicked = nil
	
	if onRet then onRet.OnReturn(onRet, onRet.text) end
	if onLost then onLost.OnLostFocus(onLost) end
	if onChange then onChange.OnTextChange(onChange, onChange.text) end
	
end

-- activate Input
function libMeta.SetFocus(l,inp, selectAll)
	if _hasFocus and _hasLib and _hasFocus != inp then _hasLib:RemoveFocus() end
	_hasFocus = inp
	_hasLib = l
	_hasClicked = nil
	_Limit(inp)
	_oldtext = inp.text
	if selectAll then
		inp.cursor = 0
		inp.cursorEnd = #inp.text
		_Limit(inp)
	end
	
	if _hasFocus and _hasFocus.OnGainedFocus then _hasFocus.OnGainedFocus(_hasFocus) end	
end

-- true if an Input has focus				 
function libMeta.HasFocus(l)
	return _hasFocus != nil --and _hasLib == l
end

-- mousebutton down
function libMeta.MouseDown(l, mx, my, mb, mbclicks)
	local ww,hh = SizeText("+")
	if mb == "RIGHT" and _hasRightClicked == nil and _hasClicked == nil then
		for id,inp in pairs(l) do
			if inp.visible and tonumber(inp.text) != nil and SDL.Rect.ContainsPoint(inp.rectBack, {mx, my}) then	
				-- rightclick - start fast change with mouse-x
				l:SetFocus(inp)
				_hasRightClicked = inp
				inp.oldmx = mx
				inp.oldText = tonumber(inp.text)
				inp.text = tostring(inp.oldText)
				inp.cursor = 0
				inp.cursorEnd = #inp.text
				_Limit(inp)
				SDL.Cursor.Set(cursorHand)
				
				return true
			end
		end
	end
	
	if mb == "LEFT" and _hasRightClicked == nil and _hasClicked == nil then
		for id,inp in pairs(l) do
			if inp.visible and SDL.Rect.ContainsPoint(inp.rectBack, {mx, my}) then
				l:SetFocus(inp)
				
				local x,y = (mx - inp.rectText.x) \ ww, (my - inp.rectText.y) \ hh
				if y == 0 and x >= 0 and x < inp.textLimit then					
					if mbclicks == 1 or (inp.cursor == 0 and inp.cursorEnd == #inp.text) then 
						-- click in text - set cursor
						_hasClicked = inp
						inp.cursor = x
						inp.cursorEnd = x
						_Limit(inp)
					else
						-- select all
						inp.cursor = 0
						inp.cursorEnd = #inp.text
						_Limit(inp)
					end
				else
					-- select all
					inp.cursor = 0
					inp.cursorEnd = #inp.text
					_Limit(inp)
				end			
				
				return true
			end			
		end
	end
	l:RemoveFocus()	
	return false
end

-- move
function libMeta.MouseMove(l, mx, my,mb)
	local ww,hh = SizeText("+")
	if _hasRightClicked and _hasLib == l then
		-- modefy value with mousemovement
		local delta = (mx - _hasRightClicked.oldmx) \ ww		
		
		local newValue = _hasRightClicked.oldText + delta
		if _hasRightClicked.min and _hasRightClicked.max then newValue = math.clamp(_hasRightClicked.min, _hasRightClicked.max,newValue) end
		
		_hasRightClicked.text = tostring(newValue)			
		_hasRightClicked.cursorEnd = #_hasRightClicked.text
		_Limit(_hasRightClicked)
			
	elseif _hasClicked and _hasLib == l then
		-- select a text
		local x,y = math.ceil( (mx - _hasClicked.rectText.x) / ww ) - 1, (my - _hasClicked.rectText.y) \ hh
		if y == 0 and x >= 0 then
			_hasClicked.cursorEnd = x
			_Limit(_hasClicked)
		end
	end
end

-- mousebutton up
function libMeta.MouseUp(l, mx, my, mb) 
	if _hasRightClicked and _hasLib == l and mb == "RIGHT" then
		_hasLib:RemoveFocus()
		_hasRightClicked = nil
		SDL.Cursor.Set(cursorArrow)
		
	elseif _hasClicked and _hasLib == l and mb == "LEFT" then
		_hasClicked = nil
	end
end

-- mousewheel can change value
function libMeta.MouseWheel(l,x,y,mx,my)
	for id,inp in pairs(l) do
		if inp.visible and tonumber(inp.text) != nil and SDL.Rect.ContainsPoint(inp.rectBack, {mx, my}) then
			-- wheel can change value of Input
			local hadFocus = _hasFocus == inp
			
			l:SetFocus(inp)
			inp.text = tonumber(inp.text) + (y>0 and 1 or -1)
			if inp.min and inp.max then inp.text = math.clamp(inp.min, inp.max, inp.text) end
			inp.text = tostring(inp.text)
			_Limit(inp)
			inp.cursor = 0
			inp.cursorEnd = #inp.text
			
			if not hadFocus then 
				_hasLib:RemoveFocus()
			end
			return true
		
		end
	end
	return false
end

-- keyboard pressed -> cursor, backspace, delete
function libMeta.KeyDown(l, sym, scan, mod)
	if mod:hasflag("CTRL ALT GUI") > 0 then return false end
	if _hasFocus and _hasLib == l then
	
		-- cursor movement
		local off
		if sym == "LEFT" then
			off = -1
		elseif sym == "RIGHT" then
			off = 1
		elseif sym == "HOME" then
			off = -9999
		elseif sym == "END" then
			off = 9999
		end	
		
		if off then 
			if mod:hasflag("SHIFT") == 0 then 	
				_hasFocus.cursorEnd += off
				_hasFocus.cursor = _hasFocus.cursorEnd
			else
				_hasFocus.cursorEnd += off
			end
			_Limit(_hasFocus)
		end	
		
		if sym == "BACKSPACE" then
			local s,e = _hasFocus.cursor, _hasFocus.cursorEnd
			if s > e then s,e = e,s end	
			if s != e then
				-- remove selected text
				_hasFocus.text = _hasFocus.text:sub(1, s) .. _hasFocus.text:sub(e + 2)
			elseif s > 0 then 
				-- normal backspace
				s -= 1
				_hasFocus.text = _hasFocus.text:sub(1, s) .. _hasFocus.text:sub(e + 1)
			end
			_hasFocus.cursor = s
			_hasFocus.cursorEnd = s
			_Limit(_hasFocus)
			
		elseif sym == "DELETE" then
			local s,e = _hasFocus.cursor, _hasFocus.cursorEnd
			if s > e then s,e = e,s end	
			_hasFocus.text = _hasFocus.text:sub(1, s) .. _hasFocus.text:sub(e + 2)
			_hasFocus.cursor = s
			_hasFocus.cursorEnd = s
			_Limit(_hasFocus)
		
		elseif sym == "KP_ENTER" or sym == "RETURN" then			
			_hasLib:RemoveFocus(true,true)
			
		elseif sym == "ESCAPE" then	
			_hasFocus.text = _oldtext
			_hasLib:RemoveFocus()	
			
		elseif sym == "TAB" and _hasFocus.tab then
			_hasLib:SetFocus(_hasFocus.tab, true)
			
		end
		
		
		return true		
	end
	return false
end

-- keyboard has released
function libMeta.KeyUp(l, sym, scan, mod)
	if _hasFocus and _hasLib == l then
		return true
	end
	return false
end

-- user has input a "string"
function libMeta.Input(l, str)
	if _hasFocus and _hasLib == l then
		str = activePico:StringUTF8toPico(str)
		if str and str != "" then
			local s,e = _hasFocus.cursor, _hasFocus.cursorEnd
			if s > e then s,e = e,s end	
			if s != e then
				_hasFocus.text = _hasFocus.text:sub(1, s) .. str .. _hasFocus.text:sub(e + 2)
			else
				_hasFocus.text = _hasFocus.text:sub(1, s) .. str .. _hasFocus.text:sub(e + 1)
			end
			_hasFocus.cursor = s + #str
			_hasFocus.cursorEnd = s + #str
			_Limit(_hasFocus)		
		end
		return true
	end
	return false	
end

-- clipboard string to paste 
function libMeta.Paste(l, str)
	return l:Input(str)
end

-- return string to copy in clipboard
function libMeta.Copy(l)
	if _hasFocus and _hasLib == l then
		local s,e = _hasFocus.cursor, _hasFocus.cursorEnd
		if s > e then s,e = e,s end			
		return _hasFocus.text:sub(s+1,e+1)
	end
	return nil
end

return lib