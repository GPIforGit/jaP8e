--[[

	Hex module
	
	manage memory


--]]


modules = modules or {}
local m = {
	name = "Hex",
	sort = 80,	
}
table.insert(modules, m)

local _apiGetRangeButtons = {}

local _LINEBYTES = 16 -- bytes per line in hexview
local _cursor = 0x0 
local _cursorEnd = 0x0
local _cursorSub = 0 -- first or second part of the byte
local _rectHexBorder
local _rectHexText
local _rectInfoValues
local _lastfile = "data.rom"

-- scroll the bar, so that the cursor is visible
local function _CursorVisible(m)
	local a = _cursorEnd \ _LINEBYTES
	local barPos, barPage = m.scrollbar.hex:GetValues()
	if barPos +2 > a then
		barPos = a-2
	end
	if barPos + barPage - 3 < a then
		barPos = a - barPage + 3
	end	
	a = _cursor \ _LINEBYTES
	if barPos +2 > a then
		barPos = a-2
	end
	if barPos + barPage - 3 < a then
		barPos = a - barPage + 3
	end	
	m.scrollbar.hex:SetValues( barPos )
end

-- Set cursor to memory-postionen. with shift set "endcursor" to end of memory block
local function _ButSelectMemory(b)
	if b.userdata[2] != 1 or SDL.Keyboard.GetModState():hasflag("SHIFT") == 0 then		
		_cursor = b.userdata[1]
		_cursorEnd = b.userdata[2] + b.userdata[1] - 1
	else
		-- shift + size == 1 -> end of block
		_cursor = b.userdata[1] + 0xff
	end
	_cursorSub = 0
	_CursorVisible(m)	
end

-- calculate value of the string - return true/false, v1, v2
local function _Calc(str)
	-- create lua code in an empty enviroment
	local myenv = {}
	local f,err = load("return " .. tostring(str),"userinput","t",myenv)

	-- errorhandling
	if not f then
		SDL.Request.Message(window, TITLE, tostring(err) ,"OK STOP")
		return false
	end
		
	-- calculate
	local ok,a,b = pcall(f)

	-- errorhandling
	if not ok then
		SDL.Request.Message(window, TITLE, tostring(a) ,"OK STOP")
		return false
	end

	-- return values
	return true, a, b
end

-- save current block as file
local function _ButSaveBin(bin)
	if _cursor == _cursorEnd then 
		InfoBoxSet("Select a block first.")
		return 
	end

	-- request filename
	local file = RequestSaveFile(window, "Save binary",_lastfile, FILEFILTERROM)
	if file == nil then return false end
	_lastfile = file
	local path, name, extension = SplitPathFileExtension(file)
	
	
	-- open file to write
	local fwrite, err = io.open(file,"wb")
	if fwrite == nil then
		SDL.Request.Message(window,TITLE,"Can't save.\n"..err,"OK STOP")
		return false
	end

	-- write data and close
	local adr,size = math.min(_cursor,_cursorEnd), math.abs(_cursor - _cursorEnd) + 1
	fwrite:write( activePico:PeekString(adr, size) )
	fwrite:close()
	
	InfoBoxSet(string.format("Saved 0x%02x %i bytes to %s.",adr,size,name) )
end

