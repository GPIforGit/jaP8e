--[[
	source code modul
	
	
--]]

modules = modules or {}
local m = {
	name = "Lua", -- name
	sort = 10,  --- sort order - 0-100 is reserved, also init-order
}
table.insert(modules, m)


local _rectSourceCode -- rect sourcecode + linenumbers
local _rect128x128	-- left rect with infos
local _128Size = 32	-- for 16x16 rect
local _128SizeBig = 64 -- for 8x8 rect
local _lines = {}	-- position of the line in sourcecode
local _functions = {} -- list of all functions in current tab
local _rectNumber -- rect for linenumbers
local _colors = {} -- colorinformation of a character in sourcecode
local _cursorPos = 1 
local _cursorPosEnd = 1
local _mouseLock
local _tabs = {} -- table with tab information
local _activeTab = 0
local _functionSelected -- cursor is in this function
local _maxLineWidth -- max Line Width of current tab
local _ppLuaFind -- search dialog
local _findText = ""
local _replaceText = ""
local _wordIndent ={ -- tabel to control idents by some words
	["function"] = {before = 0, after = 1, forceBefore = 0} , ["end"] = {before = -1, after = 0, forceBefore = 0}, ["do"] = {before = 0, after = 1, forceBefore = 0}, 
	["then"] = {before = 0, after = 1, forceBefore = 0}, ["repeat"] = {before = 0, after = 1, forceBefore = 0}, ["until"] = {before = -1, after = 0, forceBefore = 0},
	["elseif"] = {before = 0, after = 0, forceBefore = -1}, ["else"] = {before = 0, after = 1, forceBefore = -1}
	} 
local _ppLuaGoto -- goto dialog
local _wordColor -- special 
local _rgb = {} -- color information
local _puny = true
local _leftSideMode = "function"
local _sfxUsedIn = {}
local _leftSideSFX, _leftSideMusic
local _ALPHANUMERICSTRING = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"
local _ALPHANUMERIC = {}
local _BRACES = {[40] = 1, [41] = -1, [91] = 1, [93] = -1, [123] = 1, [125] = -1} -- braces 1=open, -1=close

-- convert _ALPHANUMERICSTRING to _ALPHANUMERIC
for nb,c in string.codes(_ALPHANUMERICSTRING) do
	_ALPHANUMERIC[c] = true	
end

-- not in puny-mode shift keys
local _altKeys = {A = "█", B = "▒", C = "🐱", D = "⬇️", E = "░", F = "✽", G = "●", H = "♥", I = "☉", J = "웃", K = "⌂", L = "⬅️", M = "😐", N = "♪", O = "🅾️", P = "◆",
					Q = "…", R = "➡️", S = "★", T = "⧗", U = "⬆️", V = "ˇ", W = "∧", X = "❎", Y = "▤", Z = "▥" }

-- face braces are used for name detection of table-members.
local _fakeBraces = {
	["do"] = "<", ["end"] = ">", ["repeat"] = "<", ["until"] = ">", ["then"] = "<", ["elseif"] = ">", ["function"] = "<"
}


--===================================================================
-----------------------------------------------------------------Font
--===================================================================
local _fontPicoWidth = {} 
local _fontPicoWidthMin = {}
local _fontPicoYPos = {}
local _fontPicoHeight 
local _fontMaxDigitWidth
local _fontMaxWidth
local _fontOwn
local _fontOwnList = {}
local _fontMidCharWidth

local function _FontInit()
	local w1,h1 =  SizeText("+")
	local w2,h2 =  SizeText("+",2)
	Add = function(z)
		table.insert( _fontOwnList, {w = w1 * z, h = h1 * z, z = z, f = 1})
		table.insert( _fontOwnList, {w = w2 * z, h = h2 * z, z = z, f = 2})
	end
	Add(0.5)
	Add(1)
	Add(2)
	
	table.sort(_fontOwnList, function(a,b) return a.w < b.w end )	
end

local function _FontPixelSize(s,e)
	if s > e then s,e = e,s end
	local lw, hw, h = activePico:Peek(Pico.CHARSET) , activePico:Peek(Pico.CHARSET+1), activePico:Peek(Pico.CHARSET+2)
	local adjEnable = (activePico:Peek(Pico.CHARSET + 5) & 1) == 1
	local w = 0
	for pos,char in activePico:LuaCodes(s,e-1) do
		local offx, oneup = activePico:CharsetGetVariable(char)
		w += (char < 0x80 and lw or hw) + (adjEnable and offx or 0)	
	end
	return w
end

local function _FontChoose()
	if config.LuaFontCustom then
		local lw,hw
		local count = 0
		lw, hw, _fontPicoHeight = activePico:Peek(Pico.CHARSET) , activePico:Peek(Pico.CHARSET+1), activePico:Peek(Pico.CHARSET+2)
		local adjEnable = (activePico:Peek(Pico.CHARSET + 5) & 1) == 1
		_fontMaxDigitWidth = 0
		_fontMidCharWidth = 0
		for char = 0, 255 do 
			local offx, oneup = activePico:CharsetGetVariable(char)
			_fontPicoWidth[char] = (char < 0x80 and lw or hw) + (adjEnable and offx or 0)
			_fontPicoWidthMin[char] = math.min(_fontPicoWidth[char],8)
			_fontPicoYPos[char] = oneup and -1 or 0
			if char >= 48 and char <= 57 and _fontPicoWidth[char] > _fontMaxDigitWidth then 
				_fontMaxDigitWidth = _fontPicoWidth[char]
			end
			if (char >= 65 and char <= 90) or (char >= 97 and char <= 122) then
				_fontMidCharWidth += _fontPicoWidth[char]
				count += 1
			end
				
		end
	
		_fontMidCharWidth \= count
	
		tex = TexturesGetCharset()
		tex:SetAlphaMod(255)
		tex:SetBlendMode("BLEND")
		tex:SetScaleMode("NEAREST")
	else
		_fontOwn = _fontOwnList[config.LuaZoom]
	end	
end

local function _FontDraw(x,y,char,col)
	local tex = TexturesGetCharset()
	
	if type(char) == "string" then
		local yy
		for nb, c in char:codes() do
			x,yy = _FontDraw(x, y, c, col)
		end
		return x, yy
	else
		if config.LuaFontCustom then
			if char != 10 and char != 9 then
				local rectSrc = {
					x = (char & 0xf) * 8,
					y = (char >> 4) * 8,
					w = _fontPicoWidthMin[char],
					h = _fontPicoHeight,
				}
				local rectDest = {
					x = x,
					y = y + _fontPicoYPos[char] * config.LuaZoom,
					w = _fontPicoWidthMin[char] * config.LuaZoom,
					h = _fontPicoHeight * config.LuaZoom
				}
				
				rectDest.x += 1
				rectDest.y += 1				
				tex:SetColorMod(0, 0, 0)
				renderer:Copy(tex, rectSrc, rectDest)
				
				rectDest.x -= 1
				rectDest.y -= 1				
				tex:SetColorMod(col.r, col.g, col.b)
				renderer:Copy(tex, rectSrc, rectDest)
			end
			return x + _fontPicoWidth[char] * config.LuaZoom, y + _fontPicoHeight * config.LuaZoom
		else
			if char >= 65 and char <= 90 then
				char += 97-65
			elseif char >= 97 and char <= 122 then
				char += 65-97
			end		
			return DrawChar(x,y,char,col,_fontOwn.z,_fontOwn.f)
		end
	end
end

local function _FontLineWidth(line, maxOffset, findOffset)	
	if line < 1 and line > #_lines then return 0 end
	
	if maxOffset then	
		maxOffset = math.min(_lines[line].e, _lines[line].s + maxOffset) 
	else
		maxOffset = _lines[line].e
	end
	
	if config.LuaFontCustom then
		local w = 0
				
		for pos,char in activePico:LuaCodes(_lines[line].s, maxOffset ) do 
			w += _fontPicoWidth[char] * config.LuaZoom	
			if findOffset and w > findOffset then
				return pos
			end
		end	
		if findOffset then 
			return _lines[line].e
		end
		return w
	else
		local w = 0
				
		for pos,char in activePico:LuaCodes(_lines[line].s, maxOffset ) do 
			w += char >= 0x80 and _fontOwn.w * 2 or _fontOwn.w
			if findOffset and w > findOffset then
				return pos
			end
		end	
		if findOffset then 
			return _lines[line].e
		end
		return w
	
	end
end

local function _FontHeight() 
	if config.LuaFontCustom then
		return _fontPicoHeight * config.LuaZoom
	else
		return _fontOwn.h
	end
end

local function _FontCharSize(char)
	if config.LuaFontCustom then
		local w = 0
		if type(char) == "string" then
			for pos,c in char:codes() do 
				w += _fontPicoWidth[c] * config.LuaZoom	
			end		
		else
			w = _fontPicoWidth[char] * config.LuaZoom
		end
		return w, _fontPicoHeight * config.LuaZoom
	else
	
		local w = 0
		if type(char) == "string" then
			for pos,c in char:codes() do 
				w += c >= 0x80 and _fontOwn.w * 2 or _fontOwn.w
			end		
		else
			w = char >= 0x80 and _fontOwn.w * 2 or _fontOwn.w
		end
		return w, _fontOwn.h
	end
end

local function _FontNumberWidth()
	if config.LuaFontCustom then
		return _fontMaxDigitWidth * config.LuaZoom
	else
		return _fontOwn.w
	end
end

local function _fontMaxWidth()
	if config.LuaFontCustom then
		return _fontMidCharWidth * config.LuaZoom
	else
		return _fontOwn.w
	end
end

--===================================================================
---------------------------------------------------line/offset/cursor
--===================================================================

-- convert position to line/offset
local function _PosToLineOffset(pos)
	for nb,l in pairs(_lines) do
		if pos >= l.s and pos <= l.e then
			return nb, pos - l.s + 1
		end
	end
	return 1,1
end

-- convert line/offset to position
local function _LineOffsetToPos(line, offset)
	return _lines[math.clamp(1, #_lines, line)].s + offset - 1
end

-- make sure that a cursor is visible
local function _VisibleCursor()
	if _activeTab then
		_cursorPos = math.clamp(_cursorPos, _activeTab.posStart, _activeTab.posEnd)
		_cursorPosEnd = math.clamp(_cursorPosEnd, _activeTab.posStart, _activeTab.posEnd)
	else
		_cursorPos = math.clamp(1, _cursorPos, activePico:LuaLen())
		_cursorPosEnd = math.clamp(1, _cursorPosEnd, activePico:LuaLen())
	end

	local line, pageHeight = m.scrollbar.y:GetValues()
	
	local cLine,cOffset =_PosToLineOffset(_cursorPos)
	
	if cLine - 3 < line then
		line = cLine - 3
	end
	if cLine + 2 > line + pageHeight then
		line = cLine + 2 - pageHeight 
	end	
	m.scrollbar.y:SetValues(line)
	
	
	cPixelOffset = _FontLineWidth(cLine, cOffset - 2)
	local offset, pageWidth = m.scrollbar.x:GetValues()
	if cPixelOffset - 7 * _fontMaxWidth() < offset then
		offset = cPixelOffset - 7 * _fontMaxWidth()
	end
	if cPixelOffset + 6 * _fontMaxWidth() > offset + pageWidth then
		offset = cPixelOffset + 6 * _fontMaxWidth() - pageWidth
	end
	m.scrollbar.x:SetValues(offset)
	
end

-- search for the function where the cursor is in
local _ffs_oldcursor
local function _UpdateFunctionSelection(forced)
	if _ffs_oldcursor == _cursorPos and not forced then
		return -- cursor hasn't move
	end
	
	_ffs_oldcursor = _cursorPos

	-- search in table
	local selFn	
	for nb, fn in pairs(_functions) do 
		if _cursorPos >= fn.posStart and ( fn.posTail == nil or _cursorPos <= fn.posTail) then
			selFn = fn
			-- no break, because they could be nested
		end
	end
	
	if _functionSelected != selFn or forced then
		_functionSelected = selFn
		if selFn then 	
			-- make sure the selection is visible
			local line, pageHeight = m.scrollbar.fnY:GetValues()		
			if selFn.nb - 3 < line then
				line = selFn.nb - 3
			end
			if selFn.nb + 2 > line + pageHeight then
				line = selFn.nb + 2 - pageHeight
			end			
			m.scrollbar.fnY:SetValues(line)
		else
			m.scrollbar.fnY:SetValues(0)
		end
	end
end


--===================================================================
----------------------------------------------------coloring/phrasing
--===================================================================

-- remove empty tabs. 
local function _ClearEmptyTabs()
	-- important - undo will create a deleted tab and the cursor is then outside!
	-- to prevent this, _clearEmptyTabs should only be called, when the user changes some text
	-- for example when he enter a key. So the "tab-delete"-Action is combined with the user
	-- action.
	
	local pos,posEnd,newpos = 0
	local max = activePico:LuaLen()
	local os,oe
	while pos do
		os,oe = posEnd, newPos
		posEnd,newPos = activePico:LuaFind("\n-->8\n",pos,true) -- pico8 stores a tab-mark with -->8
		
		-- Empty tab?
		if  pos +1 == (posEnd or max) and _cursorPos < pos +1 then
			-- erase it!
			activePico:LuaReplace(os - 1, oe, "")
						
			-- correct the stored position of the tabs
			activePico.userdata_luaTabs = activePico.userdata_luaTabs or {}
			for nb = #_tabs, 15 do
				activePico.userdata_luaTabs[nb] = activePico.userdata_luaTabs[nb+1]
			end
			
			-- restart search!
			_tabs = {}
			pos = 0
			max = activePico:LuaLen()
		else
			pos = newPos		
		end
		
	end
end

-- find all avaible tabs, update buttons
local function _ScanForTabs()
	local ow, oh = renderer:GetOutputSize()
	_tabs = {}
	local pos,posEnd,newpos,nextline = 0
	local max = activePico:LuaLen()
	local os,oe
	local b
	while pos do
		os,oe = posEnd, newPos
		posEnd,newPos = activePico:LuaFind("\n-->8\n",pos,true) -- pico8 stores a tab-mark with -->8
		
		-- in the next line is the name of the tab
		nextline = activePico:LuaFind("\n",pos+1,true) or (pos + 1)		
		local str = activePico:LuaSub(pos+1,nextline-1)
		if #_tabs > 0 and str:sub(1,2) == "--" then
			str = str:sub(3):trim()
		else 
			str = string.format("-%x-",#_tabs)
		end
		
		-- max 15 tabs!
		if #_tabs == 14 then
			-- next is the last!
			posEnd = max
			newPos = max
		end
		
		-- insert tab in table
		table.insert(_tabs, {
			b = m.buttons["tab".. #_tabs],
			posStart = pos +1,
			posEnd =  posEnd or max,
			name = str,
			index = #_tabs + 1
		})
		
		
		
		pos = newPos
	
		
	end
	
	-- how much space does it need?
	local tabsWidth = _rightSide -1 + (#_tabs < 15 and (m.buttons.tabAdd.rectBack.w + 5) or 0) + 5
	for nb, tab in pairs(_tabs) do
		tabsWidth += m.buttons:GetSize(tab.name) + 1
	end
		
	for nb, tab in pairs(_tabs) do
		-- find active tab
		if math.clamp(_cursorPos, tab.posStart, tab.posEnd) == _cursorPos then
			_activeTab = tab
			m.buttons:SetRadio( tab.b)
		end
		
		-- display it
		tab.b.visible = true

		-- full name or short name?
		if tabsWidth > ow then
			tab.b:SetText(tab.name:sub(1,4),true)
			tab.b.tooltip = #tab.name>4 and tab.name or nil
		else
			tab.b:SetText(tab.name,true)
			tab.b.tooltip = nil
		end
		
		-- place the buttons
		if nb == 1 then
			b = tab.b:SetPos(_rightSide, topLimit)
		else
			b = tab.b:SetRight(b,1)		
		end
	end
	
	-- ensure that the active tab is in the current and not from the old _tabs
	_activeTab = _tabs[math.clamp(1,#_tabs,_activeTab.index)]
	

	-- add plus button for more tabs
	if #_tabs < 16 then 
		m.buttons.tabAdd:SetRight(_tabs[#_tabs].b)
		m.buttons.tabAdd.visible = true
	else
		m.buttons.tabAdd.visible = false
	end
	
end

-- colorize the code
local function _ColorizeCode()
	-- very quick and dirty code
	-- maybe not perfect, but it work
	-- it colorize only the code in the current tab.
	--local w2,h2 = SizeText("+",2)
	_lines = {}
	_functions = {}
	
	_maxLineWidth = _rectSourceCode.w --\ h2
	local lineStart = _activeTab.posStart
	local strStart, strType, lastType = 2,-1
	local typ = nil
	local isLineComment
	local isMultiLineString
	local isMultiLineComment
	local isHex
	local hasDot
	local ignoreNext
	local isDQuote,isQuote
	local multideep = 0
	local nextFunctionName = false
	local commentstart = nil
	local lastVar = nil
	local lastVarStart = nil
	
	local braces= {}
	local tableName = {}
	
	local indentBefore = 0
	local indentAfter = 0
	local indentCurrent = 0
	local indentForceBefore = 0
	local indentIgnore = false
	
	for pos,code in activePico:LuaCodes(_activeTab.posStart, _activeTab.posEnd ) do
		if code == 10 then			
			table.insert(_lines,{s = lineStart, e = pos, indent = -1})
			--_maxLineWidth = math.max(_maxLineWidth, pos - lineStart + 10)
			lineStart = pos + 1	
			indentIgnore = isMultiLineComment or isMultiLineString
		end
		
		local typ 
		
		if isDQuote then
			typ = 34
			if code == 92 and not ignoreNext then
				-- escape
				ignoreNext = true
		
			elseif code == 34 then
				-- end?
				if not ignoreNext then
					isDQuote = false
				end
				ignoreNext = false
			
			elseif code == 10 then
				typ = 10
			
			else
				ignoreNext = false
			end
			
		elseif isQuote then
			typ = 39
			if code == 92 and not ignoreNext then
				-- escape
				ignoreNext = true
		
			elseif code == 39 then
				if not ignoreNext then
					isQuote = false
				end
				ignoreNext = false
			
			elseif code == 10 then
				typ = 10
			
			else
				ignoreNext = false
			end
		
		elseif strType == 45 and ((code == 45 and pos == strStart +1) or (code == 91 and pos >= strStart+2 and pos <= strStart+3)) then
			-- -- --[[
			typ = 45
						
		elseif strType != 91 and code == 91 then
			-- [
			typ = 91
		
		elseif strType == 91 and code == 91 and pos == strStart + 1 then
			-- [[
			typ = 91
		
		elseif strType != 93 and code == 93 then
			-- ]
			typ = 93
		
		elseif strType == 93 and code == 93 and pos == strStart + 1 then
			-- ]]
			typ = 93
			
		
		
		elseif isLineComment or (strType == 45 and pos - strStart >= 2) then
			if code == 10 then
				typ = 10 -- linefeed
			else
				typ = 999
			end

		elseif not isMultiLineComment and not isMultiLineString then
	
			if code == 61 then
				-- = 
				typ = 61				
			
			elseif code == 40 then
				-- (				
				typ = 40
			
			elseif code == 41 then
				-- )				
				typ = 41
			
			elseif code == 123 then
				-- {				
				typ = 123
				
			elseif code == 125 then
				-- }				
				typ = 125
			
			elseif code == 34 then
				-- double quote "
				typ = 34
				isDQuote = true
				ignoreNext = false		
			
			elseif code == 39 then
				-- single quote '
				typ = 39
				isQuote = true
				ignoreNext = false
			
			elseif (strType == -1 or strType > 9) and (code >= 48 and code <= 57) then
				-- numeric start
				typ = 2
				hasDot = false
				isHex = false	
				if strStart == pos - 1 and strType == 46 then
					-- dot before
					strType = 2
					hasDot = true
				end
				
			elseif strType == 2 and code == 120 and pos == strStart + 1 then
				-- hex value
				typ = 2
				isHex = true
				
			elseif strType == 2 and ((code >= 48 and code <= 57) or ( isHex==true and ( (code >=65 and code <= 70) or (code >= 97 and code <=102)   ) ) ) then
				-- numeric
				typ = 2
				
			elseif strType == 2 and not hasDot and code == 46 then
				-- numeric dot
				typ = 2
				hasDot = true
			
			elseif (code >= 48 and code <= 57) or (code >=65 and code <=90) or code == 95 or (code >= 97 and code <= 122) or code >= 128 then
				typ = 1 -- "alphanumeric"
				
			elseif strType == 1 and (code == 46  or code == 58 ) then
				typ = 1 -- blabla.blabla blabla:blabla
				
			elseif code == 46 then
				typ = 46 -- .
				
				
			elseif code == 32 or code == 9 then
				typ = 32 -- space
				
			elseif code == 10 then
				typ = 10 -- linefeed
				
			elseif strType != 45 and code == 45 then
				-- minus
				typ = 45
			
			
			else
				typ = 999  -- control chars
				
			end
		
		else			
			typ = 999 -- control chars
		
		end
		
		if typ != strType then
			if strType != -1 then 				
				local c
				
				if strType == 40 then
					-- (
					for i=strStart, pos - 1 do
						table.insert(braces, 40)
						table.insert(tableName, "")
						indentAfter += 1
					end
					c = _rgb.LuaColorControl
					nextFunctionName = false
					lastVar = nil
				
				elseif strType == 41 then
					-- )
					for i=strStart, pos - 1 do
						if braces[#braces] and braces[#braces] == 40 then
							table.remove(braces)
							table.remove(tableName)
							indentBefore -= 1
						end
					end
					c = _rgb.LuaColorControl
					nextFunctionName = false
					lastVar = nil
					
				elseif strType == 123 then
					-- {
					for i=strStart, pos - 1 do
						table.insert(braces,123)	
						indentAfter += 1
						if lastType == 61 and lastVar then
							local str = tableName[#tableName] or ""
							if str != "" then str ..= "." end			
							table.insert(tableName,str..lastVar)							
						else
							table.insert(tableName,"?")
						end
					end
					c = _rgb.LuaColorControl
					nextFunctionName = false
					lastVar = nil
					
				elseif strType == 125 then
					-- }
					for i=strStart, pos - 1 do
						if braces[#braces] and braces[#braces] == 123 then
							table.remove(braces)
							table.remove(tableName)
							indentBefore -= 1
						end
					end
					c = _rgb.LuaColorControl
					nextFunctionName = false
					lastVar = nil
				
				elseif strType == 34 then
					--dquote
					c = _rgb.LuaColorString 
					nextFunctionName = false
					lastVar = nil
				
				elseif strType == 39 then
					--squote
					c = _rgb.LuaColorString 
					nextFunctionName = false
					lastVar = nil
				
				elseif strType == 2 then
					-- number
					c = _rgb.LuaColorNumber
					nextFunctionName = false
					lastVar = nil
					
				elseif strType == 1 then
					-- alphanumeric
					local str = activePico:LuaSub(strStart, pos - 1)
					c = _wordColor[str] or _rgb.LuaColorVariable
					if str == "function" then
						table.insert(_functions,{nb = #_functions + 1, posStart = strStart, posEnd = pos - 1})
						
						if lastType == 61 and lastVar then
							local tname = tableName[#tableName] or ""
							if tname != "" then tname ..= "." end
							tname = string.rep(" ",#tableName)..tname
							_functions[#_functions].name = tname .. lastVar							
							_functions[#_functions].posStart = lastVarStart
							
							
						elseif lastType == 61 then
							local tname = tableName[#tableName] or ""
							if tname != "" then tname ..= "." end
							tname = string.rep(" ",#tableName)..tname
							_functions[#_functions].name = tname .. "?"	
						
						else
							_functions[#_functions].name = string.rep(" ",#tableName).."()"
							nextFunctionName = true
						end
						
						
						
					else
						if nextFunctionName then
							_functions[#_functions].posEnd = pos - 1
							
							local tname = tableName[#tableName - 1] or "" -- function starts a new tableName
							if tname != "" then tname ..= "." end
							tname = string.rep(" ",#tableName - 1)..tname
							
							_functions[#_functions].name = tname .. str
							
						end
						nextFunctionName = false
					end
					lastVar = str
					lastVarStart = strStart
					
					if _wordIndent[str] then
						indentBefore += _wordIndent[str].before 
						indentAfter +=  _wordIndent[str].after
						indentForceBefore += _wordIndent[str].forceBefore
					end
					
					if _fakeBraces[str] then
					
						if str == "function" then
							table.insert(braces,- #_functions)
							table.insert(tableName, "")
						elseif _fakeBraces[str] == "<" then
							table.insert(braces, 60)
							table.insert(tableName, "")
						else
							if #braces > 0 then
								if braces[#braces] == 60 then
									table.remove(braces)
									table.remove(tableName)
								elseif braces[#braces] < 0 then
									_functions[-braces[#braces]].posTail = pos-1
									table.remove(braces)
									table.remove(tableName)									
								end
							end
						end
					end
					
					
					
				elseif strType == 45 then
					-- - -- --[ --[[
					local str = activePico:LuaSub(strStart, pos - 1)
					if str == "--" or str == "--[" then
						isLineComment = true
						commentstart = strStart
			
					elseif str == "--[["  then
						if not isLineComment and not isMultiLineString then
							isMultiLineComment = true
						end
						multideep += 1
						
						
					else
						c = _rgb.LuaColorControl
					end
					nextFunctionName = false
					lastVar = nil
					
				elseif strType == 91 and pos - strStart == 2 then
				    -- [[
					if not isLineComment and not isMultiLineComment then
						isMultiLineString = true
					end
					multideep += 1
					nextFunctionName = false
					lastVar = nil
					
				elseif strType == 93 and pos - strStart == 2 then
				    -- ]]
					multideep -= 1
										
					if isMultiLineComment then
						c = _rgb.LuaColorComment
					elseif isMultiLineString then
						c = _rgb.LuaColorString 
					else
						c = _rgb.LuaColorControl
					end
					
					if multideep <= 0 then
						isMultiLineComment = false
						isMultiLineString = false
					end
					nextFunctionName = false
					lastVar = nil

				elseif strType == 32 or strType == 61 or strType == 10 then
					c = _rgb.LuaColorControl
					-- spaces, = or lf between function and names are ok!
								
				elseif strType == 999 then
					c = _rgb.LuaColorControl
					nextFunctionName = false
					lastVar = nil

				else
					c = _rgb.LuaColorControl
					nextFunctionName = false
					lastVar = nil
					
				end
				
				if isLineComment or isMultiLineComment then
					c = _rgb.LuaColorComment
					nextFunctionName = false
					lastVar = nil
					
				elseif isMultiLineString then
					c = _rgb.LuaColorString 
					nextFunctionName = false
					lastVar = nil
				end
				
				
				for i = strStart,pos-1 do
					local b = activePico:LuaByte(i)
					_colors[i] = (b == 32 or b== 9) and _rgb.LuaColorMark or c
				end
				
			end
			
			if typ == 10 then
			
				if #_lines > 0 and not indentIgnore and not isLineComment and not isMultiLineCommentthen then
					local x = indentAfter + indentBefore
					if x < 0 then
						_lines[#_lines ].indent = indentCurrent + x + indentForceBefore
					else
						_lines[#_lines ].indent = indentCurrent + indentForceBefore
					end
					
					indentCurrent += x + indentForceBefore
					--indentCurrent += indentAfter + indentBefore
					indentBefore = 0
					indentAfter = 0
					indentForceBefore = 0
					
				end
			
			
				if isLineComment then
					local str = activePico:LuaSub(commentstart, pos - 1)
					if str:sub(1,3) == "-- " and str:sub(-3,-1) == " --" then
						table.insert(_functions,{ nb = #_functions + 1, posStart = commentstart, posEnd = pos - 1, name = str:sub(3,-3):trim(), isComment = true})
					end
				end
			
				-- linefeed
				isLineComment = false
				isQuote = false
				isDQuote = false
			end
			
			if strType != 32 and strType != 10 then
				lastType = strType
			end
			strType = typ
			strStart = pos
		end
		
	end
	
	for i=strStart,activePico:LuaLen() do
		_colors[i] = _rgb.LuaColorControl
	end
	
	for nb = 1,#_lines  do
		_maxLineWidth = math.max(_maxLineWidth, _FontLineWidth(nb))	
	end
	
	
end

-- split "#123456" to a rgba-table
local function _RGBSplit(str)
	return {
		r = tonumber("0x"..str:sub(2,3)) or 0,
		g = tonumber("0x"..str:sub(4,5)) or 0,
		b = tonumber("0x"..str:sub(6,7)) or 0,
		a = 255
	}
end


--===================================================================
-----------------------------------------------------------------Menu
--===================================================================

-- Select the word on the position
local function _SelectWord(newPos)
	local cLine,cOffset = _PosToLineOffset(newPos)
	
	local c = activePico:LuaByte(newPos)
	_cursorPos = newPos + 1
	_cursorPosEnd = newPos
			
	if _ALPHANUMERIC[c] then
		-- cursor is a word
		-- search beginn
		for pos = newPos - 1, _lines[cLine].s, -1 do
			c = activePico:LuaByte(pos,pos)
			if _ALPHANUMERIC[c] then
				_cursorPosEnd = pos
			else
				break
			end
		end
		-- search end
		for pos = newPos +1 , _lines[cLine].e do
			c = activePico:LuaByte(pos,pos)
			if _ALPHANUMERIC[c] then
				_cursorPos = pos + 1
			else
				break
			end
		end
	elseif c == 32 or c == 9 then
		-- cursor is space/tab
		-- search start
		for pos = newPos - 1, _lines[cLine].s, -1 do
			c = activePico:LuaByte(pos,pos)
			if c == 32 or c == 9 then
				_cursorPosEnd = pos
			else
				break
			end
		end
		-- search end
		for pos = newPos +1 , _lines[cLine].e do
			c = activePico:LuaByte(pos,pos)
			if c == 32 or c == 9 then
				_cursorPos = pos + 1
			else
				break
			end
		end
	else
		-- cursor is in control-character
		-- search start
		for pos = newPos - 1, _lines[cLine].s, -1 do
			c = activePico:LuaByte(pos,pos)
			if not (_ALPHANUMERIC[c] or c == 32 or c == 9) then
				_cursorPosEnd = pos
			else
				break
			end
		end
		-- search end
		for pos = newPos +1 , _lines[cLine].e do
			c = activePico:LuaByte(pos,pos)
			if not (_ALPHANUMERIC[c] or c == 32 or c == 9) then
				_cursorPos = pos + 1
			else
				break
			end
		end
	end
end

-- search the function before the cursor position
local function _PreviousFunction()
	local selFn = nil
	local cpos = math.min(_cursorPos, _cursorPosEnd)
	for nb,fn in pairs(_functions) do
		if fn.posStart < cpos then
			selFn = fn
		else
			break
		end
	end
	if selFn then
		-- function found
		_cursorPos = selFn.posEnd + 1
		_cursorPosEnd = selFn.posStart			
	else
		-- cursor on top of tab
		_cursorPos = _activeTab.posStart
		_cursorPosEnd = _cursorPos	
	end
	_VisibleCursor()
end			

-- search the function after the cursor position	
local function _NextFunction()
	local selFn = nil
	for nb,fn in pairs(_functions) do
		if fn.posStart > _cursorPos then
			selFn = fn
			break
		end
	end
	if selFn then
		-- function found
		_cursorPos = selFn.posEnd + 1
		_cursorPosEnd = selFn.posStart
	else
		-- cursor on bottom of tab
		_cursorPos = _activeTab.posEnd
		_cursorPosEnd = _cursorPos	
	end
	_VisibleCursor()
	
end

-- save a lua-block
local _lastfile = ""
local function _SaveBlock()
	if _cursorPos == _cursorPosEnd then return false end
	local s,e = _cursorPos, _cursorPosEnd
	if s>e then s,e = e,s end
	local text = activePico:LuaSub(s,e-1)

	local file = RequestSaveFile(window, "Save block",_lastfile, FILEFILTERLUA)
	if file == nil then return false end
	_lastfile = file

	local path, name, extension = SplitPathFileExtension(file)
	
	local fwrite, err = io.open(file,"wb")
	
	if file == nil then
		SDL.Request.Message(window,TITLE,"Can't save.\n"..err,"OK STOP")
		return false
	end

	fwrite:write( activePico:StringPicoToUTF8(text) )
	fwrite:close()
	
	InfoBoxSet(string.format("Saved %i characters to %s.",#text,name) )
end

-- load a lua-block
local function _LoadBlock()
	local file = RequestOpenFile(window, "Load block", _lastfile, FILEFILTERLUA)
	if file == nil then return false end

	_lastfile = file

	local path, name, extension = SplitPathFileExtension(file)
	
	local fread, err = io.open(file,"rb")
	if fread == nil then
		SDL.Request.Message(window,TITLE,"Can't load.\n"..err,"OK STOP")
		return false
	end
	
	local str = fread:read("a")
	fread:close()
	
	m:Input(str)
	
	InfoBoxSet(string.format("Loaded %i characters from %s.",#str, name) )
	
end

-- open find dialog
local function _FindOpen(doreplace)
	-- Selected text? -> new _find text
	if _cursorPos != _cursorPosEnd then
		local s,e = _cursorPos, _cursorPosEnd
		if s>e then s,e = e,s end
		_findText = activePico:LuaSub(s,e-1)
	end
	-- update text
	_ppLuaFind.inputs.find.text = _findText
	_ppLuaFind.inputs.replace.text = _replaceText
	
	-- resize elements to fit
	_ppLuaFind.inputs.find:Resize(_rectSourceCode.w - _ppLuaFind.buttons.findNext.rectBack.w - _ppLuaFind.buttons.matchWord.rectBack.w - 2)
	_ppLuaFind.inputs.replace:Resize(_rectSourceCode.w - _ppLuaFind.buttons.replace.rectBack.w - _ppLuaFind.buttons.replaceAll.rectBack.w - 2)
	_ppLuaFind.inputs.replace:SetDown(_ppLuaFind.inputs.find,1)
	_ppLuaFind.buttons.matchWord:SetRight(_ppLuaFind.inputs.find,1)
	_ppLuaFind.buttons.findNext:SetRight(1)
	_ppLuaFind.buttons.replaceAll:SetRight(_ppLuaFind.inputs.replace,1)
	_ppLuaFind.buttons.replace:SetRight(1)
	
	-- resize to fit complete
	_ppLuaFind:Resize(0,0) 
	
	-- open dialog
	_ppLuaFind:Open(_rectSourceCode.x, topLimit + m.buttons.tab0.rectBack.h)
	if doreplace then
		-- set cursor to replace-field
		_ppLuaFind.inputs:SetFocus(_ppLuaFind.inputs.replace,true)
	else
		-- or to find-field
		_ppLuaFind.inputs:SetFocus(_ppLuaFind.inputs.find,true)
	end
end

-- find next
local function _FindNext()
	if _findText == nil or _findText == "" then return end
	
	local first = true	
	local oldPos,oldPosEnd = _cursorPos, _cursorPosEnd
	
	while true do 
		local s,e = activePico:LuaFind(_findText,_cursorPos,true)

		if not s and first then
			-- restart at the beginning of the complete source code
			s,e = activePico:LuaFind(_findText,0,true)
			InfoBoxSet("Start search from the beginning.")
			first = false
		end
		
		if s then
			-- found something
			_cursorPosEnd = s
			_cursorPos = e + 1
					
			if math.clamp(_cursorPos, _activeTab.posStart, _activeTab.posEnd) != _cursorPos then
				-- we changed the tab - inform the user
				m:Resize()
				InfoBoxSet("Change tab.")
			end			
			
			-- match word - check
			if _ppLuaFind.buttons.matchWord.selected == false  or (not _ALPHANUMERIC[activePico:LuaByte(s-1)] and not _ALPHANUMERIC[activePico:LuaByte(e+1)]) then
				break
			end
			
		else
			-- not found
			InfoBoxSet("Could not be found.")
			_cursorPos, _cursorPosEnd = oldPos,oldPosEnd
			break
		end
	end
	_VisibleCursor()
end

-- find previous
local function _FindPrevious()
	if _findText == nil or _findText == "" then return end
	
	local s,e = 1,1
	local fs,fe,ls,le
	repeat
		s,e = activePico:LuaFind(_findText,e,true)
		if s and (_ppLuaFind.buttons.matchWord.selected == false  or (not _ALPHANUMERIC[activePico:LuaByte(s-1)] and not _ALPHANUMERIC[activePico:LuaByte(e+1)])) then 
			if s < _cursorPos and s < _cursorPosEnd then
				fs = s
				fe = e
			elseif fs then
				-- we have found a previous, quit
				break
			end
			-- last found position
			ls = s
			le = e				
		end
	until not s 
	
	if fs == nil then
		InfoBoxSet("Start search from end.")
		fs = ls
		fe = le
	end
	
	if fs then
		_cursorPosEnd = fs
		_cursorPos = fe + 1
		if math.clamp(_cursorPos, _activeTab.posStart, _activeTab.posEnd) != _cursorPos then
			m:Resize()
			InfoBoxSet("Change tab.")
		end
		_VisibleCursor()			
			
	else
		InfoBoxSet("Could not be found.")
	end
		
end

-- start a new search
local function _FindStart(text)
	_findText = text	
	_FindNext()
end

-- replace text (if it fit) and find next
local function _Replace()
	if _findText == nil or _findText == "" then return end	
	local ret = false
	-- get text
	local s,e = _cursorPos, _cursorPosEnd
	if s>e then s,e = e,s end
	local text = activePico:LuaSub(s,e-1)
	-- replace?
	if text == _findText then
		m:Input(_replaceText)
		ret = true
	end
	-- next 
	_FindNext()
	return ret
end

-- replace in complete source code
local function _ReplaceAll()
	if _findText == nil or _findText == "" then return end
	
	local oldPos,oldPosEnd = _cursorPos, _cursorPosEnd

	_cursorPos = 0
	
	local s,e
	local count = 0
	while true do
		-- search
		s,e = activePico:LuaFind(_findText,_cursorPos,true)
		if not s then break end
		-- set cursor
		_cursorPosEnd = s
		_cursorPos = e + 1
		-- matchWord- handling
		if _ppLuaFind.buttons.matchWord.selected == false or (not _ALPHANUMERIC[activePico:LuaByte(s-1)] and not _ALPHANUMERIC[activePico:LuaByte(e+1)]) then
			-- replace text
			oldPos,oldPosEnd = _cursorPos, _cursorPosEnd
			m:Input(_replaceText) -- not ideal, because everytime a resize is called
			count += 1
		end
	end
	-- inform the user
	InfoBoxSet("Replaced " .. count .. " times.")		
	-- set cursor to last replaced text
	_cursorPos, _cursorPosEnd = oldPos,oldPosEnd
	_VisibleCursor()
end

-- open goto dialog
local function _GotoOpen()
	local line = _PosToLineOffset(_cursorPos)
	-- update values
	_ppLuaGoto.inputs.line.text = tostring(line)
	_ppLuaGoto.inputs.line.min = 1
	_ppLuaGoto.inputs.line.max = #_lines			
	-- resize elements
	_ppLuaGoto.inputs.line:Resize(_rectSourceCode.w)	
	_ppLuaGoto:Resize(0,0)
	-- open dialog
	_ppLuaGoto:Open(_rectSourceCode.x, topLimit + m.buttons.tab0.rectBack.h)
	_ppLuaGoto.inputs:SetFocus(_ppLuaGoto.inputs.line,true)
end

-- goto line number
local function _GotoStart(text)
	local line = tonumber(text)
	if line then
		_cursorPos = _LineOffsetToPos(line \ 1, 1)
		_cursorPosEnd = _cursorPos
		_VisibleCursor()
	end
end


--===================================================================
-----------------------------------------------------------------main
--===================================================================

-- custom menu
local _mFont
local function _MenuZoomSet(e)
	config.LuaZoom = math.clamp(1,6,e.index or 4)
	e:SetRadio()
	_FontChoose()
	m:Resize()
end

local function _MenuInit()
	m.menuBar = menu:CreateBar()
	
	m.menuBar:AddFile()
	local men = m.menuBar:AddEdit()
	men:Add()
	men:Add("luaSelectNext", "Duplicate line \t ctrl+d", function ()
			local line,offset = _PosToLineOffset(_cursorPos)
			local str = activePico:LuaSub(_lines[line].s, _lines[line].e)
			activePico:LuaReplace(_lines[line].e, _lines[line].e, str)
			activePico:LuaSetUndoCursor(_cursorPos, _cursorPosEnd )
			m:Resize()
			_VisibleCursor()
		end,
		"CTRL+D"
	)
	men:Add("luaLowerCase", "Convert to lower case \t ctrl+u", function()		
			if _cursorPos != _cursorPosEnd then
				local s,e = _cursorPos, _cursorPosEnd
				if s>e then s,e = e,s end
				local str = activePico:StringPicoToUTF8(activePico:LuaSub(s,e-1))
				m:Input(str:upper()) -- reversed in pico-8
				_cursorPos = e
				_cursorPosEnd = s 
				_VisibleCursor()
				
			end
		end,
		"CTRL+U"
	)
	men:Add("luaUpperCase", "Convert to UPPER CASE \t shift+ctrl+u", function()		
			if _cursorPos != _cursorPosEnd then
				local s,e = _cursorPos, _cursorPosEnd
				if s>e then s,e = e,s end
				local str = activePico:StringPicoToUTF8(activePico:LuaSub(s,e-1))
				m:Input(str:lower()) -- reversed in pico-8
				_cursorPos = e
				_cursorPosEnd = s 
				_VisibleCursor()
			end
		end,
		"SHIFT+CTRL+U"
	)
	men:Add("luaComment", "Insert/remove comment \t ctrl+b", function()	
			if _cursorPos != _cursorPosEnd then
				activePico:LuaSetUndoCursor(_cursorPos, _cursorPosEnd )
		
				local line1 = _PosToLineOffset(_cursorPos)
				local line2 = _PosToLineOffset(_cursorPosEnd)
				if line1 > line2 then line1,line2 = line2,line1 end
				
				for nb = line2, line1, -1 do
					local line = _lines[nb]
					if activePico:LuaSub(line.s, line.s + 1) == "--" then
						if _cursorPos > line.s then
							_cursorPos -= 2
						end
						if _cursorPosEnd > line.s then
							_cursorPosEnd -= 2
						end
						activePico:LuaReplace(line.s - 1, line.s +1,"")
					else
						if _cursorPos > line.s then
							_cursorPos += 2
						end
						if _cursorPosEnd > line.s then
							_cursorPosEnd += 2
						end
						activePico:LuaReplace(line.s - 1, line.s -1,"--")
					end
				end
				
				m:Resize()
			end
		end,
		"CTRL+B"
	)
	men:Add("luaIndent", "Automatic indent document \t ctrl+i",function()	
			activePico:LuaSetUndoCursor(_cursorPos, _cursorPosEnd )
			for nb = #_lines,1,-1 do
				local line = _lines[nb]
				if line.indent >= 0 then
				
					local s,e = line.s - 1, line.s - 1
					
					for nb,code in activePico:LuaCodes(line.s, line.e) do
						if code == 32 or code == 9 then
							e+=1
						else
							break
						end
					end
					
					if (e-s) != line.indent then
						if _cursorPos > s then
							_cursorPos += -(e-s) + line.indent
						end
						if _cursorPosEnd > s then
							_cursorPosEnd += -(e-s) + line.indent
						end
						activePico:LuaReplace(s,e,string.rep(" ",line.indent))									
					end
				end				
							
			end			
			m:Resize()
		end,
		"CTRL+I"
	)
	men:Add("luaTab", "Increase indent \t tab", function()
		if _cursorPos != _cursorPosEnd then
			local line1 = _PosToLineOffset(_cursorPos)
			local line2 = _PosToLineOffset(_cursorPosEnd)
			if line1 < line2 then line1,line2 = line2,line1 end
			activePico:LuaSetUndoCursor(_cursorPos, _cursorPosEnd )
			for nb = line1,line2,-1 do
				activePico:LuaReplace(_lines[nb].s - 1, _lines[nb].s - 1, "\t")
				if _cursorPos >  _lines[nb].s then _cursorPos += 1 end
				if _cursorPosEnd > _lines[nb].s then _cursorPosEnd += 1 end
			end
			m:Resize()
		else
			m:Input("\t")
		end
	end, "TAB")
	men:Add("luaShiftTab", "Decrease indent \t shift+tab", function()
		if _cursorPos != _cursorPosEnd then
			local line1 = _PosToLineOffset(_cursorPos)
			local line2 = _PosToLineOffset(_cursorPosEnd)
			if line1 < line2 then line1,line2 = line2,line1 end
			activePico:LuaSetUndoCursor(_cursorPos, _cursorPosEnd )
			for nb = line1,line2,-1 do
				local b = activePico:LuaByte(_lines[nb].s)
				if b == 32 or b == 9 then
					activePico:LuaReplace(_lines[nb].s - 1, _lines[nb].s, "")
					if _cursorPos >  _lines[nb].s then _cursorPos -= 1 end
					if _cursorPosEnd > _lines[nb].s then _cursorPosEnd -= 1 end
				end				
			end
			m:Resize()
		else
			m:Input("\t")
		end
	end, "SHIFT+TAB")
	men:Add()
	men:Add("luaSaveBlock", "Save block", _SaveBlock,nil)
	men:Add("luaLoadBlock", "Load block", _LoadBlock,nil)
	
	men:Add()
	men:Add("luaPuny", "Puny mode \t ctrl+p",function(e)
		_puny = e.checked
	end, "CTRL+P","TOOGLE")
	
		
	local mSearch = m.menuBar:Add("Search")
	mSearch:Add("luaFind", "Find \t ctrl+f", function() _FindOpen() end, "CTRL+F")
	
	mSearch:Add("luaNext", "Find next \t F3", _FindNext, "F3")
	mSearch:Add("luaPrevious", "Find previous \t shift+F3", _FindPrevious,"SHIFT+F3")
	mSearch:Add("luaSelectNext", "Select and find next \t ctrl+F3", function ()
			if _cursorPos == _cursorPosEnd then
				_SelectWord(_cursorPos)
			end
			local s,e = _cursorPos, _cursorPosEnd
			if s>e then s,e = e,s end
			_findText = activePico:LuaSub(s,e-1)
			_FindNext()	
		end,
		"CTRL+F3"
	)
	mSearch:Add("luaSelectPrevious", "Select and find previous \t shift+ctrl+F3", function ()
			if _cursorPos == _cursorPosEnd then
				_SelectWord(_cursorPos)
			end
			local s,e = _cursorPos, _cursorPosEnd
			if s>e then s,e = e,s end
			_findText = activePico:LuaSub(s,e-1)
			_FindPrevious()	
		end,
		"SHIFT+CTRL+F3"
	)
	mSearch:Add("luaReplace", "Replace \t ctrl+h", function() _FindOpen(true) end, "CTRL+H")
	mSearch:Add("luamark", "Mark \t ctrl+m", function() _SelectWord(_cursorPos) end, "CTRL+M")
	mSearch:Add()
	mSearch:Add("luaLine", "Go to line \t ctrl+g", _GotoOpen, "CTRL+G")
	mSearch:Add()
	mSearch:Add("luaNextFN", "Next function \t ctrl+down", _NextFunction, "CTRL+DOWN")
	mSearch:Add("luaPrevFN", "Previous function \t ctrl+up", _PreviousFunction, "CTRL+UP")
	
	m.menuBar:AddPico8()
	
	_mFont = m.menuBar:Add("Zoom")
	_mFont:Add("LuaFontCustom","Use custom font",
		function(e)
			config.LuaFontCustom = e.checked
			
			_FontChoose()
			m:Resize()
		end,
		nil,
		"TOOGLE"
	)
	_mFont:Add()
	for i = 1,6 do
		local e = _mFont:Add("luaZoom"..i, tostring(i), _MenuZoomSet,nil,"font")
		e.index = i
	end
	
	local ViewChange = function(str)
		-- activate Button
		for nb,b in pairs(m.buttons) do
			if b.index == str then
				b:OnClick(b)
				m.buttons:SetRadio(b)
				break
			end
		end
		
	end
	
	_mView = m.menuBar:Add("View")
	_mView:Add("luaViewfunction","Functions\t shift+ctrl+1",function() ViewChange("function") end,"CTRL+SHIFT+1")
	_mView:Add("luaViewsprite","Sprites\t shift+ctrl+2",function() ViewChange("sprite") end,"CTRL+SHIFT+2")
	_mView:Add("luaViewcharset","Font\t shift+ctrl+3",function() ViewChange("charset") end,"CTRL+SHIFT+3")
	_mView:Add("luaViewsound","Sound\t shift+ctrl+4",function() ViewChange("sound") end,"CTRL+SHIFT+4")
	_mView:Add("luaViewmusic","Music\t shift+ctrl+5",function() ViewChange("music") end,"CTRL+SHIFT+5")
	_mView:Add("luaViewpalette","Palette\t shift+ctrl+6",function() ViewChange("palette") end,"CTRL+SHIFT+6")
			
	m.menuBar:AddSettings()
	m.menuBar:AddModule()
	m.menuBar:AddDebug()
	
	m.MenuUpdate = function (m,bar)
		bar:Set("luaPuny", _puny)	
		bar:Set("LuaFontCustom", config.LuaFontCustom)
		bar:Set("luaZoom".. config.LuaZoom )
		bar:Set("luaView".._leftSideMode)
	end
	
end

-- initalize everything
function m.Init(m)
	m.buttons = buttons:CreateContainer()
	m.scrollbar = scrollbar:CreateContainer()
	
	_MenuInit()	
	
	-- add some scrollbars
	m.scrollbar:Add("x",1,1,true,1,1,1)
	m.scrollbar:Add("y",1,1,false,1,1,1)
	m.scrollbar:Add("fnY",1,1,false,1,1,1)
	
	local b	
	
	-- switch left side info
	local ls_update = function(but)
		_leftSideMode = but.index
		PicoRemoteSFX(-1)
		PicoRemoteMusic(-1)
		m.menuBar:Set("luaView".._leftSideMode)
	end
	
	-- left side buttons
	b = m.buttons:Add("ls_functions","Functions",nil,nil,"leftSide")
	b.index = "function"
	b.shrinkOnDeselected = true
	b.OnClick = ls_update
	
	b = m.buttons:Add("ls_sprites", "Sprites",nil,nil, "leftSide")
	b.index = "sprite"
	b.shrinkOnDeselected = true
	b.OnClick = ls_update
	
	b = m.buttons:Add("ls_charset", "Font",nil,nil, "leftSide")
	b.index = "charset"
	b.shrinkOnDeselected = true
	b.OnClick = ls_update
	
	b = m.buttons:Add("ls_sound", "Sound",nil,nil, "leftSide")
	b.index = "sound"
	b.shrinkOnDeselected = true
	b.OnClick = ls_update
	
	b = m.buttons:Add("ls_music", "Music",nil,nil, "leftSide")
	b.index = "music"
	b.shrinkOnDeselected = true
	b.OnClick = ls_update
	
	b = m.buttons:Add("ls_palette", "Palette",nil,nil, "leftSide")
	b.index = "palette"
	b.shrinkOnDeselected = true
	b.OnClick = ls_update
	
	m.buttons:SetRadio(m.buttons.ls_functions)
	
	-- sourcecode tab buttons	
	local tabSelected = function(but)
		-- save some values
		activePico.userdata_luaTabs = activePico.userdata_luaTabs or {}	
		activePico.userdata_luaTabs[_activeTab.index] = {
			cursorPos = _cursorPos - _activeTab.posStart,
			cursorPosEnd = _cursorPosEnd - _activeTab.posStart,
			barY = m.scrollbar.y:GetValues(),
			barX = m.scrollbar.x:GetValues()
		}

		-- select a tab
		local tab = _tabs[math.clamp(1,#_tabs,but.index + 1)]
		-- restore values
		local data = activePico.userdata_luaTabs[tab.index] or {cursorPos = 0, cursorPosEnd = 0}
		_cursorPos = math.clamp(data.cursorPos + tab.posStart, tab.posStart, tab.posEnd)
		_cursorPosEnd = math.clamp(data.cursorPosEnd + tab.posStart, tab.posStart, tab.posEnd)
		-- resize to recolor code
		m:Resize()
		-- update scrollbars
		m.scrollbar.y:SetValues(data.barY or 0)
		m.scrollbar.x:SetValues(data.barX or 0)				
	end
	
	for i = 0, 0xf do
		b = m.buttons:Add("tab"..i, string.format("%x",i), nil, nil, "tabs")
		b.index = i
		b.shrinkOnDeselected = true
		b.OnClick = tabSelected
	end
	
	b = m.buttons:Add("tabAdd","+")
	b.OnClick = function(but)
		if #_tabs < 15 then
			-- store some values
			activePico.userdata_luaTabs = activePico.userdata_luaTabs or {}		
			activePico.userdata_luaTabs[_activeTab.index] = {
				cursorPos = _cursorPos - _activeTab.posStart,
				cursorPosEnd = _cursorPosEnd - _activeTab.posStart,
				barY = m.scrollbar.y:GetValues(),
				barX = m.scrollbar.x:GetValues()
			}
			-- insert a new tab
			activePico:LuaReplace( activePico:LuaLen(),activePico:LuaLen(),"-->8\n\n")			
			activePico:LuaSetUndoCursor(_cursorPos, _cursorPosEnd )
			-- set cursor to end
			_cursorPos = activePico:LuaLen()
			_cursorPosEnd = _cursorPos
			-- update module
			m:Resize()
		end
	end
	
	-- default colors
	config.LuaColorBack = config.LuaColorBack or "#2A211C"
	config.LuaColorControl = config.LuaColorControl or "#FFAA00"
	config.LuaColorKeyword = config.LuaColorKeyword or "#F6F080"
	config.LuaColorString = config.LuaColorString or "#55E439"
	config.LuaColorNumber = config.LuaColorNumber or "#FF3A83"
	config.LuaColorComment = config.LuaColorComment or "#1E9AE0"
	config.LuaColorVariable = config.LuaColorVariable or "#BDAE9D"
	config.LuaColorPico = config.LuaColorPico or "#EDAECD"
	config.LuaColorMark = config.LuaColorMark or "#83675A"
	config.LuaColorCursor = config.LuaColorCursor or "#37A8ED"
	config.LuaColorHighlightLine = config.LuaColorHighlightLine or "#4B3C34"
	config.LuaColorLinenumberBack = config.LuaColorLinenumberBack or "#4C4A41"
	config.LuaColorLinenumber = config.LuaColorLinenumber or "#E5C138"
	config.LuaColorMarkWord = config.LuaColorMarkWord or "#7E2553"
	config.LuaColorMarkBrace = config.LuaColorMarkBrace or "#00FFFF"
	config.LuaColorMarkBadBrace = config.LuaColorMarkBadBrace or "#FF0000"
	
	if config.LuaFontCustom == nil then config.LuaFontCustom = true end
	config.LuaZoom = config.LuaZoom or 4
	
	-- comments for the config
	configComment.LuaColorBack = "Background color of the source code"
	configComment.LuaColorControl = "Color for all non-alphanumeric"
	configComment.LuaColorKeyword = "Color for all lua keywords"
	configComment.LuaColorString = "Color for strings"
	configComment.LuaColorNumber = "Color for numbers"
	configComment.LuaColorComment = "Color for comments"
	configComment.LuaColorVariable = "Color for functions/variables"
	configComment.LuaColorPico = "Color for pico-8 functions/variables"
	configComment.LuaColorMark = "Background color for marked text"
	configComment.LuaColorCursor = "Color of the cursor"
	configComment.LuaColorHighlightLine = "Background color of the current line"
	configComment.LuaColorLinenumberBack = "Background color for the line numbers"
	configComment.LuaColorLinenumber = "Color for the line numbers"
	configComment.LuaColorMarkWord = "Color for selected words"
	configComment.LuaColorMarkBrace = "Color of the matching brace"
	configComment.LuaColorMarkBadBrace = "Color for a missing brace"
	
	configComment.LuaFontCustom = "Use custom font in lua editor"
	configComment.LuaZoom = "Zoom level for text in lua editor"
	
	-- generate _rgb table
	for key,value in pairs(config) do
		if key:sub(1,8) == "LuaColor" then
			_rgb[key] = _RGBSplit(value)
		end
	end

	-- color for some special words	
	 _wordColor ={
	 -- lua keywords
	["function"] = _rgb.LuaColorKeyword, ["end"] = _rgb.LuaColorKeyword, ["for"] = _rgb.LuaColorKeyword, ["do"] = _rgb.LuaColorKeyword, 
	["while"] = _rgb.LuaColorKeyword, ["if"] = _rgb.LuaColorKeyword, ["then"] = _rgb.LuaColorKeyword, ["and"] = _rgb.LuaColorKeyword, 
	["or"] = _rgb.LuaColorKeyword, ["not"] = _rgb.LuaColorKeyword, ["return"] = _rgb.LuaColorKeyword, ["local"] = _rgb.LuaColorKeyword,
	["break"] = _rgb.LuaColorKeyword, ["goto"] = _rgb.LuaColorKeyword, ["repeat"] = _rgb.LuaColorKeyword, ["until"] = _rgb.LuaColorKeyword,
	["elseif"] = _rgb.LuaColorKeyword, ["in"] = _rgb.LuaColorKeyword, ["nil"] = _rgb.LuaColorKeyword, ["true"] = _rgb.LuaColorKeyword, 
	["false"] = _rgb.LuaColorKeyword, ["else"] = _rgb.LuaColorKeyword,
	-- pico8 build in functions
	assert = _rgb.LuaColorPico, run = _rgb.LuaColorPico, reset = _rgb.LuaColorPico, flip = _rgb.LuaColorPico, printh = _rgb.LuaColorPico,
	time = _rgb.LuaColorPico, stat = _rgb.LuaColorPico, extcmd = _rgb.LuaColorPico, sfx = _rgb.LuaColorPico, music = _rgb.LuaColorPico, 
	mget = _rgb.LuaColorPico, mset = _rgb.LuaColorPico, map = _rgb.LuaColorPico, tline = _rgb.LuaColorPico,	peek = _rgb.LuaColorPico, 
	poke = _rgb.LuaColorPico, peek2 = _rgb.LuaColorPico, poke2 = _rgb.LuaColorPico, peek4 = _rgb.LuaColorPico, poke4 = _rgb.LuaColorPico, 
	memcpy = _rgb.LuaColorPico, reload = _rgb.LuaColorPico, cstore = _rgb.LuaColorPico, memset = _rgb.LuaColorPico, max = _rgb.LuaColorPico, 
	min = _rgb.LuaColorPico, mid = _rgb.LuaColorPico, flr = _rgb.LuaColorPico, ceil = _rgb.LuaColorPico, cos = _rgb.LuaColorPico, 
	sin = _rgb.LuaColorPico, atan2 = _rgb.LuaColorPico, sqrt = _rgb.LuaColorPico, abs = _rgb.LuaColorPico, rnd = _rgb.LuaColorPico, 
	srnd = _rgb.LuaColorPico, color = _rgb.LuaColorPico, clip = _rgb.LuaColorPico, pset = _rgb.LuaColorPico, pget = _rgb.LuaColorPico, 
	sset = _rgb.LuaColorPico, sget = _rgb.LuaColorPico, print = _rgb.LuaColorPico, cursor = _rgb.LuaColorPico, cls = _rgb.LuaColorPico, 
	camera = _rgb.LuaColorPico, circ = _rgb.LuaColorPico, circfill = _rgb.LuaColorPico, oval = _rgb.LuaColorPico, ovalfill = _rgb.LuaColorPico, 
	line = _rgb.LuaColorPico, rect = _rgb.LuaColorPico, rectfill = _rgb.LuaColorPico, pal = _rgb.LuaColorPico, palt = _rgb.LuaColorPico, 
	spr = _rgb.LuaColorPico, sspr = _rgb.LuaColorPico, fillp = _rgb.LuaColorPico, add = _rgb.LuaColorPico, del = _rgb.LuaColorPico, 
	deli = _rgb.LuaColorPico, count = _rgb.LuaColorPico, all = _rgb.LuaColorPico, foreach = _rgb.LuaColorPico, pairs = _rgb.LuaColorPico,
	btn = _rgb.LuaColorPico, btnp = _rgb.LuaColorPico, band = _rgb.LuaColorPico, bor = _rgb.LuaColorPico, bxor = _rgb.LuaColorPico, 
	bnot = _rgb.LuaColorPico, shl = _rgb.LuaColorPico, shr = _rgb.LuaColorPico, lshr = _rgb.LuaColorPico, rotl = _rgb.LuaColorPico, 
	rotr = _rgb.LuaColorPico, menuitem = _rgb.LuaColorPico, tostr = _rgb.LuaColorPico, tonum = _rgb.LuaColorPico, chr = _rgb.LuaColorPico, 
	ord = _rgb.LuaColorPico, sub = _rgb.LuaColorPico, split = _rgb.LuaColorPico, type = _rgb.LuaColorPico, cartdata = _rgb.LuaColorPico, 
	dget = _rgb.LuaColorPico, dset = _rgb.LuaColorPico,	
	}
	
	-- find dialog
	_ppLuaFind = popup:Add("luaSearch",0,0)
	
	local inp = _ppLuaFind.inputs:Add("find", "Find:   ", "<search>")
	inp.OnTextChange = function (inp,text)
		_findText = text
	end
	inp.OnReturn = function(inp, text)
		_FindStart(text)
		_ppLuaFind:Close()
	end
	
	inp =_ppLuaFind.inputs:Add("replace",     "Replace:", "<replace>")
	inp.OnTextChange = function(inp,text)
		_replaceText = text
	end
	inp.OnReturn = function (inp,text)
		_replaceText = text
		_Replace()
		_ppLuaFind.inputs:SetFocus(_ppLuaFind.inputs.replace,true)
	end
	
	-- set tab-destination
	_ppLuaFind.inputs.find.tab = _ppLuaFind.inputs.replace
	_ppLuaFind.inputs.replace.tab = _ppLuaFind.inputs.find
	
	local b = _ppLuaFind.buttons:Add("findNext","Find next",100)
	b.OnClick = _FindNext
	
	b = _ppLuaFind.buttons:Add("replace","Replace",100)
	b.OnClick = _Replace	
	
	b = _ppLuaFind.buttons:Add("replaceAll","Replace all",100)
	b.OnClick = _ReplaceAll
	
	b = _ppLuaFind.buttons:Add("matchWord","Match Word",100,nil,"TOOGLE")
	
	-- goto dialog
	_ppLuaGoto = popup:Add("luaGoto",0,0)
	local inp = _ppLuaGoto.inputs:Add("line","Line:","<lnb>")
	inp.OnTextChange = function (inp,text)
		_GotoStart(text)
		_ppLuaGoto:Close()
	end
	
	_FontInit()
	
	return true
end

-- free resources
function m.Quit(m)
	m.scrollbar:DestroyContainer()
	m.buttons:DestroyContainer()
	popup:Remove(_ppLuaFind)
	popup:Remove(_ppLuaGoto)
	m.menuBar:Destroy()	
end

-- got focus
function m.FocusGained(m)
	-- restored some values
	_cursorPos = activePico.userdata_lua_cursorPos or 1
	_cursorPosEnd = activePico.userdata_lua_cursorPosEnd or 1
	m.scrollbar.y:SetValues(activePico.userdata_lua_line or 0)
	m.scrollbar.x:SetValues(activePico.userdata_lua_xoffset or 0)
	
	_FontChoose()
end

-- lost focus
function m.FocusLost(m)
	-- save some values
	activePico.userdata_lua_cursorPos = _cursorPos
	activePico.userdata_lua_cursorPosEnd = _cursorPosEnd
	activePico.userdata_lua_line = m.scrollbar.y:GetValues()
	activePico.userdata_lua_xoffset = m.scrollbar.x:GetValues()
	PicoRemoteSFX(-1)
	PicoRemoteMusic(-1)
end

-- resize
function m.Resize(m)
	local ow, oh = renderer:GetOutputSize()
	local w1,h1 = SizeText("+")
		
	_rightSide = 5 + _128Size * 16 + 5, topLimit + 5
	
	-- position left side buttons
	m.buttons.ls_functions:SetPos(5,topLimit)
	m.buttons.ls_sprites:SetRight(1)
	m.buttons.ls_charset:SetRight(1)
	m.buttons.ls_sound:SetRight(1)
	m.buttons.ls_music:SetRight(1)
	m.buttons.ls_palette:SetRight(1)
	
	-- left side rects
	_rect128x128 = {x = 5, y = topLimit + m.buttons.tab0.rectBack.h + 5, w = 16 * _128Size, h = 16 * _128Size}
	_rectLSInfo = {x = 5, y = _rect128x128.y + _rect128x128.h + 5, w = _rect128x128.w, h = h1 + 10}
	
	-- hide all tabs
	for i =0,15 do
		m.buttons["tab"..i].visible = false
	end
	
	-- function list
	_rectFunctions = {x = 5, y = topLimit + m.buttons.tab0.rectBack.h + 5}
	_rectFunctions.w = _rightSide - 5 - _rectFunctions.x - BARSIZE - 5
	_rectFunctions.h = oh - _rectFunctions.y - 5 - h1 - 5
			
	-- rect where the source code is displayed (seperated in text and linenumber)
	_rectSourceCode= { x = _rightSide, y = topLimit + m.buttons.tab0.rectBack.h + 5 }
	_rectSourceCode.w = ow - _rectSourceCode.x - 5 - BARSIZE - 5
	_rectSourceCode.h = oh - _rectSourceCode.y - 5 - BARSIZE - 5 - h1 - 5

	-- infobar
	_rectInfobar = {x = _rectSourceCode.x, y = _rectSourceCode.y + _rectSourceCode.h + 5 + BARSIZE + 5 , _rectSourceCode.w, h1}

	-- place scrolbars
	m.scrollbar.x:SetPos(_rectSourceCode.x, _rectSourceCode.y + _rectSourceCode.h + 5, _rectSourceCode.w, BARSIZE)
	m.scrollbar.y:SetPos(_rectSourceCode.x + _rectSourceCode.w + 5, _rectSourceCode.y, BARSIZE, _rectSourceCode.h)
	m.scrollbar.fnY:SetPos(_rectFunctions.x + _rectFunctions.w + 5, _rectFunctions.y, BARSIZE, _rectFunctions.h)
	
	-- search tabs and update tabs
	_ScanForTabs()	
	
	-- colorize tab
	_ColorizeCode()

	-- line number
	local count = #tostring(#_lines)
	_rectNumber = {x = _rectSourceCode.x, y = _rectSourceCode.y, w = _FontNumberWidth() * count + 10, h = _rectSourceCode.h}
	
	-- text	
	_rectText = { x = _rectNumber.x + _rectNumber.w, y = _rectNumber.y }
	_rectText.w = _rectSourceCode.w - (_rectText.x - _rectSourceCode.x)
	_rectText.h = _rectSourceCode.h - (_rectText.y - _rectSourceCode.y)
	
	-- update scrollbars
	m.scrollbar.y:SetValues(nil, _rectSourceCode.h \ _FontHeight(), #_lines)	
	m.scrollbar.x:SetValues(nil, _rectSourceCode.w  - _rectNumber.w, _maxLineWidth)
	m.scrollbar.fnY:SetValues(nil, _rectFunctions.h \ _FontHeight(), #_functions)	
	
	-- build a list with all used sfx	
	_sfxUsedIn = {}
	for i = 0, 63 do
		_sfxUsedIn[i] = {}
	end
	for i=0,63 do
		local t = activePico:MusicGet(i)
		for a = 1, 4 do
			if not t.disabled[a] then 
				table.insert(_sfxUsedIn[t.sfx[a]], i) 
			end
		end
		local tex = TexturesGetSFX(i) -- calculate dominate wave form
	end
	
	-- Search function on cursor position
	_UpdateFunctionSelection(true)
end

-- drawing module
local _PALETTENAMES = { "Custom palette", "Default palette", "Extended palette" }
local _oldCLine, _oldCOffset
function m.Draw(m)
	--m.Resize(m) -- debug hardcore test!
	m.scrollbar.fnY.visible = (_leftSideMode == "function")
	_leftSideSFX = nil
	_leftSideMusic = nil	

	-- get size	
	local ow, oh = renderer:GetOutputSize()
	local leftSideInfo
	
	if _leftSideMode == "function" then
		-- functionlist
		_UpdateFunctionSelection()
		
		-- draw background
		DrawBorder(_rectFunctions.x, _rectFunctions.y, _rectFunctions.w, _rectFunctions.h, Pico.RGB[5])
		DrawFilledRect(_rectFunctions,_rgb.LuaColorBack,nil,true)
						
		local line, pageHeight = m.scrollbar.fnY:GetValues()
		local yy = _rectFunctions.y
				
		-- draw list
		renderer:SetClipRect( _rectFunctions )

		for i = line + 1, line + pageHeight + 1 do
			local fn = _functions[i]
			if fn then
				-- choose a color
				local col = fn.isComment and _rgb.LuaColorComment or _rgb.LuaColorVariable
				if fn.name and fn.name:sub(-2) == "()" then
					col = _rgb.LuaColorControl
				end
				
				local xx = _rectFunctions.x + 5
				
				-- selection background
				if fn == _functionSelected then
					DrawFilledRect({_rectFunctions.x, yy, _rectFunctions.w, _FontHeight()}, _rgb.LuaColorHighlightLine)
				end			
				
				-- draw name
				if fn.name then
					_FontDraw(xx,yy,fn.name,col)
				end
			end
			yy += _FontHeight()
		end
		renderer:SetClipRect( nil )
		
	elseif _leftSideMode == "sprite" or _leftSideMode == "charset" then
		-- draw sprite or charset
		local tex = (_leftSideMode == "sprite") and TexturesGetSprite() or TexturesGetCharset()
		
		if _leftSideMode == "charset" then
			tex:SetColorMod(Pico.RGB[7].r,Pico.RGB[7].g,Pico.RGB[7].b)
			tex:SetBlendMode("BLEND")
			DrawFilledRect(_rect128x128,COLBLACK,nil,true)
		else
			tex:SetBlendMode("NONE")
		end
		
		-- draw texture and border
		renderer:Copy(tex,nil,_rect128x128)
		DrawBorder(_rect128x128.x,_rect128x128.y,_rect128x128.w,_rect128x128.h, Pico.RGB[5])
		
		-- draw a grid
		renderer:SetClipRect(_rect128x128)
		for x = _rect128x128.x-1, _rect128x128.x + _rect128x128.w, _128Size do
			DrawFilledRect({x, _rect128x128.y, 1, _rect128x128.h}, COLGREY)
		end
		for y = _rect128x128.y-1, _rect128x128.y + _rect128x128.h, _128Size do
			DrawFilledRect({_rect128x128.x, y, _rect128x128.w, 1}, COLGREY)
		end
		renderer:SetClipRect( nil )
		
		-- if the user select a value, draw a border around it
		if _cursorPos != _cursorPosEnd then
			local s,e = _cursorPos, _cursorPosEnd
			if s>e then s,e = e,s end
			local nb = tonumber(activePico:LuaSub(s,e-1))
			if nb and nb >= 0 and nb <= 255 and nb \ 1 == nb then
				leftSideInfo = nb
				local x = nb & 0xf
				local y = (nb >> 4) & 0xf
				DrawBorder(_rect128x128.x + x * _128Size, _rect128x128.y + y * _128Size, _128Size, _128Size, COLWHITE)
			end
			
		elseif SDL.Rect.ContainsPoint(_rect128x128, {mx, my}) then
			-- if not - is the mouse cursor inside? 
			leftSideInfo = (mx - _rect128x128.x) \ _128Size + ( (my - _rect128x128.y) \ _128Size << 4)		
		end
		
		-- draw additional infos about selected/highlighted sprite/character
		if leftSideInfo then
			local w1,h1 = SizeText("+")
			local x,y = leftSideInfo & 0xf, (leftSideInfo >> 4) & 0xf
			local xx,yy = _rectLSInfo.x, _rectLSInfo.y + 5
			
			xx = DrawText(xx,yy,string.format("id: 0x%02x - %03i ",leftSideInfo,leftSideInfo),COLDARKWHITE)
			renderer:Copy(tex, {x * 8, y * 8, 8, 8}, {xx, yy - 5, _rectLSInfo.h, _rectLSInfo.h})
			xx += _rectLSInfo.h + w1 
			
			if _leftSideMode == "sprite" then
				-- dummy sprite flags
				for i=0,7 do 
					if activePico:SpriteFlagGet( leftSideInfo, i) then
						DrawFilledRect({xx, yy - 5, w1 + 10, h1 + 10}, Pico.RGB[i+8])
						xx = DrawText(xx + 5, yy, i, COLBLACK) + 5 + 1
						
					else
						DrawFilledRect({xx, yy - 5, w1 + 10, h1 + 10}, COLDARKGREY)
						xx = DrawText(xx + 5, yy, i, Pico.RGB[i+8]) + 5 + 1 
					end
				end	
			else
				-- character name
				xx = DrawText(xx,yy,activePico.CHARNAME[leftSideInfo],COLDARKWHITE)
			end
		end
		
	elseif _leftSideMode == "palette" then
		-- palette
		local w1,h1 = SizeText("+")
		local w2,h2 = SizeText("+",2)
		local ww = _128SizeBig * 2 + h2
		local space = (_rect128x128.h - ww * 3)\2 + ww
		
		-- draw background
		DrawBorder(_rect128x128.x, _rect128x128.y, _rect128x128.w, _rect128x128.h, Pico.RGB[5])
		DrawFilledRect(_rect128x128,COLBLACK)
		
		-- draw 3 palettes - custom, default, extended		
		for p =0, 2 do
			local xx, yy = _rect128x128.x, _rect128x128.y + p * space
			local str = _PALETTENAMES[p+1]
			
			-- draw name
			_,yy = DrawText(xx, yy, str, COLDARKWHITE, 2)
			-- draw colors
			for i = 0,15 do
				local rect = {x = xx + _128SizeBig * (i % 8), y = yy + _128SizeBig * (i \ 8), w = _128SizeBig, h = _128SizeBig}
				local col
				if p == 0 then
					-- from user changed palette
					col = activePico:PaletteGetRGB(i)
					str = string.format("%02i",i)
				elseif p == 1 then
					-- pico-8 default palette
					col = Pico.RGB[i]
					str = string.format("%02i",i)
				else
					--extended palette
					col = Pico.RGB[i+128]
					str = string.format("%03i",i + 128)
				end
				DrawFilledRect(rect, col,nil, true)
				DrawFilledRect({rect.x + 5, rect.y + 5, rect.w - 10, rect.h - 10}, col)
				local x,y = DrawText(rect.x + (rect.w - w2 * #str) \ 2,rect.y + (rect.h - h2) \ 2, str, COLWHITE, 2)
				if p == 0 then
					DrawText(rect.x + (rect.w - w1 * 3) \2, y, string.format("%03i", activePico:PaletteGetColor(i)), COLDARKWHITE)
				end
			end
		end
	
	elseif _leftSideMode == "sound" or _leftSideMode == "music" then
		-- sound and music
		
		-- draw background
		DrawBorder(_rect128x128.x, _rect128x128.y, _rect128x128.w, _rect128x128.h, Pico.RGB[5])
		DrawFilledRect(_rect128x128,COLBLACK)
		
		-- when picoremote is playing something, highlight this.
		-- otherwise check the selected number.
		local mus,pat,s1,s2,s3,s4,t1,t2,t3,t4 = PicoRemoteStatus()
		if s1 != -1 and _leftSideMode == "sound" then
			-- playing a sound effect
			leftSideInfo = s1
			
		elseif mus and pat != -1 and _leftSideMode == "music" then
			-- playing a music
			leftSideInfo = pat
		
		elseif _cursorPos != _cursorPosEnd then
			-- cursor highlighted a number
			local s,e = _cursorPos, _cursorPosEnd
			if s>e then s,e = e,s end
			local nb = tonumber(activePico:LuaSub(s,e-1))
			if nb and nb >= 0 and nb <= 63 and nb \ 1 == nb then
				leftSideInfo = nb
				local x = nb & 0xf
				local y = (nb >> 4) & 0xf				
			end
			
		elseif SDL.Rect.ContainsPoint(_rect128x128, {mx, my}) then
			-- mouse is over a sfx/music
			leftSideInfo = (mx - _rect128x128.x) \ _128SizeBig + ( (my - _rect128x128.y) \ _128SizeBig * 8)		
		end
				
		if _leftSideMode == "sound" then
			-- draw all sounds
			for y = 0,7 do
				for x = 0,7 do
					local i = x + y * 8
					local rect = {x = _rect128x128.x + _128SizeBig * x, y = _rect128x128.y + _128SizeBig * y, w = _128SizeBig, h = _128SizeBig}
					renderer:SetClipRect(rect)
					
					-- draw background
					local col
					if activePico:SFXEmpty(i) then 
						col = leftSideInfo != i and COLBLACK or Pico.RGB[2]
					elseif _sfxUsedIn[i] and #_sfxUsedIn[i] > 0 then
						col = leftSideInfo != i and COLDARKGREY or Pico.RGB[2]
					else
						col = leftSideInfo != i and COLGREY or Pico.RGB[4]
					end			
					DrawFilledRect(rect, col ,nil, true)				
					
					-- draw the texture
					local tex = TexturesGetSFX(i)
					tex:SetBlendMode("BLEND")
					tex:SetScaleMode("NEAREST")
					renderer:Copy(tex, nil, rect)		
					
					-- draw the name
					local str = activePico:SaveDataGet("SFXname",i) or ""
					if str == "" then str = string.format("%02d",i) end
					DrawText(rect.x+1,rect.y+1,str,Pico.RGB[6])
				
				end
			end
		else
			-- draw all music
			local w1,h1 = SizeText("+")
			for y = 0,7 do
				for x = 0,7 do
					local i = x + y * 8
					
					local rect = {x = _rect128x128.x + _128SizeBig * x, y = _rect128x128.y + _128SizeBig * y, w = _128SizeBig, h = _128SizeBig}
					renderer:SetClipRect(rect)
					
					local t = activePico:MusicGet(i)
					local col,tcol
					
					if t.disabled[1] and t.disabled[2] and t.disabled[3] and t.disabled[4] then
						col = (leftSideInfo == i) and Pico.RGB[9] or Pico.RGB[1]
						tcol = Pico.RGB[0]			
					else
						col = (leftSideInfo == i) and Pico.RGB[8] or Pico.RGB[13]
						tcol = Pico.RGB[6]		
					end
					
					if moduleMusic and moduleMusic.texMusicBack then
						-- we use the music-background from music-module
						moduleMusic.texMusicBack:SetColorMod( col.r,col.g,col.b)
						moduleMusic.texMusicBack:SetScaleMode("NEAREST")
						moduleMusic.texMusicBack:SetBlendMode("BLEND")		
						local val = (t.beginLoop and 1 or 0) | (t.endLoop and 2 or 0) | (t.stop and 4 or 0)
						renderer:Copy(moduleMusic.texMusicBack, {val * 8,0,8,8}, {rect.x,rect.y,rect.w,rect.h - 10})

					else
						-- a simple rect, if we don't have access to the texture
						DrawFilledRect({rect.x,rect.y,rect.w,rect.h - 5}, col)
					end
					
					-- draw the 4 voices, when in use
					local sw,sh = (rect.w - 3 - 4) \ 4,5
					for i=1,4 do
						if not t.disabled[i] then
							local c = activePico:SFXDominate(t.sfx[i]) + 8
							if c > 15 then c = 3 end
							DrawFilledRect( {rect.x + (sw + 1) * (i-1)+2, rect.y + rect.h - 8, sw, sh}, Pico.RGB[ c ] )
						end
					end
					
					-- draw the name
					local str = activePico:SaveDataGet("MusicName",i) or ""
					if str == "" then str = string.format("%02d",i) end
					DrawText(rect.x + (rect.w - w1 * #str) \ 2, rect.y + (rect.h - h1 - 5) \ 2, str, tcol)
					
				end
			end
		end		
		
		-- draw grid
		renderer:SetClipRect(_rect128x128)
		for x = _rect128x128.x-1, _rect128x128.x + _rect128x128.w, _128SizeBig do
			DrawFilledRect({x, _rect128x128.y, 1, _rect128x128.h}, COLGREY)
		end
		for y = _rect128x128.y-1, _rect128x128.y + _rect128x128.h, _128SizeBig do
			DrawFilledRect({_rect128x128.x, y, _rect128x128.w, 1}, COLGREY)
		end
		renderer:SetClipRect( nil )
		
		-- draw additional info
		if leftSideInfo then
			local x,y = leftSideInfo & 0xf, (leftSideInfo >> 4) & 0xf
			local xx,yy = _rectLSInfo.x, _rectLSInfo.y + 5
			xx = DrawText(xx,yy,string.format("id: 0x%02x - %03i - press [ctrl]+[t] to play / stop",leftSideInfo,leftSideInfo),COLDARKWHITE)
			if _leftSideMode == "sound" then
				_leftSideSFX = leftSideInfo
			else 
				_leftSideMusic = leftSideInfo
			end
		end
		
	end
		
	-- sourcecode
	
	-- draw background
	DrawBorder(_rectSourceCode.x,_rectSourceCode.y,_rectSourceCode.w,_rectSourceCode.h, Pico.RGB[5])
	DrawFilledRect(_rectText, _rgb.LuaColorBack, nil, true)
	DrawFilledRect(_rectNumber, _rgb.LuaColorLinenumberBack, nil, true)
	
	renderer:SetClipRect( _rectSourceCode )
	
	local line, pageHeight = m.scrollbar.y:GetValues()
	local offset, pageWidth = m.scrollbar.x:GetValues()
	local endX = _rectSourceCode.x + _rectSourceCode.w	
	
	
	-- highlight line
	local cLine,cOffset = _PosToLineOffset(_cursorPos)	
	renderer:SetClipRect( _rectText )
	DrawFilledRect({_rectText.x, _rectText.y + (cLine - line - 1) * _FontHeight(), _rectText.w, _FontHeight()}, _rgb.LuaColorHighlightLine)
		
	-- check if a word is highlighted
	local cs,ce = _cursorPos, _cursorPosEnd
	if cs > ce then ce,cs = cs,ce end
	local cursorWord = activePico:LuaSub(cs,ce - 1)
	local startByte, stopByte
	if not _ALPHANUMERIC[activePico:LuaByte(cs - 1)] and not _ALPHANUMERIC[activePico:LuaByte(ce)] then
		startByte, stopByte= cursorWord:byte(), cursorWord:byte(#cursorWord)
	end
	
	-- check if cursor is over a brace and highlight matching brace
	local braceByte = activePico:LuaByte(_cursorPos)
	local braceMatch = nil
	local braceBad = nil
	if _cursorPos == _cursorPosEnd and _BRACES[braceByte] and _colors[_cursorPos] == _rgb.LuaColorControl then
		-- is a brace
		local d = _BRACES[braceByte]
		local e = (d < 0) and (_activeTab.posStart) or (_activeTab.posEnd)
		
		-- search for matching brace
		local value = _BRACES[braceByte]		
		for pos = _cursorPos + d, e, d do
			if _colors[pos] == _rgb.LuaColorControl then				
				value += _BRACES[ activePico:LuaByte(pos) ] or 0
				if value == 0 then
					-- found 
					braceMatch = pos
					break
				end
			end
		end
		
		-- not found - bad brace
		if not braceMatch then
			braceBad = _cursorPos
		end
	end
	
	-- draw text
	local yy = _rectSourceCode.y
	for i = line + 1, line + pageHeight + 1 do
		if _lines[i] then
			local xx = _rectNumber.x + _rectNumber.w - 5
			
			renderer:SetClipRect( _rectSourceCode )
			
			-- line number
			local str = string.format("%i",i)
			local x = _FontCharSize(str)
			_FontDraw(xx-x, yy, str,_rgb.LuaColorLinenumber,2)
						
			renderer:SetClipRect( _rectText )
			xx = _rectText.x + 5 - offset			
			local markNext = 0
			for pos,char in activePico:LuaCodes(_lines[i].s, _lines[i].e ) do 
				local wChar,hChar = _FontCharSize(char)
			
			
				if markNext == 0 then
					-- check if next word matches selected word
					if char == startByte then 
						if activePico:LuaByte(pos + #cursorWord-1) == stopByte and activePico:LuaSub(pos, pos + #cursorWord -1) == cursorWord and
							not _ALPHANUMERIC[activePico:LuaByte(pos + #cursorWord)] and not _ALPHANUMERIC[activePico:LuaByte(pos-1)] then
							-- yes -> colorize the # chars
							markNext = #cursorWord
						end
					end
				end

				if pos >= cs and pos < ce then
					-- selected part of source code
					DrawFilledRect({xx,yy,wChar,hChar},_rgb.LuaColorMark)
					markNext = 0
					
				elseif markNext > 0 then
					-- highlight word, because it matches selection		
					DrawFilledRect({xx,yy,wChar,hChar},_rgb.LuaColorMarkWord)
					markNext -= 1
				end
				
				-- choose a text color
				local col
				if pos == braceBad then
					-- bad brace color
					col = _rgb.LuaColorMarkBadBrace
					
				elseif braceMatch and (pos == braceMatch or pos == _cursorPos) then
					-- matching brace color
					col = _rgb.LuaColorMarkBrace
					
				else
					-- color form colorization or red
					col = _colors[pos] or COLRED
				end
						
				-- draw char
				xx = _FontDraw(xx,yy,char,col)
								
				if xx >= endX then break end				
			end
			
		end	
		yy += _FontHeight()
	end
	
	-- draw blinking cursor
	local cLine,cOffset = _PosToLineOffset(_cursorPos)	
	if (_oldCLine != cLine or _oldCOffset != cOffset or (SDL.Time.Get()*100) % config.cursorBlink < config.cursorBlink\2 ) and hasFocus and not popup:HasFocus() and not menu:HasFocus() then 
		local xx = _FontLineWidth(cLine, cOffset -2)
		DrawFilledRect({_rectText.x + 5 + (xx - offset - 1), _rectText.y + (cLine - line - 1) * _FontHeight(), 2, _FontHeight()}, _rgb.LuaColorCursor)
		_oldCLine, _oldCOffset = cLine, cOffset		
	end
		
	renderer:SetClipRect(nil)
	
	-- draw status line under sourcecode
	local line,offset = _PosToLineOffset(_cursorPos)
	local line2,offset2 = _PosToLineOffset(_cursorPosEnd)
	local str = string.format("length: %i / 65535  lines: %i  cursor: %ix%i  ", activePico:LuaLen(), #_lines, offset, line)
	if _cursorPos != _cursorPosEnd then
		local px = _FontPixelSize(_cursorPos, _cursorPosEnd)
		str ..= string.format("selection: %i x %i / %ipx", math.abs(_cursorPos - _cursorPosEnd), math.abs(line-line2) +1, px)
	else
		str ..= string.format("position: %i",_cursorPos)
	end
	if _puny then
		str ..= "  Puny font: ON"
	else
		str ..= "  Puny font: off"
	end	
	DrawText(_rectInfobar.x, _rectInfobar.y, str, COLDARKWHITE)
		
end


local _selectLineStart
function m.MouseDown(m, mx, my, mb, clicks)
	if _mouseLock then return end
	local isShift = SDL.Keyboard.GetModState():hasflag("SHIFT") > 0
	
	if (_leftSideMode == "sprite" or _leftSideMode == "charset") and SDL.Rect.ContainsPoint(_rect128x128, {mx, my}) then
		local xx = (mx - _rect128x128.x) \ _128Size
		local yy = (my - _rect128x128.y) \ _128Size
		local id = xx + (yy << 4)
		
		if mb == "LEFT" then
			if _leftSideMode == "sprite" then
				m:Input(tostring(id))
			elseif id > 0 then
				m:Input(activePico:StringPicoToUTF8(string.char(id)))
			end

		elseif mb == "RIGHT" then
			if _leftSideMode == "sprite" then
				moduleSprite:API_SetSprite( id )
			elseif id > 0 then
				moduleCharset:API_SetCharacter( id )
			end
		end
		
	elseif (_leftSideMode == "sound" or _leftSideMode == "music") and SDL.Rect.ContainsPoint(_rect128x128, {mx, my}) then
		--local w,h = _rect128x128.w \ 8, _rect128x128.h \ 8
		local xx = (mx - _rect128x128.x) \ _128SizeBig
		local yy = (my - _rect128x128.y) \ _128SizeBig
		local id = xx + yy*8
		if mb == "LEFT" then
			m:Input(tostring(id))
		elseif mb == "RIGHT" then
			if _leftSideMode == "sound" then
				moduleSFX:API_SetSFX( id )
			else
				moduleMusic:API_SetMusic( id )
			end
		end
	
	
	elseif mb == "LEFT" and _leftSideMode == "function" and SDL.Rect.ContainsPoint(_rectFunctions, {mx, my}) then
		local line, pageHeight = m.scrollbar.fnY:GetValues()
		local cLine = (my - _rectFunctions.y) \ _FontHeight() + line + 1
		if cLine > 0 and cLine <= #_functions then
			_cursorPosEnd = _functions[cLine].posStart 
			_cursorPos = _functions[cLine].posEnd + 1
			_VisibleCursor()
		end
	
	elseif mb == "LEFT" and SDL.Rect.ContainsPoint(_rectText, {mx, my}) then		
		local line, pageHeight = m.scrollbar.y:GetValues()
		local offset, pageWidth = m.scrollbar.x:GetValues()
		local cLine = math.clamp( (my - _rectText.y) \ _FontHeight() + line + 1, 1, #_lines)
		local xx = _FontLineWidth( cLine, nil, mx - _rectText.x + offset) 		
		local cOffset = math.clamp( xx - _lines[cLine].s + 1, 1, _lines[cLine].e - _lines[cLine].s + 1)
		local newPos = _LineOffsetToPos(cLine, cOffset)
		
		if clicks > 1 then 
			
			if _cursorPos == _cursorPosEnd or math.clamp(_cursorPos,_cursorPosEnd, newPos) != newPos then
				if newPos == _cursorPos then
					_SelectWord(newPos)
				else
					_cursorPos = newPos
					if not isShift then _cursorPosEnd = _cursorPos end
					_mouseLock = "selectCursor"
				end
				
			else
				_cursorPos = _lines[cLine].e
				_cursorPosEnd = _lines[cLine].s
			end
			
		else
			_cursorPos = newPos
			if not isShift then _cursorPosEnd = _cursorPos end
			_mouseLock = "selectCursor"
		end		
		_VisibleCursor()
		
	elseif mb == "LEFT" and SDL.Rect.ContainsPoint(_rectNumber, {mx, my}) then
		local line, pageHeight = m.scrollbar.y:GetValues()
		local cLine = math.clamp( (my - _rectNumber.y) \ _FontHeight() + line + 1, 1, #_lines)
		_cursorPos = _lines[cLine].e
		_cursorPosEnd = _lines[cLine].s
		_selectLineStart = cLine
		_mouseLock = "selectLine"
		_VisibleCursor()
		
	end
	
	
end

function m.MouseMove(m, mx, my, mb)
	if _mouseLock == "selectCursor" and SDL.Rect.ContainsPoint(_rectText, {mx, my}) then
		local line, pageHeight = m.scrollbar.y:GetValues()
		local offset, pageWidth = m.scrollbar.x:GetValues()
		local cLine = math.clamp( (my - _rectText.y) \ _FontHeight() + line + 1, 1, #_lines)
		local xx = _FontLineWidth( cLine, nil, mx - _rectText.x + offset) 		
		local cOffset = math.clamp( xx - _lines[cLine].s + 1, 1, _lines[cLine].e - _lines[cLine].s + 1)
		_cursorPos = _LineOffsetToPos(cLine, cOffset)	
		_VisibleCursor()
		
	elseif _mouseLock == "selectLine" and SDL.Rect.ContainsPoint(_rectNumber, {mx, my}) then
		local line, pageHeight = m.scrollbar.y:GetValues()
		local cLine = math.clamp( (my - _rectNumber.y) \ _FontHeight() + line + 1, 1, #_lines)
		if cLine < _selectLineStart then
			_cursorPos = _lines[cLine].s
			_cursorPosEnd = _lines[_selectLineStart].e		
		else
			_cursorPos = _lines[cLine].e + 1
			_cursorPosEnd = _lines[_selectLineStart].s
		end
		_VisibleCursor()
		
		
	end
	
	
end

function m.MouseUp(m, mx, my, mb)
	if _mouseLock == "selectCursor" and mb == "LEFT" then
		_mouseLock = nil
		
	elseif _mouseLock == "selectLine" and mb == "LEFT" then
		_mouseLock = nil
	end
end

function m.MouseWheel(m, wx, wy, mx, my)
	-- mousewheel is moved by wx,wy - on mouseposition mx,my
	
	if SDL.Keyboard.GetModState():hasflag("CTRL") > 0 then
		wy = math.clamp(-1,1,wy)	
		config.LuaZoom = math.clamp( config.LuaZoom + wy, 1, 6)
		_MenuZoomSet(menu:GetId("luaZoom"..config.LuaZoom))
		
	else
	
		if SDL.Keyboard.GetModState():hasflag("SHIFT") > 0 then
			wx,wy = - wy * _fontMaxWidth(), -wx
		end
		if SDL.Rect.ContainsPoint(_rectSourceCode, {mx, my}) then
			local pos = m.scrollbar.y:GetValues()
			m.scrollbar.y:SetValues( pos - wy)
			local pos = m.scrollbar.x:GetValues()
			m.scrollbar.x:SetValues( pos + wx)
		end
		
		if SDL.Rect.ContainsPoint(_rectFunctions, {mx, my}) then
			local pos = m.scrollbar.fnY:GetValues()
			m.scrollbar.fnY:SetValues( pos - wy)
		end
	end
	
end


function m.KeyDown(m, sym, scan, mod)
	-- Keyboard is pressed.
	local isShift = mod:hasflag("SHIFT") > 0
	local isCtrl = mod:hasflag("CTRL") > 0
	local isAlt = mod:hasflag("ALT") > 0
	
	local line, pageHeight = m.scrollbar.y:GetValues()
	local offset, pageWidth = m.scrollbar.x:GetValues()
		
	local dx, dy = 0,0
	
	--[[ map alt + UP/DOWN to ctrl + UP/DOWN
	if isAlt and scan == "DOWN" then _NextFunction() return true end
	if isAlt and scan == "UP" then _PreviousFunction() return true end
	--]]
	
	if isCtrl  then
		if sym == "T" then
			local mus,pat,s1,s2,s3,s4,t1,t2,t3,t4 = PicoRemoteStatus()		
			if mus or s1 != -1 then
				-- stop playing
				PicoRemoteSFX( -1 )		
				PicoRemoteMusic( -1 )
			elseif _leftSideSFX then	
				-- play complete sfx
				PicoRemoteWrite(  Pico.SFX + _leftSideSFX * 68, 68 ,activePico:SFXAdr(_leftSideSFX))
				PicoRemoteSFX( _leftSideSFX )
			elseif _leftSideMusic then	
				-- play complete music
				PicoRemoteWrite(  Pico.SFX , Pico.SFXLEN, activePico:SFXAdr())
				PicoRemoteWrite(  Pico.MUSIC , Pico.MUSICLEN, activePico:MusicAdr() )
				PicoRemoteMusic( _leftSideMusic )
			end
		elseif scan == "TAB" then
			local x = _tabs[(_activeTab.index - 1 + (isShift and -1 or 1)) % #_tabs +1]
			if x then x.b:OnClick() end
				
		elseif scan == "HOME" then
			_cursorPos = _lines[1].s
			if not isShift then _cursorPosEnd = _cursorPos end
			_VisibleCursor()
			
		elseif scan == "END" then
			_cursorPos = _lines[#_lines].e
			if not isShift then _cursorPosEnd = _cursorPos end
			_VisibleCursor()
			
		
		
		elseif scan == "RIGHT" then
			local cLine,cOffset = _PosToLineOffset(_cursorPos)
			local pos = _lines[cLine].s + cOffset - 1
			local col = _colors[pos]
			local byte = activePico:LuaByte(pos) if byte == 9 then byte = 32 end
			for p = pos, _lines[cLine].e do
				local cc = _colors[p]
				local bb = activePico:LuaByte(p) if bb == 9 then bb = 32 end
				_cursorPos = p
				if (byte == 32 and bb!= 32) or (byte != 32 and cc != col and bb != 32) then
					break
				end
				if bb == 32 then col = -1 end				
			end
			if not isShift then _cursorPosEnd = _cursorPos end
			_VisibleCursor()
			
		elseif scan == "LEFT" then
			local cLine,cOffset = _PosToLineOffset(_cursorPos)
			local pos = _lines[cLine].s + cOffset - 1
			local col = _colors[pos]
			local byte = activePico:LuaByte(pos) if byte == 9 then byte = 32 end
			_cursorPos = _lines[cLine].s
			for p = _lines[cLine].s, pos -1 do
				local cc = _colors[p]
				local bb = activePico:LuaByte(p) if bb == 9 then bb = 32 end
				
				if (byte == 32 and bb!= 32) or (byte != 32 and cc != col and bb != 32) then
					_cursorPos = p
					col = cc
					byte = bb
				end
				if bb == 32 then col = -1 end		
			end
			if not isShift then _cursorPosEnd = _cursorPos end
			_VisibleCursor()
		end
		
	else
		-- no ctrl
	
		if scan == "HOME" then
			local cLine,cOffset = _PosToLineOffset(_cursorPos)
			_cursorPos = _lines[cLine].s
			if not isShift then _cursorPosEnd = _cursorPos end
			_VisibleCursor()
		elseif scan == "END" then
			local cLine,cOffset = _PosToLineOffset(_cursorPos)
			_cursorPos = _lines[cLine].e
			if not isShift then _cursorPosEnd = _cursorPos end
			_VisibleCursor()
			
		elseif scan == "UP" then
			dy -= 1
		elseif scan == "DOWN" then
			dy += 1
		elseif scan == "LEFT" then
			dx -= 1
		elseif scan == "RIGHT" then
			dx += 1
		elseif scan == "PAGEUP" then
			dy -= pageHeight \ 2
		elseif scan == "PAGEDOWN" then
			dy += pageHeight \ 2
		end
	end
	if dy != 0 then
		local cLine,cOffset = _PosToLineOffset(_cursorPos)
		cLine = math.clamp( cLine + dy, 1, #_lines)
		cOffset = math.clamp( cOffset, 1, _lines[cLine].e - _lines[cLine].s + 1)
		_cursorPos = _LineOffsetToPos(cLine,cOffset)
		if not isShift then _cursorPosEnd = _cursorPos end
		_VisibleCursor()
	end
		
	if dx != 0 then
		_cursorPos = math.clamp(1, _cursorPos + dx, _lines[#_lines].e)
		if not isShift then _cursorPosEnd = _cursorPos end
		_VisibleCursor()
	end
	
	if scan == "KP_ENTER" or scan == "RETURN" then
		local cLine,cOffset = _PosToLineOffset(_cursorPos)
		local pos = _lines[cLine].s
		while activePico:LuaByte(pos) == 32 or activePico:LuaByte(pos) == 9 do 
			pos += 1
		end
		m:Input("\n" .. string.rep(" ", pos - _lines[cLine].s) )
	end
	
	if scan == "BACKSPACE" then
		if _cursorPos == _cursorPosEnd then
			if _cursorPos > 1 then
				_cursorPos -= 1
				m:Input("")
			end
		else
			m:Input("")
		end
	end
	-- delete is m.Delete()
end

function m.KeyUp(m, sym, scan, mod)
	-- keyboard is released.
end

function m.Paste(m, str)
	local old = _puny
	_puny = true
	m:Input(str:gsub("\r\n","\n"))
	_puny = old
end

function m.Copy(m, str)
	if _cursorPos != _cursorPosEnd then
		local s,e = _cursorPos, _cursorPosEnd
		if s > e then s,e = e,s end
		local str = activePico:StringPicoToUTF8(activePico:LuaSub(s, e - 1))
		InfoBoxSet("Copied ".. #str.." chars.")
		return str
	end
end

function m.Input(m, text)
	if activePico.writeProtected then return false end
	
	if not _puny and _altKeys[text] then
		text = _altKeys[text]
	end	
	
	
	local str = activePico:StringUTF8toPico(text)
	
	
		
	if _cursorPos != _cursorPosEnd  or (str != "" and str != nil) then
		local s,e = _cursorPos, _cursorPosEnd 
		if s>e then s,e = e,s end		
		local newPos = activePico:LuaReplace(s - 1, e - 1, str) + 1-- insert before char, set cursor after
		activePico:LuaSetUndoCursor(_cursorPos, _cursorPosEnd )
		_cursorPos = newPos
		_cursorPosEnd = _cursorPos
		_ClearEmptyTabs()
		m:Resize()
		_VisibleCursor()
	end
end

function m.Undo(m)
	local pos, posEnd = activePico:LuaGetUndoCursor() 
	_cursorPos = pos or _cursorPos
	_cursorPosEnd = posEnd or _cursorPosEnd
	m:Resize()
	_VisibleCursor()
end
m.Redo = m.Undo

function m.SelectAll(m)
	_cursorPos = _activeTab.posEnd
	_cursorPosEnd = _activeTab.posStart
end

function m.Delete(m)
	if _cursorPos == _cursorPosEnd then
		if _cursorPosEnd < _lines[#_lines].e then
			_cursorPosEnd += 1
			m:Input("")
		end
	else
		m:Input("")
	end
end

return m