-- load block from file and past it in
local function _ButLoadBin(bin)
	-- request file
	local file = RequestOpenFile(window, "Load binary", _lastfile, FILEFILTERROM)
	if file == nil then return false end
	_lastfile = file
	local path, name, extension = SplitPathFileExtension(file)
	
	-- open file to read
	local fread, err = io.open(file,"rb")
	if fread == nil then
		SDL.Request.Message(window,TITLE,"Can't load.\n"..err,"OK STOP")
		return false
	end
	
	-- read file and close
	local str = fread:read("a")
	fread:close()
	
	-- copy content to memory
	local adr = math.min(_cursor,_cursorEnd)
	activePico:PokeString(adr, str)
	
	-- set cursor position
	_cursor = adr
	_cursorEnd = adr + #str -1	
	_CursorVisible(m)
	
	-- inform the user
	InfoBoxSet(string.format("Loaded %s to 0x%02x %i bytes.",name,adr,#str) )	
end

-- allows other modules to add buttons 
function m.API_AddGetRange(m, txt, fn)
	table.insert(_apiGetRangeButtons, {text = txt, fn = fn})
end

-- allows other modules to select memory
function m.API_SelectRange(m, posStart, posEnd)
	ModuleActivate(m)
	_cursor = posStart
	_cursorEnd = posEnd
	_cursorSub = 0
	_CursorVisible(m)
end

-- Copy memory as hex
function m.API_CopyHex(m, adr, size)
	InfoBoxSet(string.format("Copied from 0x%04x %d bytes.", adr, size))
	return string.format("\\^@%04x%04x",adr,size).. activePico:PeekChar(adr,size)
end

-- paste hex as memory
function m.API_PasteHex(m, str, adr, size)
	if str:sub(1,1) == "\"" and str:sub(-1,-1) == "\"" then
		str = str:sub(2,-2)
	end

	if str:sub(1,3) == "\\^@" then
		
		-- get data from string
		local cadr = tonumber("0x" .. str:sub(4,7)) or 0
		local csize = tonumber("0x" .. str:sub(8,11)) or 1
		
		-- when size = 1 select all
		if size == 1 then size = csize end		
		-- when the selected size is bigger than from to paste, clamp to csize		
		size = math.min(size,csize) 
		
		
		local action		
		if adr == cadr and csize <= size then
			-- identical, always simple copy
			action = "YES"
		else
			-- ask where to paste - stored memory adress or selected space?
			action = SDL.Request.Message(window, TITLE, string.format("Copy %d bytes to 0x%04x?\n (no = %d bytes to 0x%04x)",csize,cadr,size,adr),"YESNOCANCEL QUESTION DEFAULT3")
		end
		
		if action == "YES" then
			-- copy to position from clipboard
			activePico:PokeChar(cadr, str:sub(12), csize)
			_cursor = cadr
			_cursorEnd = cadr + csize -1
			_cursorSub = 0
			InfoBoxSet(string.format("Pasted to 0x%04x %d bytes.", cadr, csize))
			
		elseif action == "NO" then
			-- copy to selected memory position
			activePico:PokeChar(adr, str:sub(12), size)
			_cursor = adr
			_cursorEnd = adr + size -1
			_cursorSub = 0
			InfoBoxSet(string.format("Pasted to 0x%04x %d bytes.", adr, size))
		end
		
	end
end

-- free all resources
function m.Quit(m)
	m.buttons:DestroyContainer()
	m.scrollbar:DestroyContainer()
	m.inputs:DestroyContainer()
	m.menuBar:Destroy()	
end

-- shortcuts
local function _InitShortcut()
	local MoveCursor = function (s)
		local off
		if s.off then
			off = s.off
		else
			local barPos, barPage = m.scrollbar.hex:GetValues()
			off = s.page * _LINEBYTES * (barPage \2)
		end
	
		_cursor = math.clamp(0,0xffff,_cursor + off)
		if not s.shift then 
			_cursorEnd = _cursor
		end
		_CursorVisible(m)
	end
	
	local Delete = function (s)
		for adr = _cursor, _cursorEnd, _cursor > _cursorEnd and -1 or 1 do
			activePico:Poke(adr, 0)
		end
	end
	
		
	m.shortcut = {}
	local s
	s = ShortcutAdd(m.shortcut, "UP", MoveCursor) s.off = -_LINEBYTES
	s = ShortcutAdd(m.shortcut, "DOWN", MoveCursor) s.off = _LINEBYTES
	s = ShortcutAdd(m.shortcut, "LEFT", MoveCursor) s.off = -1
	s = ShortcutAdd(m.shortcut, "RIGHT", MoveCursor) s.off = 1
	s = ShortcutAdd(m.shortcut, "PAGEUP", MoveCursor) s.page = -1
	s = ShortcutAdd(m.shortcut, "PAGEDOWN", MoveCursor) s.page = 1
	
	s = ShortcutAdd(m.shortcut, "SHIFT+UP", MoveCursor) s.off = -_LINEBYTES s.shift = true
	s = ShortcutAdd(m.shortcut, "SHIFT+DOWN", MoveCursor) s.off = _LINEBYTES s.shift = true
	s = ShortcutAdd(m.shortcut, "SHIFT+LEFT", MoveCursor) s.off = -1 s.shift = true
	s = ShortcutAdd(m.shortcut, "SHIFT+RIGHT", MoveCursor) s.off = 1 s.shift = true
	s = ShortcutAdd(m.shortcut, "SHIFT+PAGEUP", MoveCursor) s.page = -1 s.shift = true
	s = ShortcutAdd(m.shortcut, "SHIFT+PAGEDOWN", MoveCursor) s.page = 1 s.shift = true
	
	s = ShortcutAdd(m.shortcut, "DELETE", Delete)
	s = ShortcutAdd(m.shortcut, "BACKSPACE", Delete)
end

-- initalize module
function m.Init(m)
	local w1,h1 = SizeText("1")
	m.buttons = buttons:CreateContainer()
	m.scrollbar = scrollbar:CreateContainer()
	m.inputs = inputs:CreateContainer()
	
	_rectHexBorder = {x=0, y=topLimit, w= w1 * (4 + 2 + _LINEBYTES * 3 + 2 + _LINEBYTES), h=0}
	_rectHexText = {x=0, y=_rectHexBorder.y + 5, w=_rectHexBorder.w - 10, h=0}
	_rectInfoValues = {x=0, y=0, w= _rectHexBorder.w, h=h1}
	
	m.scrollbar:Add("hex",1,1,false,1,1,2)
	
	local size = 151
	local size2 = 75
	local b
	
	-- labels
	m.buttons:AddLabel("lROM","ROM")
	m.buttons:AddLabel("lRAM","RAM")
	m.buttons:AddLabel("lPOS","POS")
	
	-- rom buttons
	b = m.buttons:Add("GFX", "Sprites",size)
	b.userdata = {Pico.SPRITE ,Pico.SPRITELEN}
	
	b = m.buttons:Add("GFXlo", "(low)",size2)
	b.userdata = {0x0000      ,0x1000}
	
	b = m.buttons:Add("GFXhi", "(shared)",size2)
	b.userdata = {0x1000      ,0x1000}
	
	b = m.buttons:Add("MAP", "Map",size)
	b.userdata = {0x1000      ,0x2000}
	
	b = m.buttons:Add("MAPlo", "(low)",size2)
	b.userdata = {0x2000      ,0x1000}
	
	b = m.buttons:Add("MAPhi", "(shared)",size2)
	b.userdata = {0x1000      ,0x1000}
	
	b = m.buttons:Add("FLAGS", "Sprite flags",size)
	b.userdata = {0x3000      ,0x0100}
	
	b = m.buttons:Add("FLAGSlo", "(low)",size2)
	b.userdata = {0x3000      ,0x0080}
	
	b = m.buttons:Add("FLAGShi", "(high)",size2)
	b.userdata = {0x3080      ,0x0080}	
	
	
	b = m.buttons:Add("MUSIC", "Music",size)
	b.userdata = {Pico.MUSIC  ,Pico.MUSICLEN}
	
	b = m.buttons:Add("SFX","Sound", size)
	b.userdata = {Pico.SFX    ,Pico.SFXLEN}
	
	b = m.buttons:Add("romAll", "Complete Rom",size)
	b.userdata = {0x0000,0x4300}
	
	-- ram buttons
	b = m.buttons:Add("Free", "Free", size)
	b.userdata = {Pico.FREEMEM,Pico.FREEMEMLEN}
	
	b = m.buttons:Add("CHARSET", "Custom Font",size)
	b.userdata = {Pico.CHARSET,Pico.CHARSETLEN}
	
	b = m.buttons:Add("charOpt","Settings",size2)
	b.userdata = {Pico.CHARSET, 8 * 16}
	
	b = m.buttons:Add("charAll","Chars",size2)
	b.userdata = {Pico.CHARSET + 8*16, 8*(256-16)}
		
	
	b = m.buttons:Add("PAL", "Palette",size)
	b.userdata = {Pico.PAL    ,Pico.PALLEN}
	
	b = m.buttons:Add("LABEL", "Label",size)
	b.userdata = {Pico.LABEL  ,Pico.LABELLEN}
			
	b = m.buttons:Add("MAPsettings", "Map setup",size)
	b.userdata = {Pico.MAPPOS,0x0002}
		
	-- custom buttons
	b = m.buttons:Add("MAPcustom", "Map", size)
	b.userdata = {0x0000,0x0000}
		
	b = m.buttons:Add("GFXcustom", "Sprites", size)
	b.userdata = {0x0000,Pico.SPRITELEN}
	
	b = m.buttons:Add("FlagsCustom", "Flags",size)
	b.userdata = {0x0000,Pico.SPRFLAGLEN}
	
	b = m.buttons:Add("SFXCustom", "Sound",size)
	b.userdata = {0x0000,Pico.SFXLEN}
	
	b = m.buttons:Add("MusicCustom", "Music",size)
	b.userdata = {0x0000,Pico.MUSICLEN}

	-- high-memory
	for i = 0x80,0xff do 
		local b = m.buttons:Add("HI"..i, string.format("%02x",i))
		b.userdata 	= {i * 0x100, 1}
	end
	
	-- set handling for all rom/ram/pos-buttons
	for id,b in pairs(m.buttons) do
		if b.userdata then 
			b.OnClick = _ButSelectMemory
		end
	end
	
	-- input fields
	b = m.inputs:Add("range", "Range:", "", _rectHexBorder.w)
	b.OnTextChange = function (inp, text) 
		local f, a, b = _Calc(text)
		if f then
			a = tonumber(a) or 0
			b = tonumber(b) or 0
			_cursor = math.clamp(0,0xffff,a)
			_cursorEnd = math.clamp(0,0xffff, a + b -1)
			_CursorVisible(m)
		end
	end
	
	-- select-input fields
	b = m.inputs:Add("sfx", "Sound:", "", 160,nil)
	b.OnTextChange = function (inp,text)
		local f, a, b = _Calc(text)
		if f then
			a = math.clamp(0,63,tonumber(a) or 0)
			b = math.clamp(0,63,tonumber(b) or a)			
			_cursor = Pico.SFX + a * 68 
			_cursorEnd = Pico.SFX + b * 68 + 67
			inp.text = a..", "..b
			_CursorVisible(m)
		else
			inp.text = ""
		end
	end
	
	b = m.inputs:Add("char", "Char: ", "", 160,nil)
	b.OnTextChange = function (inp,text)
		local f, a, b = _Calc(text)
		if f then
			a = math.clamp(0,255,tonumber(a) or 0)
			b = math.clamp(0,255,tonumber(b) or a)			
			_cursor =  Pico.CHARSET + a * 8 
			_cursorEnd = Pico.CHARSET + b * 8 + 7
			inp.text = a..", "..b
			_CursorVisible(m)
		else
			inp.text = ""
		end
	end
	
	b = m.inputs:Add("music", "Music:", "", 160,nil)
	b.OnTextChange = function (inp,text)
		local f, a, b = _Calc(text)
		if f then
			a = math.clamp(0,63,tonumber(a) or 0)
			b = math.clamp(0,63,tonumber(b) or a)			
			_cursor =  Pico.MUSIC + a * 4
			_cursorEnd = Pico.MUSIC + b * 4 + 3
			inp.text = a..", "..b
			_CursorVisible(m)
		else
			inp.text = ""
		end
	end
	
	-- action buttons
	b = m.buttons:Add("loadBin","Load",100)
	b.OnClick = _ButLoadBin
	
	b = m.buttons:Add("saveBin","Save",100)
	b.OnClick = _ButSaveBin

	-- custom menu
	m.menuBar = menu:CreateBar()
	m.menuBar:AddFile()	
	
	local men = m.menuBar:AddEdit()
	men:Add()
	men:Add("loadBinary", "Load binary", _ButLoadBin, nil)
	men:Add("saveBinary", "Save binary", _ButSaveBin, nil)
	
	m.menuBar:AddPico8()
	m.menuBar:AddSettings()
	m.menuBar:AddModule()
	m.menuBar:AddDebug(r)
	
	_InitShortcut()
	
	return true
end

-- resize window
function m.Resize(m)
	local ow, oh = renderer:GetOutputSize()
	local w1,h1 = SizeText("1")
	
	-- position elements
	_rectHexBorder.x = 16 * 32 + 10 + (ow - MINWIDTH) \ 2
	_rectHexBorder.h = oh - _rectHexBorder.y - 5 - m.inputs.range.rectBack.h - 5 - h1 - 5
	
	_rectHexText.x = _rectHexBorder.x + 5
	_rectHexText.h = _rectHexBorder.h - 10
	
	_rectInfoValues.x = _rectHexBorder.x
	_rectInfoValues.y = oh - h1 - 5
	
	m.inputs.range:SetPos(_rectHexBorder.x, _rectHexBorder.y + _rectHexBorder.h + 5)
	
	-- update scrollbars
	local barPage = (_rectHexText.h \ h1)
	m.scrollbar.hex:SetValues(nil, barPage, 0x10000 \ _LINEBYTES)
	m.scrollbar.hex:SetPos(_rectHexBorder.x + _rectHexBorder.w + 5, _rectHexBorder.y, BARSIZE, _rectHexBorder.h)

	-- make sure, that the cursor is visible
	_CursorVisible(m)
	
	-- position buttons
	local widthColumn = (m.buttons.GFX.rectBack.w + m.buttons.lROM.rectBack.w +5+5)
	local b
	
	-- rom buttons
	m.buttons.GFX:SetPos(_rectHexBorder.x -  widthColumn * 2, _rectHexBorder.y)
	b = m.buttons.GFXlo:SetDown(1)
	m.buttons.GFXhi:SetRight(1)
	
	m.buttons.MAP:SetDown(b,1)
	b = m.buttons.MAPlo:SetDown(1)
	m.buttons.MAPhi:SetRight(1)
	
	m.buttons.FLAGS:SetDown(b,1)
	b = m.buttons.FLAGSlo:SetDown(1)
	m.buttons.FLAGShi:SetRight(1)
	
	m.buttons.MUSIC:SetDown(b,1)
	m.buttons.SFX:SetDown(1)
	
	m.buttons.romAll:SetDown(1)
		
	-- ram buttons
	m.buttons.Free:SetDown(5)	
	m.buttons.CHARSET:SetDown(1)
	b = m.buttons.charOpt:SetDown(1)
	m.buttons.charAll:SetRight(1)
	
	m.buttons.PAL:SetDown(b,1)
	m.buttons.LABEL:SetDown(1)	
	m.buttons.MAPsettings:SetDown(1)
	
	-- custom-buttons (and update adr)
	b = m.buttons.GFXcustom:SetPos(_rectHexBorder.x - widthColumn * 1, _rectHexBorder.y)
	b.userdata[1] = activePico:SpriteAdr(0,0)	
		
	b = m.buttons.MAPcustom:SetDown(1)
	local adr = activePico:MapAdr(0,0)
	if adr < 0x8000 then
		b.userdata[1], b.userdata[2] = 0x1000,0x2000
	else
		b.userdata[1] = adr
		b.userdata[2] = activePico:MapSize()
	end
		
	b = m.buttons.FlagsCustom:SetDown(1)
	b.userdata[1] = activePico:SpriteFlagAdr(0)
	
	b = m.buttons.MusicCustom:SetDown(1)
	b.userdata[1] = activePico:MusicAdr(0)
	
	b = m.buttons.SFXCustom:SetDown(1)
	b.userdata[1] = activePico:SFXAdr(0)
		
	m.buttons.HI128:SetPos(_rectHexBorder.x - (m.buttons.HI128.rectBack.w +1) * 16 - 5 ,oh - (m.buttons.HI128.rectBack.h + 1) * 8 - 5)
	for i = 0x81,0xff do 
		local b = m.buttons["HI"..i]
		if (i % 16) == 0 then
			b:SetDown( m.buttons["HI"..(i-16)],1)
		else
			b:SetRight( m.buttons["HI"..(i-1)],1)
		end
	end
	
	-- labels
	m.buttons.lROM:SetLeft(m.buttons.GFX)
	m.buttons.lRAM:SetLeft(m.buttons.Free)
	m.buttons.lPOS:SetLeft(m.buttons.GFXcustom)
		
	-- inputs
	m.inputs.sfx:SetPos(_rectHexBorder.x + _rectHexBorder.w + 5 + BARSIZE + 10, topLimit)
	m.inputs.char:SetDown()
	m.inputs.music:SetDown()
	
	-- additional buttons
	for nb, e in pairs(_apiGetRangeButtons) do
		if not e.but then 
			-- create new button, if needed
			e.but = m.buttons:Add("apigetrange"..nb, e.text, 160)
			e.but.OnClick = function (but)
				e.fn(_cursor, _cursorEnd)
			end	
		end
		e.but:SetDown()
	end
	
	-- add action-buttons
	m.buttons.loadBin:SetLeft(m.buttons.lROM,10)
	m.buttons.saveBin:SetDown()
	
end

-- we got the focus
function m.FocusGained(m)
	m:Resize()
end

-- convert mouse position to memory adress in hex-field
local function _MouseToAdr(mx, my)	
	if not SDL.Rect.ContainsPoint(_rectHexText,{mx,my}) then  
		return nil
	end
	
	local w1,h1 = SizeText("1")
	local barPos = m.scrollbar.hex:GetValues()
	local adr = barPos * _LINEBYTES
	local x = (mx - _rectHexText.x + w1 \ 2) \ w1 
	local y = (my - _rectHexText.y) \ h1

	x = (x - 7) \ 3
			
	if x >= 0 and x < _LINEBYTES then			
		return math.clamp(0,0xffff, adr + x + y * _LINEBYTES)
	end
	return nil
end

-- mouse click
function m.MouseDown(m, mx, my, mb, mbclicks)
	if m.lock == nil and mb == "LEFT" then 
		-- select memory in hex-field
		local adr = _MouseToAdr(mx, my)
		if adr then
			if SDL.Keyboard.GetModState():hasflag("SHIFT") == 0 then				
				_cursor = adr			
				_cursorEnd = adr
				_cursorSub = 0
				m.lock = "HEX"
				_CursorVisible(m)
			else
				_cursor = adr		
			end
			
			m.inputs:RemoveFocus()	
		end
	end
end

-- mouse move
function m.MouseMove(m, mx, my, mb)
	if m.lock == "HEX" then 
		local adr = _MouseToAdr(mx, my)
		if adr then
			_cursor = adr			
		end
	end
end

-- mouse up
function m.MouseUp(m, mx,my,mb, mbclicks)
	if mb == "LEFT" and m.lock == "HEX" then
		m.lock = nil
	end
end

-- user enterd text
function m.Input(m, sym)
	if m.lock == nil and not m.inputs.HasFocus() then
		local key = tonumber("0x"..sym)
		if key then	
			if _cursorSub == 0 then
				activePico:Poke(_cursor, (activePico:Peek(_cursor) & 0x0f) | (key << 4) )
				_cursorSub = 1
				_cursorEnd = _cursor
			else
				activePico:Poke(_cursor, (activePico:Peek(_cursor) & 0xf0) | key )
				_cursorSub = 0
				_cursor = math.clamp(0, 0xffff, _cursor +1)
				_cursorEnd = _cursor
			end
		end
	end
end


-- mousewheel to scroll
function m.MouseWheel(m,x,y,mx,my)
	local barPos = m.scrollbar.hex:GetValues()
	m.scrollbar.hex:SetValues(barPos - y)	
end

-- calculate position of an element
local function _PositionHexValue(i)
	return (7 + 3 * (i % _LINEBYTES)),(i\_LINEBYTES)
end
local function _PositionHexCharacter(i)
	return (7 + 3 * _LINEBYTES + 1 + (i % _LINEBYTES)), (i\_LINEBYTES) 
end

-- drawing
function m.Draw(m)
	local ow, oh = renderer:GetOutputSize()
	local w1, h1 = SizeText("1")
	
	-- draw background
	DrawFilledRect(_rectHexBorder, COLBLACK, 255, true)
	
	-- draw hexfield
	renderer:SetClipRect(_rectHexText)
	local x,y = _rectHexText.x, _rectHexText.y
	
	local barPos, barPage = m.scrollbar.hex:GetValues()
	local adr = barPos * _LINEBYTES
	
	local col,col2 = Pico.RGB[7], Pico.RGB[5]
	
	local hasFocus = not m.inputs.HasFocus()
	
	for i = 0, (barPage + 1) * _LINEBYTES -1 do
		if i + adr > 0xffff then break end
		
		-- address - left side
		if (i % _LINEBYTES) == 0 then
			DrawText(x,y + (i\_LINEBYTES) * h1,string.format("%04x: ",adr + i),col)
		end
		
		-- value - middle
		local value = activePico:Peek(adr + i)
		local incursor = math.clamp(adr + i, _cursor, _cursorEnd) == adr + i		
		local xx,yy = _PositionHexValue(i)
		
		-- selection-background, if no input has the focus
		if hasFocus then
			if incursor then
				if adr +i != _cursor then
					DrawFilledRect( {x + xx * w1 - w1 \ 2, y + yy * h1, w1 * 3, h1}, Pico.RGB[2])	
				else
					DrawFilledRect( {x + xx * w1 - w1 \ 2, y + yy * h1, w1 * 3, h1}, Pico.RGB[8])	
				end
			end
		end
		
		-- hex value
		DrawText(x + xx * w1, y + yy * h1, string.format("%02x",value), value==0 and col2 or col)
		
		-- characters - right
		xx,yy = _PositionHexCharacter(i)
		-- background selection
		if hasFocus and incursor then
			DrawFilledRect( {x + xx * w1 , y + yy * h1, w1 , h1}, Pico.RGB[2])	
		end				
		-- hex character
		DrawText(x + xx * w1, y + yy * h1, string.char(value), col )		
	end	
	renderer:SetClipRect(nil)
	
	-- info line
	local ms,me = math.min(_cursor,_cursorEnd), math.max(_cursor,_cursorEnd)
	local s = me - ms + 1	
	
	local str 
	local w,h 	
	
	local v1,v2,v4 = activePico:Peek(_cursor),activePico:Peek2(_cursor) or 0, activePico:Peek4(_cursor) or 0
	local str2 = string.format("%08x",(v4*0x10000)\1)
	
	local v4i = v4 \ 1
	local vs = string.format("%.4f",v4-v4i)
	str = string.format("0x%02x = %03i, 0x%04x = %05i, %s = %05i%s", v1,v1, v2,v2, "0x"..str2:sub(1,4).."."..str2:sub(5),v4i, vs:sub(2))

	w,h = SizeText(str)
	DrawText(_rectInfoValues.x + (_rectInfoValues.w - w) \ 2, _rectInfoValues.y ,str)
	
	-- update range - but only wenn not an input has the focus!
	if hasFocus then
		m.inputs.range.text = string.format("0x%04x, ".. (config.sizeAsHex and "0x%04x" or "%i"), ms,s)
	end
	
	-- update scrollbar
	m.scrollbar.hex:SetValues(nil,nil,nil,_cursor\_LINEBYTES, _cursorEnd\_LINEBYTES)
end

-- copy memory to clipboard as pico8-string
function m.Copy(m)
	local adr,size = math.min(_cursorEnd, _cursor), math.abs(_cursor - _cursorEnd) + 1
	return m:API_CopyHex(adr,size)
end

-- paste clipboard into memory



function m.Paste(m, str)
	local adr,size = math.min(_cursorEnd, _cursor), math.abs(_cursor - _cursorEnd) + 1
	m:API_PasteHex(str, adr, size)
	_CursorVisible(m)
end

m.CopyHex = m.Copy
m.PasteHex = m.Paste


return m