
--[[ todo
	,. <> speed in sfx

	changelog
		v0.94
			-- IMPORTANT -- 
			please delete the old installtion. I removed many files. Don't copy over an existing installation.
			When you want to save your settings, save the jaP8e.ini file
			
			* main - own menm handling
			* main - fix numblock handling
			* main - ctrl+<number> change Module/Editor
			* main - recolor toolbar
			* main - Copy & Paste HEX - Ctrl+shift+c / Ctrl+Shift+v - copy/paste current module complete data as hex-memory-string.
			* main - input fields have now a small cursor
			* lua - shift+ctrl+<number> change view on the left side
			* lua - shift + mouse wheel scroll in x direction
			* label - add flip, rotate, shift
			* font - adjustment on grid
			* font - chars with the attribute "oneup" become "light-peach" instead of "white"
			* pattern - flip, rotate, shift and invert option
			* hex - rename sfx to sound
			* sprite/map - ctrl + click on the right area will exchange the color
			* luatic - removed many dlls. switch to opengl

			
			New Keyboard-Shortcuts (when this function exist in the module/editor)
				A/- = cursor left
				D/=/+ = cursor right
				W = cursor up
				S = cursor down
				
				< = slower
				> = faster
								
				SHIFT + A/- = select cursor left
				SHIFT + D/=/+ = select cursor right
				SHIFT + W = select cursor up
				SHIFT + S = select cursor down
				
				Q = previous color
				E = next color
				` = Color 0
				SHIFT + ` = Color 10
				0 - 9 = Color 0 - 9
				SHIFT + 0 - 5 = Color 10 - 15				
				
				R = rotate left
				T = rotate right
				F = flip x
				V = flip y
				I = invert
				LEFT/RIGHT/UP/DOWN = shift left/right/up/down
				
				STRG+H = show id/hex in area
				STRG+G = show grid in area
				STRG+F = show flags in area
				
				STRG+SHIFT+H = show id/hex in left overview
				STRG+SHIFT+G = show grid in left overview
				STRG+SHIFT+F = show flags in left overview
			
		
		v0.93
			* lua - fix background bug
			* lua - display width of the selected text in pixels. 
			* lua - coloring-bug with "\\\\"
			* hex/font - remove double quotes on pasted strings
			* hex - add font settings / chars under ram
			* main - renamed charset to font
			* main - workaround for a bug in sdl2 with the right alt/gr-key in german keyboard layout
			* main - when you save a cart in pico-89 with "save @clip" you can past it now in jaP8e
		
		v0.92
			* luatik - two executables - luatik.com for consoles and luatik.exe for windows
			* fillp - new Module - easy editing of fill patterns.
			* new dither option
			* lua - zoomable text and you can choose between the custom font and the build in font
			* lua - build in font now inverts lower/upper case (like the custom font)
			* main - Update charset.png - chars over 127 will now double wide in lua-editor
			
		v0.91
			* lzh - fix bug where lzh pack to 0 instead of base adr.
			* main - stop spaming empty lines while running a p8
			* main - fix possible endless write protect.
			* main - update decompressing code for .p8.png and .p8.rom 
			* main - alt / f10 controls now the menu bar
			* lua - alt + up / down doesn't work any more - use ctrl + up/down
			* lua - ctrl + m plays the music/sfx, not alt+space
			* main - jaP8e is now a windows application. In Debug-Menu you can open a console.
			* main - remove link and start.bat, add a "starter"-execute
			* main - new icon :)
						
		
	
	[gfx]0808000000000888888088888888888ffff888f1ff1808fffff00033330000700700[/gfx]
	
		 pattern
		 | music
		 | |
	[sfx]0402

		Patternnr.
		|
		15 4a084a064a045106510451025b085b06582a58285826530853085306530453024f084f064f0451065104510256285626530a530853065304530253025302530000200020 <-speicherformat
		0a c15f8051c15fc151a35bc15f81518051c15f8051c1518751a35b8051c15f8051c15fc151c15f8051a35bc15f81518051c15f8051a5518151a35ba551c15fa35b01100020
		16 ee0bf70bee07f707ee05f705ee03f703e20beb0be207eb07dd0be40bdd07e407df0be70bdf07e707df05e705e90bf00be907f007e905f005e903f003e903f00300100020
		0c 070e070c070a1100070e070c031a0f0e0a0e0a0c0a0a0a000a0e0a0c050a0508030e030c0300030a0c0e0c0c110a160e160c0f1e050a0a0e050a031a0a0e0a0c00100000 
	
		
		15 0a 56 44 1 <- format p8, aber erste byte zuletzt!
		0a 16 0c 44 0[/sfx]
		
	[sfx]0100 
		00 f60e230fef0e1d0fea0e170fe70e130fe30e110fde0e0e0fda0c0c0dd60a0809d20605059901990199019901bf01bf01bf01bf01bf01bf01bf01bf01bf01bf0100020000[/sfx]
	
	
--]]



-- Menu zoom-level and pixel-size
zoomLevels = { 
	{"zoom05", 4, "0.5"}, 
	{"zoom1", 8, "1"}, 
	{"zoom2", 16, "2"}, 
	{"zoom3", 24, "3"}, 
	{"zoom4", 32, "4"}, 
	{"zoom5", 40, "5"}, 
	{"zoom6", 48, "6"}, 
	{"zoom7", 56, "7"}, 
	{"zoom8", 64, "8"}, 
	{"zoom9", 72, "9"}, 
	{"zoom10", 80, "10"} 
	}
PICOTEXTZOOM = 4

-- some globals

activePico = nil		-- pico-object
window = nil	-- main window
renderer = nil	-- renderer of main window
topLimit = nil
mx, my = 0, 0 -- mouse cursor
hasFocus = false -- main window has focus

cursorArrow = nil
cursorHand = nil

-- some constants

TITLE = "jaP8e"
VERSION = "0.94 BETA"
-- min size of the main window
MINHEIGHT = 667
MINWIDTH = 1306
-- size of the scrollbars
BARSIZE = 10

-- toolbar colors
local _TOOLBARBACK = 6
local _TOOLBARBUTTONBACK = 140
local _TOOLBARBUTTONHIGH = 12


-- some filters for fileselect-box
FILEFILTERIMAGE = "image|*.png;*.bmp;*.jpg|format png|*.png|format bmp|*.bmp|format jpg|*.jpg|all|*.*"
FILEFILTERPICOLOAD = "pico8|*.p8.png;*.rom;*.p8|all|*.*"
FILEFILTERPICOSAVE = "pico8|*.p8|all|*.*"
FILEFILTERROM = "rom|*.rom|all|*.*"
FILEFILTEREXPORT = "Binary|*.bin|Cartridge|*.p8.png;*.p8.rom|html|*.html;*.js|wasm|*.wasm|all|*.*"
FILEFILTERLUA = "Lua|*.lua|Text|*.txt|all|*.*"
FILEFILTEREXECUTE = "Executeable|*.exe|all|*.*"

-- some colors
COLBLACK 		= {r=0x00, g=0x00, b=0x00, a=0xff}
COLWHITE 		= {r=0xff, g=0xff, b=0xff, a=0xff}
COLDARKWHITE 	= {r=0xaa, g=0xaa, b=0xaa, a=0xff}
COLDARKGREY 	= {r=0x19, g=0x19, b=0x19, a=0xff}
COLGREY 		= {r=0x33, g=0x33, b=0x33, a=0xff}
COLLIGHTGREY 	= {r=0x66, g=0x66, b=0x66, a=0xff}
COLRED 			= {r=0xFF, g=0x00, b=0x00, a=0xff}
COLBLUE 		= {r=0x29, g=0xAD, b=0xFF, a=0xff}
COLLIGHTBLUE	= {r=0x59, g=0xDD, b=0xFF, a=0xff}
COLGREEN		= {r=0x29, g=0xFF, b=0xad, a=0xff}

--===================================================================
-----------------------------------------------------------------MISC
--===================================================================

function PrintDebug(...)
	--if config.debug then
	return print(...)
	--end
end

-- light or dark the a color
function ColorOffset(c,offset)
	if c == nil then return nil end
	return {
		r = math.clamp(0,(c.r + offset), 0xff),
		g = math.clamp(0,(c.g + offset), 0xff),
		b = math.clamp(0,(c.b + offset), 0xff),
		a = c.a
	}
end

-- seperate path (with final \), filename, (with dot)extension
function SplitPathFileExtension(file)
	local a,b = file:match("(.-)([^\\/]*)$")
	return a, b:match("([^%.]*)(.-)$")
end

-- Request a file name for saving, add extension if missing
function RequestSaveFile(window, title, preselect, filter)
	local file,index = SDL.Request.SaveFile(window, title, preselect, filter, 1, "OVERWRITEPROMT")

	if file != nil then 
		local path,name,extension = SplitPathFileExtension(file)

		if extension == "" then 
			-- search throug the filter for the matching pattern. always use the first extension
			local nb,mainExtensionOne = 1, ""
			for name,star,mainExtension,additional in filter:gmatch("([^|]+)|([^|;%.]*)([^|;]+)([^|]*)") do
				-- on "all"-Filter, we use the one from the first pattern
				if nb == index then
					extension =  mainExtension == ".*" and mainExtensionOne or mainExtension
					break
				elseif nb == 1 then
					mainExtensionOne = mainExtension
				end
				nb += 1
			end
			file = path .. name .. extension
		end
	end
	return file, index
end

-- Request a file name for opening, must exist
function RequestOpenFile(window, title, preselect, filter)
	return SDL.Request.OpenFile(window, title, preselect, filter , 1, "MUSTEXIST")
end	

-- handle global errors
local function _ErrorMessageHandler(err)
	-- output traceback
	PrintDebug("[ERROR]", err)		
	PrintDebug(debug.traceback())
	SDL.Request.Message(window,TITLE,"Critical error catched.'\n" .. tostring(err),"OK STOP") 
	popup:ForceClose()
	return err
end

-- call a function and grab error, return false,error or true,ret1,ret2,ret3,ret4,ret5,ret7,ret8
function SecureCall(fn,...)
	local ok,a,b,c,d,e,f,g,h = xpcall(fn, _ErrorMessageHandler, ...)
	if ok then
		return a,b,c,d,e,f,g,h
	end
	return nil
end

--===================================================================
---------------------------------------------------------------Config
--===================================================================

configFile = ".\\jaP8e.ini"	

-- default config
config = {
	doAutoOverviewZoom = true, -- automatic change zoom for sprite, charset, label
	fpsCap = 30, -- limit fps to 30fps
	doRemote = false, -- allow pico remote
	jpgQuality = 90, -- exported jpg quality
	doDithering = false, -- dither imported images
	doDitheringFloydSteinberg = false, -- use Floyd-Steinberg for dithering
	doColorOptimization = false, -- choose best matching colors for imported images
	doGreyScale = false, -- greyscale image before importing
	saveTransparentBlack = false, -- save color 0/black as transparent
	pico8execute = "", -- pico8 execute file
	pico8parameter = "", -- additional paramter for running
	cursorBlink = 60, -- cursor blink rate
	writeProtectedPico8 = true, -- while running white protect editor
	sizeAsHex = true, -- display size values as hex or dezimal
	debug = false,
	
}

-- comments in the config file, when the parameter doesn't exist
configComment = {
	doAutoOverviewZoom = "automatic change zoom for sprites and charset",
	fpsCap = "Limit the frames per second",	
	doRemote = "use Pico-8 for sound playback",
	jpgQuality = "Quality of the JPG from 0-100",
	doDithering = "Dither imported images",
	doDitheringFloydSteinberg = "when dithering, use Floyd-Steinberg",
	doColorOptimization = "Create a custom palette for imported sprite sheets",
	doGreyScale = "Convert Image to B/W before importing",
	saveTransparentBlack = "Should black transparent in exported images?" ,
	pico8execute = "path and name to the pico-8 executable",
	pico8parameter = "additional parameter before starting pico8 / remote. --run is already in use!",	
	cursorBlink = "cursor blink rate",
	writeProtectedPico8 = "Write protect project when it is running",
	sizeAsHex = "use hex values for size",
	debug = "Display debug messages in console window",
}

-- phrase "key = value" strings
local function _ConfigGetKeyValue(line)
	-- String? key = "value"
	local key, value = line:match("%s*([%w_]+)%s*=%s*\"(.*)\"%s*")
	if key and value then
		-- decode escape-sequenz
		value = value:unescape()
	
	else 
		-- no, then a number or true/false
		key, value = line:match("%s*([%w_]+)%s*=%s*([%w_%.%+%-]+)%s*")
		if key == nil or value == nil then
			return nil,nil
		end
		
		-- boolean-correction
		if value == "false" then 
			value = false
		elseif value == "true" then
			value = true
		else
			-- otherwise a number or 0
			value = tonumber(value) or 0 -- make sure, that a number is stored
		end				
	end		
	return key, value
end

-- format a key = value string
local function _ConfigKeyValue(key,value)
	local str = key .. " = "
	if type(value) == "string" then
		str ..= "\"" .. value:escape() .. "\""
	else
		str ..=  tostring(value)
	end
	return str
end

-- load a config file
function ConfigLoad(file)
	local fin, err = io.open(file,"r")
	if fin == nil then return false end
	
	for line in fin:lines("l") do
		-- lines start with * # are comments
		if line != "" and line:sub(1, 1) != "*" and line:sub(1, 1) != "#" then
			local key,value = _ConfigGetKeyValue(line)			
			if key != nil and value != nil then -- value can be false -> test with != nil
				config[key] = value	
			end
		end
	end
	
	fin:close()
end

-- save a config file
function ConfigSave(file)

	-- copy config
	local cwrite = table.copy(config)
	
	-- read an existing file and check, if it has changed
	lines = {}	
	local changed = false
	
	local fin, err = io.open(file,"r")
	if fin!= nil then 
		for line in fin:lines("l") do
			-- * # are comments
			if line != "" and line:sub(1, 1) != "*" and line:sub(1, 1) != "#" then
				-- check if line is valid
				local k,v = _ConfigGetKeyValue(line)
				if k == nil or v == nil then -- v could be false -> nil-check
					-- line is invalid -> convert to comment
					line = "# "..line
					changed = true
					
				elseif cwrite[k] != nil then
					-- update if exist
					if cwrite[k] != v then
						line = _ConfigKeyValue(k, cwrite[k])		
						changed = true						
					end
					-- remove key from "to write" list
					cwrite[k] = nil 
				end
			end
			table.insert(lines, line)			
		end
		fin:close()
	end
			
			
	-- add remaining keys
	local sortedList = {}
	for key, value in pairs(cwrite) do
		table.insert(sortedList,{key=key,value=value})
	end
	
	table.sort(sortedList, function(a,b) return a.key < b.key end)
	
	for nb,d in pairs(sortedList) do
		table.insert(lines,"")
		if configComment[d.key] then
			table.insert(lines,"# " .. tostring(configComment[d.key] ))
		end
		table.insert(lines, _ConfigKeyValue(d.key,d.value))
		changed = true
	end
	
	-- write file
	if changed then 
		local fout, err = io.open(file,"w")
		if fout then 
			for nb,line in pairs(lines) do
				fout:write(line .. "\n")
			end
			fout:close()
		else
			SDL.Request.Message(window, TITLE .. "v" .. VERSION, "Can't save config.\n"..err, "OK STOP")
		end
	end
	
end
	

--===================================================================
--------------------------------------------------------------Drawing
--===================================================================	

local _drawTextureChar = nil
local _drawRectChar = {x = 0, y = 0, w = 0, h = 0}
local _drawRectCharSource = {x = 0, y = 0, w = 0, h = 0}
local _drawTextureChar2 = nil
local _drawRectChar2 = {x = 0, y = 0, w = 0, h = 0}
local _drawRectChar2Source = {x = 0, y = 0, w = 0, h = 0}
local _drawTextureGradient = nil
local _drawTextureColor = nil

-- initalize draw routines - create textures
function DrawInit()
	-- load small characterset
	_drawTextureChar = renderer:LoadTexture("charset.png")
	if _drawTextureChar == nil then return false end	
	_, _, _drawRectCharSource.w, _drawRectCharSource.h = _drawTextureChar:Query()
	_drawRectCharSource.w \= 16
	_drawRectCharSource.h \= 16
	_drawRectChar.w = _drawRectCharSource.w \ 2
	_drawRectChar.h = _drawRectCharSource.h
	
	-- load big characterset
	_drawTextureChar2 = renderer:LoadTexture("charset3.png")
	if _drawTextureChar2 == nil then return false end
	_, _, _drawRectChar2Source.w, _drawRectChar2Source.h = _drawTextureChar2:Query()
	_drawRectChar2Source.w \= 16
	_drawRectChar2Source.h \= 16
	_drawRectChar2.w = _drawRectChar2Source.w \ 2
	_drawRectChar2.h = _drawRectChar2Source.h
			
	-- color-textures
	local surface = SDL.Surface.CreateRGB(2,2,"RGBA32")
	if surface == nil then return false end
	
	-- create a white texture, changed by colormod
	surface:FillRect(nil, surface:GetPixelFormat():MapRGBA(0xff, 0xff, 0xff, 255))	
	_drawTextureColor = renderer:CreateTexture(surface)
	if _drawTextureColor == nil then return false end

	-- create a white gradient texture, color changed by colormod
	surface:FillRect({1,0,1,1}, surface:GetPixelFormat():MapRGBA(0xdd, 0xdd, 0xdd, 255))
	surface:FillRect({0,1,1,1}, surface:GetPixelFormat():MapRGBA(0xbb, 0xbb, 0xbb, 255))
	surface:FillRect({1,1,1,1}, surface:GetPixelFormat():MapRGBA(0x99, 0x99, 0x99, 255))	
	_drawTextureGradient = renderer:CreateTexture(surface)
	if _drawTextureGradient == nil then return false end
	
	_drawTextureGradient:SetScaleMode("BEST")
	
	surface:Free()
	return true
end

-- free up all textures
function DrawQuit()
	if _drawTextureChar then
		_drawTextureChar:Destroy()
		_drawTextureChar = nil
	end
	if _drawTextureChar2 then
		_drawTextureChar2:Destroy()
		_drawTextureChar2 = nil
	end
	if _drawTextureColor then
		_drawTextureColor:Destroy()
		_drawTextureColor = nil
	end
	if _drawTextureGradient then
		_drawTextureGradient:Destroy()
		_drawTextureGradient = nil
	end	
end

-- draw filled rect
function DrawFilledRect(rect, col, alpha, gradient)
	local tex = gradient and _drawTextureGradient or _drawTextureColor
	tex:SetAlphaMod(alpha or col.a)
	tex:SetBlendMode("BLEND")
	tex:SetColorMod(col.r, col.g, col.b) -- recolor white texture
	renderer:Copy(tex,nil,rect)
end

-- draw a rect
function DrawRect(rect, col, alpha, gradient)
	local tex = gradient and _drawTextureGradient or _drawTextureColor
	tex:SetAlphaMod(alpha or col.a)
	tex:SetBlendMode("BLEND")
	tex:SetColorMod(col.r, col.g, col.b) -- recolor white texture	
	-- draw top & bottom
	local r = {x = rect[1] or rect.x, y = rect[2] or rect.y, w = rect[3] or rect.w, h = 1}
	renderer:Copy(tex,nil,r)
	r.y += (rect[4] or rect.h) - 1
	renderer:Copy(tex,nil,r)
	-- draw left & right
	r = {x = rect[1] or rect.x, y = (rect[2] or rect.y) + 1, w = 1, h = (rect[4] or rect.h) - 2}
	renderer:Copy(tex,nil,r)
	r.x += (rect[3] or rect.w) - 1
	renderer:Copy(tex,nil,r)
end	

-- draws a border - 3 pixel width outside (black, color, black)
function DrawBorder(x, y, w, h, col)
	DrawRect({x - 1, y - 1, w + 2, h + 2}, COLBLACK)
	DrawRect({x - 3, y - 3, w + 6, h + 6}, COLBLACK)
	DrawRect({x - 2, y - 2, w + 4, h + 4}, col)
end

-- draws a border in a grid. 
function DrawGridBorder(bx, by, x1, y1, x2, y2, size, col, outputSize)
	if x1 > x2 then x1,x2 = x2,x1 end 
	if y1 > y2 then y1,y2 = y2,y1 end
	local x, y = bx + x1 * size, by + y1 * size
	local w, h = (x2 - x1 + 1) * size, (y2 - y1 + 1) * size
	
	DrawBorder(x, y, w, h, col)
	
	if outputSize then
		DrawText( x + w + 2, y + h + 2, string.format("(%02i,%02i)",x2 - x1 + 1, y2 - y1 + 1),col)
	end
	
end

-- draw two-digit hex number
function DrawHex(x,y,value,col,count)
	return DrawText(x,y, string.format("%0"..(count or 2).."x",value),col)
end

-- draw a Char
function DrawChar(x,y,char,col,zoom,f)
	local _rect = f == 1 and _drawRectCharSource or _drawRectChar2Source
	local _tex = f == 1 and _drawTextureChar or _drawTextureChar2

	local w,h = _rect.w , _rect.h 
	
	if char < 0x80 then
		w /= 2
	end	
	
	if char != 32 and char != nil and char != 9 and char != 0xa then
		_rect.x = _rect.w * (char & 0xf)
		_rect.y = _rect.h * (char >> 4)
		_tex:SetColorMod(col.r,col.g,col.b)
		_tex:SetScaleMode(zoom < 1 and "BEST" or "NEAREST")
		renderer:Copy(_tex,{_rect.x, _rect.y, w, _rect.h},{x,y, w * zoom ,h * zoom})
	end
	return x + w * zoom, y + h * zoom
end

-- draw a text
function DrawText(x,y,text,col,size)
  
	col = col or COLWHITE
	text = tostring(text)

	local rect, rectSrc, tex
	if size == nil or size == 1 then
		-- small font
		rect = _drawRectChar
		rectSrc = _drawRectCharSource
		tex = _drawTextureChar
	else
		-- big font
		rect = _drawRectChar2
		rectSrc = _drawRectChar2Source
		tex = _drawTextureChar2
	end
	
	-- round coordinates
	rect.x = x \ 1
	rect.y = y \ 1	
	
	tex:SetBlendMode("BLEND")
	tex:SetColorMod(col.r,col.g,col.b)
	
	local startX = rect.x
	for i = 1, #text do
		local char = text:byte(i)
		
		if char == 10 then
			-- linefeed
			rect.x = startX
			rect.y += rect.h
		else
			-- don't draw a space
			if char != 32 and char != 9 then
				rectSrc.x = rectSrc.w * (char & 0xf)
				rectSrc.y = rectSrc.h * (char >> 4)
				local w = char >= 0x80 and rectSrc.w or rectSrc.w\2
								
				renderer:Copy(tex,{rectSrc.x, rectSrc.y, w, rectSrc.h},rect)
			end
			
			rect.x += rect.w
		end
	end
	
	
	-- return next position in pixels
	return rect.x, rect.y + rect.h
	
	
end

-- size of a text in pixel
function SizeText(text,size)
	text = tostring(text)
	local rectSrc	
	if size == nil or size == 1 then
		rectSrc = _drawRectChar
	else
		rectSrc = _drawRectChar2
	end
	
	if text:find("\n") then	
		local t = text:split("\n")
		local w = 0
		for _,str in pairs(t) do
			w = math.max(w, #str)
		end
			
		return w * rectSrc.w, #t * rectSrc.h 
	else
	
		return #text * rectSrc.w, rectSrc.h 
	end
end

-- draw a text with the pico-font in memory
function DrawPicoText(x,y,text,col)
	text = tostring(text)
	x = x \ 1
	y = y \ 1
	local lw,hw,h = activePico:Peek(Pico.CHARSET) , activePico:Peek(Pico.CHARSET+1), activePico:Peek(Pico.CHARSET+2)
	local rect = {x = x, y = y, w = 0, h = math.min(h,8) * PICOTEXTZOOM}
	local src = {x = 0, y = 0, w = 0, h = math.min(h,8)}
	
	local tex = TexturesGetCharset()	
	tex:SetAlphaMod(255)
	tex:SetBlendMode("BLEND")	
	col = col or COLWHITE
	
	local adjEnable = (activePico:Peek(Pico.CHARSET + 5) & 1) == 1
	
	for i = 1, #text do
		local char = text:byte(i)
		local offw, offy = 0,0
		if char > 0 then
			if adjEnable then
				local adj, oneup = activePico:CharsetGetVariable(char)
				offw = adj
				offy = oneup and -1 or 0				
			end		
		
			tex:SetColorMod(col.r,col.g,col.b)
			src.x = (char & 0xf) * 8
			src.y = (char >> 4) * 8
			src.w = math.clamp(0,8, (char < 0x80 and lw or hw) + offw) -- only 8 drawable pixels are avaiable
			
			
			rect.w = src.w * PICOTEXTZOOM
			rect.y += offy * PICOTEXTZOOM
			renderer:Copy(tex,src,rect)
			rect.y -= offy * PICOTEXTZOOM
						
		end
		rect.x += ((char < 0x80 and lw or hw) + offw) * PICOTEXTZOOM
	end
	return rect.x, rect.y + h * PICOTEXTZOOM
end

-- size of a text in pico-font
function SizePicoText(text)
	text = tostring(text)
	local lw,hw,h = activePico:Peek(Pico.CHARSET) , activePico:Peek(Pico.CHARSET+1), activePico:Peek(Pico.CHARSET+2)
	local x = 0
	
	local adjEnable = (activePico:Peek(Pico.CHARSET + 5) & 1) == 1
	
	for i = 1, #text do
		local char = text:byte(i)
		local offw = 0
		if adjEnable then
			offw,_ = activePico:CharsetGetVariable(char)
		end
		
		x += ((char < 0x80 and lw or hw) + offw) * PICOTEXTZOOM
	end
	return x, h * PICOTEXTZOOM
end


--===================================================================
-------------------------------------------------------------FilesTab
--===================================================================

local _filesCount = 0 -- for generating new00 - names
local _filesTab ={} -- all open files
local _filesActive = nil -- current open file-tab

-- intialize
function FilesInit()
	buttons:Add("filesAdd","+",nil,nil,nil,Pico.RGB[_TOOLBARBUTTONHIGH], Pico.RGB[7],Pico.RGB[_TOOLBARBUTTONBACK])
	buttons:Add("filesClose","X",nil,nil,nil,Pico.RGB[_TOOLBARBUTTONHIGH], Pico.RGB[7],Pico.RGB[_TOOLBARBUTTONBACK])
	buttons.filesAdd.OnClick = function(but) FilesNew() end
	buttons.filesClose.OnClick = function(but) FilesRemove() end
	return true
end

-- quit
function FilesQuit()
	-- remove all files
	while FilesRemove(true) do
	end
	-- remove buttons
	if buttons.filesAdd then
		buttons:Remove(buttons.filesAdd)
	end
	if	buttons.filesClose then
		buttons:Remove(buttons.filesClose)
	end
end

-- called when the filename needs to change on undo/redo
local function _FilesUndoName(file)
	local ret = _filesActive.file 
	_filesActive.file = file	
	local path, filename, extension = SplitPathFileExtension(file)
	_filesActive.but:SetText(filename,true)
	return ret
end

-- new file tab
function FilesNew()
	_filesCount += 1	
	local id = "files".. _filesCount
	local but = buttons:Add(id, "New".._filesCount,nil,nil,"_filesTab", Pico.RGB[_TOOLBARBUTTONHIGH], Pico.RGB[7],Pico.RGB[_TOOLBARBUTTONBACK])
	table.insert( 
		_filesTab, 
		{
			id = id,
			but = but,
			file = "New".._filesCount,
			pico = Pico.Create(renderer)
		}
	)
	but.index = id
	but.OnClick = function(but,x,y)
		FilesActivate(but.id)		
	end
	but.tooltip = file
	but.shrinkOnDeselected = true
	FilesActivate(id)
end

-- open a file in the current or new tab
function FilesOpen(file, forcepng)
	local doRemoveOnError = false
	
	if file == nil then
		file = RequestOpenFile(window, "Open", _filesActive.file or "unnamed.p8", FILEFILTERPICOLOAD)
		if file == nil then return false end
	end
	
	-- new tab needed?
	if _filesActive == nil or not activePico:IsEmpty() then 
		FilesNew() 
		doRemoveOnError = true 
	end
	
	ModulesCall("FocusLost")
	
	local ok, err 
	
	local path,filename,extension = SplitPathFileExtension(file)
	extension = extension:upper()
	
	-- load the file depending on the extension
	if extension == ".P8.PNG" or extension == ".PNG" or forcepng then
		ok,err = activePico:LoadP8PNG(file)
	elseif extension == ".ROM" or extension == ".P8.ROM" then
		ok,err = activePico:LoadRom(file)
	else
		ok,err = activePico:LoadP8(file)
	end
	
	if ok then
		-- all fine
		InfoBoxSet(filename.." loaded.")
		
		-- update button
		_filesActive.but:SetText(filename,true)
		_filesActive.but.tooltip = file
		
		-- add undo on filename
		if _filesActive.file != file then
			activePico:UndoSetCustom("_filename",_FilesUndoName,_filesActive.file)
			_filesActive.file = file
		end
		
		-- set save-point and resize everything
		activePico:SetSaved()
		ModulesCall("FocusGained")		
		MainWindowResize()		
		
		return true
		
	else
		-- something went wrong!
		SDL.Request.Message(window,TITLE,"Can't load.\n"..err,"OK STOP")		
		ModulesCall("FocusGained")
		
		if doRemoveOnError then
			-- possible that the file was partly loaded, make sure that it will be removed
			activePico:SetSaved() 
			FilesRemove()
		end		
		return false
	end
end

-- reload
function FilesReload()
	if activePico.writeProtected then 
		InfoBoxSet("Writeprotection is enabled!")
		return false 
	end
	
	local path,filename,extension = SplitPathFileExtension(_filesActive.file)
	if path == "" then -- no path means, that the file was never saved
		InfoBoxSet("Save file first.")
		return false
	end
	
	-- Create a new undo-state, if changes are in the buffer
	activePico:UndoAddState()
	
	-- reload file
	extension = extension:upper()
	if extension == ".P8.PNG" or extension == ".PNG" then
		ok,err = activePico:LoadP8PNG(_filesActive.file)
	elseif extension == ".ROM" or extension == ".P8.ROM" then
		ok,err = activePico:LoadRom(_filesActive.file)
	else
		ok,err = activePico:LoadP8(_filesActive.file)
	end
	
	if ok then
		InfoBoxSet(filename.." reloaded.")		
		activePico:SetSaved()
		MainWindowResize()
		return true
		
	else
		SDL.Request.Message(window,TITLE,"Can't reload.\n"..err,"OK STOP")
		return false
	end
	
end

-- save a file
function FilesSave(fastsave)
	if activePico.writeProtected then 
		InfoBoxSet("Writeprotection is enabled!")
		return false 
	end

	local file
	
	-- use existing filename - if it fit
	if fastsave then
		local path, name, extension = SplitPathFileExtension(_filesActive.file  or "unnamed")
		if path != "" and extension:upper() == ".P8" then
			file = _filesActive.file
		end
	end
		
	-- ask for a filename
	if file == nil then
		-- make sure, that it have the right extension! (could be .p8.png or .rom)
		local path, name, extension = SplitPathFileExtension(_filesActive.file  or "unnamed")
		file = path..name..".p8"
		file = RequestSaveFile(window, "Save as",file, FILEFILTERPICOSAVE)
		if file == nil then return false end
	end
	
	-- and save
	local ok, err = activePico:Savep8(file)
	if ok then
		local path, filename, extension = SplitPathFileExtension(file)				
		InfoBoxSet(filename.." saved.")
		-- update button
		_filesActive.but:SetText(filename,true)
		_filesActive.but.tooltip = file
		-- set undo-filename when it has changed
		if _filesActive.file != file then
			activePico:UndoSetCustom("_filename", _FilesUndoName, _filesActive.file)
			_filesActive.file = file
		end
		-- mark file has saved and resize everything
		activePico:SetSaved()
		MainWindowResize()
		return true
	else
		-- could not save!
		SDL.Request.Message(window,TITLE,"Can't save.\n"..err,"OK STOP")
		return false
	end	
end

-- activate a file tab
function FilesActivate(id)
	for nb,op in pairs(_filesTab) do
		if op.id == id or id=="*" then
			-- send a lost message for modules
			if _filesActive then
				ModulesCall("FocusLost")
			end
			
			-- and activate
			_filesActive = op
			activePico = op.pico
			buttons:SetRadio(op.but)
			
			-- send Gained message for modules
			ModulesCall("FocusGained")	
			MainWindowResize()
			break
		end
	end	
end

-- check if file is saved (or ask to save)
function FilesCheckSaved()

	if not activePico:IsSaved() then
		local path, name, extension = SplitPathFileExtension( _filesActive.file )
		local ret = SDL.Request.Message(window, TITLE, "Save file '" .. name .. "' ?","YESNOCANCEL QUESTION DEFAULT3")
		if ret == "YES" then
			-- simple save it - if it fails return false
			return FilesSave(true)
			
		elseif ret == "NO" then
			-- user don't want to save -> return true because user accept losing it
			return true
		else
			-- cancel - return false, stop !
			return false
		end
	else
		-- file is saved, return true
		return true
	end
end

-- ask user to save file and then remove it (and destroy button and pico)
-- donCreateNew - always remove (even when unsave)
function FilesRemove(dontCreateNew)
	if activePico.writeProtected then 
		InfoBoxSet("Writeprotection is enabled!")
		return false 
	end
	
	for nb,op in pairs(_filesTab) do
		if op.id == _filesActive.id then
			if dontCreateNew or FilesCheckSaved() then
				-- remove it
				table.remove(_filesTab,nb)
				buttons:Remove(op.but)
				op.pico:Destroy()
				-- new tab needed?
				if #_filesTab < 1 then
					if not dontCreateNew then
						FilesNew()
						return true
					end
					-- return false to indicate, that no files are present any more!
					return false
				else
					-- activate first file
					FilesActivate("*")
					return true
				end
			end
			
			break			
		end
	end
	
	return false
end

-- check is all files are save (or ask to save)
function FilesCheckAllSaved()
	local oldId = _filesActive.id
	for nb, op in pairs(_filesTab) do
		FilesActivate(op.id)
		if not activePico:IsSaved() then
			-- redraw window, so the user can peek on the file
			MainWindowDraw()
			if not FilesCheckSaved() then
				-- user has canceld or file couldn't save
				FilesActivate(oldId)
				return false
			end		
		end
	end
	FilesActivate(oldId)
	return true
end

-- reposition files-buttons
function FilesSetPosition(rightX, y)
	buttons.filesClose:SetPos(rightX - buttons.filesClose.rectBack.w, y)
	for nb,op in pairs(_filesTab) do
		op.but:SetLeft()	
	end
	buttons.filesAdd:SetLeft()		
end

-- check "issaved" status and update file-tab-text
function FilesCheckUpdate()
	local reposition = false
	for nb, file in pairs(_filesTab) do
		if file.saved != file.pico:IsSaved() then
			-- status has changed - update
			file.saved = file.pico:IsSaved()
			local path, filename, extension = SplitPathFileExtension(file.file)
			if not file.saved then filename ..= "*" end
			file.but:SetText(filename,true)
			reposition = true
		end
	end
	-- update tab positions
	if reposition then
		local l = buttons.filesClose
		for nb,op in pairs(_filesTab) do
			l = op.but:SetLeft(l)	
		end
		buttons.filesAdd:SetLeft()		
	end
end

-- execute file with pico8
function FilesRun()
	if not FilesSave(true) then 
		InfoBoxSet("Please save file first.")
		return false 
	end
	if not config.pico8execute or config.pico8execute == "" then 
		InfoBoxSet("Pico-8 execute is unknown.")
		return false 
	end
	if _filesActive.process then
		InfoBoxSet("Pico-8 is allready running.")
		return false
	end
	
	-- execute pico-8
	local path,name,extension = SplitPathFileExtension(config.pico8execute)
	local cmd = '"'..config.pico8execute..'" '..'-run "'.._filesActive.file..'" ' .. (config.pico8parameter or "")
	PrintDebug(cmd)
	_filesActive.process = TinyProcess.Open(cmd, path, false)
	
	
	if not _filesActive.process:IsRunning() then
		-- is not running any more
		_filesActive.process:Close()
		_filesActive.process = nil
		
	elseif config.writeProtectedPico8 then
		activePico.writeProtected = true
		InfoBoxSet("Write protection enabled.")
	else
		InfoBoxSet("Pico-8 is running.")
	end
	return true
end

-- check if pico8 is running, update output and remove writeprotection/reload if needed
function FilesCheckRunning()
	if not _filesActive.process then return end

	-- read output
	local text = _filesActive.process:Read()
	if text then
		if text:sub(-1)== "\n" then text = text:sub(1,-2) end
		if text:trim() != "" then PrintDebug("[pico8 stdin]",text) end
	end
	
	text = _filesActive.process:ReadError()
	if text then
		if text:sub(-1)== "\n" then text = text:sub(1,-2) end
		if text:trim() != "" then PrintDebug("[pico8 error]",text) end
	end

	if  not _filesActive.process:IsRunning() then
		-- is not running any more
		_filesActive.process:Close()
		_filesActive.process = nil
		activePico.writeProtected = false
		if config.writeProtectedPico8 then
			FilesReload()
			InfoBoxSet("Write protected disabled and reloaded.")
		else
			InfoBoxSet("Pico8 has closed.")
		end
	end
end

-- use pico-8 export functions
function FilesExport()
	if not FilesSave(true) then 
		InfoBoxSet("Please save file first.")
		return false 
	end
	if not config.pico8execute or config.pico8execute == "" then 
		InfoBoxSet("Pico-8 execute is unknown.")
		return false 
	end

	-- ask for filename and what to do
	local path,filename,extension = SplitPathFileExtension(_filesActive.file)
	local file = RequestSaveFile(window, "Export",filename, FILEFILTEREXPORT)
	
	if file == nil or file == "" then return false end
	
	local para = ""	
	path,filename,extension = SplitPathFileExtension(file)
	filename = filename:gsub(" ","_")-- we need to replace spaces!
	
	if extension == ".html" then
		-- html -> option -f for folder
		para = "-f "
		
	elseif extension == ".wasm" then
		-- wasm -> correct extension and add -w
		extension = ".html"
		para = "-w "
		
	elseif extension == ".bin" then
		-- get binaryOptions from activePico - for example the icon is stored here!
		para = activePico:SaveDataGet("pico8","binaryOptions") or ""
		if para != "" and para:sub(-1) != " " then para ..=" " end
	end
	
	-- execute pico-8
	local process = TinyProcess.Open('"'..config.pico8execute..'" "'.._filesActive.file..'" -export "'..para..filename..extension..'"', path,false)	
	-- wait until work is done
	local status = process:Wait()

	-- read messages and errors
	local ret =""
	local read = process:Read()
	if read and read != "" then
		if read:sub(-1)== "\n" then read = read:sub(1,-2) end
		ret ..= read .."\n"
	end	
	read = process:ReadError()
	if read and read != "" then
		if read:sub(-1)== "\n" then read = read:sub(1,-2) end
		ret ..="[ERROR]" .. read .."\n"
	end

	-- close process
	process:Close()
	
	if ret != "" then
		SDL.Request.Message(window, TITLE, ret .. "\nStatus:"..tostring(status), "OK INFORMATION")
	else	
		if status == 0 then
			InfoBoxSet("Exported.")
			return true
		else
			InfoBoxSet("Something went wrong")
			return false
		end
	end
end


--===================================================================
--------------------------------------------------------------infobox
--===================================================================

local _infoBoxText -- text to display
local _infoBoxY	-- current position y, relativ to button!
local _infoBoxH -- hight of the box
local _infoBoxW -- width of the box
local _infoBoxPhase -- which phase 0 = rise, 1 display, 2 fall

-- start displaying info-box in the right bottom corner
function InfoBoxSet(text)
	_infoBoxText = text
	local w,h = SizeText(text)
	_infoBoxH = h + 10
	_infoBoxW = w + 10
		
	if _infoBoxPhase == nil	then
		-- new box
		_infoBoxY = h + 10
		_infoBoxPhase = 0
	elseif _infoBoxPhase <= 1 then
		-- visible, joust add little shake and set to rising
		_infoBoxPhase = 0
		_infoBoxY += 3
	elseif _infoBoxPhase == 2 then
		-- was falling -> rising
		_infoBoxPhase = 0
	end
end

-- drawing the info box
function InfoBoxDraw()
	if _infoBoxPhase == 0 then		
		-- rising
		if _infoBoxY > 0.5 then
			_infoBoxY -= (_infoBoxY)/10
		else
			-- is on top -> move to stay
			_infoBoxPhase = 1
			infoboxTime = SDL.Time.Get() + 2.0
		end
		
	elseif _infoBoxPhase == 1 then
		-- stay
		if infoboxTime < SDL.Time.Get() then
			_infoBoxPhase = 2
		end
	
	elseif _infoBoxPhase == 2 then
		-- fall
		_infoBoxY += (_infoBoxY)/10
		if _infoBoxY > _infoBoxH -0.5 then
			_infoBoxPhase = nil
		end
	end
	
	if _infoBoxPhase then
		-- draw
		local ow, oh = renderer:GetOutputSize()
		DrawFilledRect({ow - _infoBoxW, oh - _infoBoxH + _infoBoxY \ 1, _infoBoxW, _infoBoxH}, Pico.RGB[8], 255, true)
		DrawText(ow - _infoBoxW + 5 , oh - _infoBoxH + 5 + _infoBoxY \ 1, _infoBoxText, Pico.RGB[10])
	end
end


--===================================================================
---------------------------------------------------------------Module
--===================================================================
_modulesActive = nil
modules = modules or {} -- should exist, because loaded from library

-- handle errors on modules
local function _ModulesMessageHandler(err) 
	local name = ""
	if _modulesActive then
		name = _modulesActive.name
	end
	
	-- output error
	PrintDebug("[ERROR]",name, err)		
	PrintDebug(debug.traceback())
	
	-- ask user what to do
	if SDL.Request.Message(window,TITLE,"Error on module '".. tostring(name) .. "'\n" .. tostring(err),"OKCANCEL STOP") == "CANCEL" then
		-- disable!
		if _modulesActive then
			_modulesActive.active = false
			InfoBoxSet("Disabled module '".. tostring(name) .."'.")
		end
	else
		-- count errors
		if _modulesActive then
			_modulesActive.errorcount += 1
		end
	end
	
	return err
end

-- Init all modules
function ModulesInit()
	
	for nb,m in pairs(modules) do
		-- quick and dirty activate
		_modulesActive = m
		
		-- initalize module
		local ok,initalized
		m.errorcount = 0
		if m.Init then 
			ok,initalized = xpcall(m.Init, _ModulesMessageHandler, m)
			initalized = ok == true and initalized == true
		end	
		
		-- store result and add button
		m.active = initalized 
		m.tabButton = buttons:Add("Tab" .. m.name, m.name, nil, nil,"tabs", Pico.RGB[_TOOLBARBUTTONHIGH], Pico.RGB[7],Pico.RGB[_TOOLBARBUTTONBACK])		
		m.tabButton.index = m
		m.tabButton.visible = initalized
		m.tabButton.shrinkOnDeselected = true
		m.tabButton.OnClick = function(but)
			ModuleActivate(but.index)
		end
	end
	-- quick & dirty deactivate module
	_modulesActive = nil
	
	-- activate module 1
	modules[1].tabButton:OnClick() -- simulate click on button
	return true
end

-- activate module
function ModuleActivate(module)
	if module and _modulesActive != module then
		-- send lost message
		ModulesCall("FocusLost")
		
		-- activate new one 
		_modulesActive = module

		-- activate correct menu bar
		if module.menuBar then
			menu:Set(module.menuBar)
		else
			menu:Set(menu.default)
		end
		
		-- send gained
		ModulesCall("FocusGained")
		
		-- update button and call resize for the module
		buttons:SetRadio(module.tabButton)	
		ModulesCall("Resize")
		return true
	end
	return false
end

-- close all modules
function ModulesQuit()
	for nb,m in pairs(modules) do
		-- quick and dirty activate
		_modulesActive = m
		local ok,err = true
		if m.Quit then 
			ok,err = xpcall(m.Quit, _ModulesMessageHandler, m) 
		end
		-- remove button
		if m.tabButton then
			buttons:Remove(m.tabButton)
		end
	end	
	_modulesActive = nil
end

-- call a module function on a secure way
function ModulesCall(fn,...)
	if _modulesActive and _modulesActive[fn] and _modulesActive.active then 
		local ok,a,b,c,d,e,f,g,h = xpcall( _modulesActive[fn], _ModulesMessageHandler, _modulesActive,...)
				
		if ok then
			return a,b,c,d,e,f,g,h
		end
	end
	return nil
end

-- check keyboard shortcut
function ModulesCheckShorcut(sym,scan,mod)
	return ShortcutCheck(_modulesActive.shortcut, sym, scan, mod)
end


-- check if a function exist
function ModulesExistCall(fn)
	return _modulesActive and _modulesActive[fn] and _modulesActive.active  
end

-- call a module sub-function (for example module.buttons:Add -> "buttons","Add")
function ModulesCallSub(s,fn,...)
	if _modulesActive and _modulesActive[s] and _modulesActive[s][fn] and _modulesActive.active then 
		local ok,a,b,c,d,e,f,g,h = xpcall( _modulesActive[s][fn], _ModulesMessageHandler, _modulesActive[s],... )
		if ok then
			return a,b,c,d,e,f,g,h
		end
	end
	return nil
end

-- reposition modules
function ModulesSetPosition(x, y)
	local b
	for nb,m in pairs(modules) do
		if m.active and m.tabButton then
			if not b then
				b = m.tabButton:SetPos(x, y)		
			else		
				m.tabButton:SetRight(1)
			end
		end
	end
end	

--===================================================================
----------------------------------------------Textures/Surface/Images
--===================================================================

local _texturesSprite = nil -- textures
local _texturesLabel = nil
local _texturesCharset = nil
local _texturesSFX = {}
local _texturesSpriteUsedPico = nil -- the textures are from this pico
local _texturesLabelUsedPico = nil
local _texturesCharsetUsedPico = nil
local _texturesSFXUsedPico = {}
surfaceCache128x128 = nil -- a generel cache-texture

-- lock a surface for direct access, return data,pitch,w,h
function SurfaceLock(Surface)
	local w, h, pitch = SDL.Surface.GetSize( Surface )
	local data = SDL.Surface.GetPixels( Surface )
	SDL.Surface.Lock(Surface)
	return data,pitch,w,h
end

-- unlock surface
function SurfaceUnlock(Surface)
	SDL.Surface.Unlock(Surface)
end

-- redraw is needed, resetet UsedPico to force it
function TexturesForceRedraws()
	_texturesSpriteUsedPico = nil
	_texturesLabelUsedPico = nil
	_texturesCharsetUsedPico = nil
	_texturesSFXUsedPico = {}
end

-- get sprite texture of the active pico
function TexturesGetSprite()
	if activePico:SpriteChanged() or activePico != _texturesSpriteUsedPico then
		local data,pitch = _texturesSprite:Lock()
		activePico:SpriteRender(data,pitch)
		_texturesSprite:Unlock()
		_texturesSpriteUsedPico = activePico
	end	
	return _texturesSprite
end

-- get label texture of the active pico
function TexturesGetLabel()
	if activePico:LabelChanged() or activePico != _texturesLabelUsedPico then
		local data,pitch = _texturesLabel:Lock()
		activePico:LabelRender(data, pitch)
		_texturesLabelUsedPico = activePico
		_texturesLabel:Unlock()
	end	
	return _texturesLabel
end

-- get charset texture of the active pico
function TexturesGetCharset()
	if activePico:CharsetChanged() or activePico != _texturesCharsetUsedPico then
		local data,pitch = _texturesCharset:Lock()
		activePico:CharsetRender(data,pitch)
		_texturesCharset:Unlock()
		_texturesCharsetUsedPico = activePico
	end	
	return _texturesCharset
end

-- get SFX texture of the active pico
function TexturesGetSFX(nb)
	if activePico:SFXChanged(nb) or activePico != _texturesSFXUsedPico[nb] then
		local data,pitch = _texturesSFX[nb]:Lock()
		activePico:SFXRender(nb, data,pitch)
		_texturesSFXUsedPico[nb] = activePico
		_texturesSFX[nb]:Unlock()
	end	
	return _texturesSFX[nb]
end

-- initalize Textures
function TexturesInit()
	-- create textures
	_texturesSprite = renderer:CreateTexture("RGBA32","STREAMING",128,128)
	if _texturesSprite == nil then return false end
	_texturesCharset = renderer:CreateTexture("RGBA32","STREAMING",128,128)
	if _texturesCharset == nil then return false end
	_texturesLabel = renderer:CreateTexture("RGBA32","STREAMING",128,128)
	if _texturesLabel == nil then return false end
	for i=0,63 do
		_texturesSFX[i] = renderer:CreateTexture("RGBA32","STREAMING",32,64)
		if _texturesSFX[i] == nil then return false end
	end
	
	-- cache-surface
	surfaceCache128x128 = SDL.Surface.CreateRGB(128,128,"RGBA32")
	if surfaceCache128x128 == nil then return false end

	return true
end

-- free Textures
function TexturesQuit()
	if _texturesSprite then
		_texturesSprite:Destroy()
		_texturesSprite = nil
	end
	if _texturesCharset then
		_texturesCharset:Destroy()
		_texturesCharset = nil
	end
	if _texturesLabel then
		_texturesLabel:Destroy()
		_texturesLabel = nil
	end
	for i = 0, 63 do
		if _texturesSFX[i] then
			_texturesSFX[i]:Destroy()
			_texturesSFX[i] = nil
		end
	end
	
	if surfaceCache128x128 then
		surfaceCache128x128:Free()
		surfaceCache128x128 = nil
	end
end

-- Set a alpha-value for the complete Surface
function SurfaceSetAlpha(surface, alpha)	
	local data,pitch,w,h = SurfaceLock(surface)
	alpha = alpha or 255
	for y=0,h-1 do
		local adr = y * pitch
		for x=0,w-1 do
			data:set8(adr+3,alpha)
			adr+=4
		end
	end
	SurfaceUnlock(surface)			
end

-- save a surface
function SurfaceSave(surface, file)
	local err = false

	-- remove transparentcy, if needed
	if not config.saveTransparentBlack then
		SurfaceSetAlpha(surface,255)
	end

	-- which file format?
	local ext = file:sub(-4,-1):upper()	
	if ext == ".JPG" then
		err = not surface:SaveJPG(file, config.jpgQuality)
	elseif ext == ".PNG" then
		err = not surface:SavePNG(file)
	else
		err = not surface:SaveBMP(file)
	end
	
	if err then
		SDL.Request.Message(window, TITLE, "Could not save image.\n" .. SDL.Error.Get(), "OK STOP")
	else
		InfoBoxSet("Image saved.")
	end	
end

-- load a image, split it in tiles and fill the map & sprite data
function ImageLoadMap(file, colconv, colrgb)
	local surface = SDL.Surface.Load(file)		
	if surface == nil then
		SDL.Request.Message(window, TITLE, "Couldn't load image\n" .. SDL.Error.Get(), "OK STOP")
		return false
	end	
	
	local sw,sh,pitch = surface:GetSize()
	local ms, mw, mh = activePico:MapSize()

	-- clamp to map and 8-pixel 
	mw = math.min(sw, mw * 8) \ 8 
	mh = math.min(sh, mh * 8) \ 8 
	
	-- Scale image to needed dimensions
	surfaceDest = SDL.Surface.CreateRGB( mw * 8, mh * 8, "RGBA32")	
	surface:SetBlendMode("NONE")
	surface:BlitScaled(nil, surfaceDest, nil)	
	
	-- Convert Image to Pico8-Colors
	local pic = SurfaceGetPico8Image(surfaceDest, colconv, colrgb, config.doColorOptimization)

	-- we don't need the images any more
	surfaceDest:Free()
	surface:Free()
	
	-- scan the image for tiles	
	local lastEmpty = 1-- sprite 0 is always in use
	for y = 0, mh -1 do
		for x = 0, mw - 1 do
			-- get tile-data from map
			local tileData = {}
			local xx,yy = x * 8, y * 8
			for h = 0, 7 do
				tileData[h] = (pic[yy + h][xx + 0]      ) | (pic[yy + h][xx + 1] <<  4) | (pic[yy + h][xx + 2] <<  8) | (pic[yy + h][xx + 3] << 12) | (pic[yy + h][xx + 4] << 16)
						   | (pic[yy + h][xx + 5] << 20) | (pic[yy + h][xx + 6] << 24) | (pic[yy + h][xx + 7] << 28)
			end
			
			-- search sprite			
			local spr = -1
			for i = 0, 255 do
				local adr = activePico:SpriteAdr(i)
				local ok = true
				for h = 0, 7 do
					if activePico:Peek32(adr + h * 64) != tileData[h] then
						ok = false
						break
					end
				end
				if ok then 
					-- found
					spr = i
					break
				end
			end
			
			-- not found -> search for an empty slot
			if spr == -1 then
				for i = lastEmpty, 255 do 
					local adr = activePico:SpriteAdr(i)
					local ok = true
					for h = 0, 7 do
						if activePico:Peek32(adr + h * 64) != 0 then
							ok = false
							break
						end
					end
					if ok then 
						--found
						lastEmpty = i + 1 -- we know that all below are in use!
						spr = i
						break
					end
				end
				
				if spr != -1 then
					-- copy tile to sprite data
					local adr = activePico:SpriteAdr(spr)
					for h = 0, 7 do
						activePico:Poke32(adr + h * 64, tileData[h])
					end
				end
			end

			-- write found sprite to map-data
			if spr != -1 then
				activePico:MapSet(x,y,spr)
			end
			
		end
	end
	return true
end

-- save the map as a big image
function ImageSaveMap(file)
	-- render the sprite data to an surface
	data,pitch = SurfaceLock( surfaceCache128x128 )
	activePico:SpriteRender(data, pitch, true)
	SurfaceUnlock( surfaceCache128x128 )
	
	-- create a surface that can contain the complete map		
	local size, width, height = activePico:MapSize()	
	surface = SDL.Surface.CreateRGB( 8 * width, 8 * height, "RGBA32")
	
	if surface == nil then
		SDL.Request.Message(window, TITLE, SDL.Error.Get() ,"OK STOP")
		return false
	end
	
	-- build map tile by tile
	for y = 0, height - 1 do
		for x = 0, width - 1 do
			local char = activePico:MapGet(x,y)
			surfaceCache128x128:Blit({ (char & 0xf) * 8, (char >> 4) *8,8,8}, surface, {x * 8,y * 8})
		end
	end	
	
	-- save image and quit
	SurfaceSave(surface, file)		
	surface:Free()	
	return true
end

-- load an image an use it as charset
function ImageLoadCharset(file)
	local surface = SDL.Surface.Load(file)			
	if surface == nil then
		SDL.Request.Message(window, TITLE, SDL.Error.Get() ,"OK STOP")
		return false
	end
	
	-- scale to charset-size
	surface:SetBlendMode("NONE")
	surface:BlitScaled(nil, surfaceCache128x128, nil)
	surface:Free()
	
	-- scan image for gray-scale values
	local w,h,pitch = surfaceCache128x128:GetSize()
	local data = surfaceCache128x128:GetPixels()
	local pm = surfaceCache128x128:GetPixelFormat()
	local pic={}
	
	for y = 0, h - 1 do
		local adr = pitch * y
		for x = 0, w - 1 do				
			local r1, g1, b1, a1 = pm:GetRGBA(data:getu32( adr ) )
			pic[x.."x"..y] = r1 * 0.299 + g1 * 0.587 + b1 * 0.114
			adr += 4
		end
	end
	
	-- convert greyscale-values to B/W-pixels and write it to the charset-buffers
	local adr = Pico.CHARSET
	for i=0,255 do
		local x,y = (i & 0xf)*8, (i >> 4)*8
		
		for yy = y, y + 7 do
			local byte = 0
			for xx = x, x + 7 do
				byte = (byte >> 1) | (pic[xx.."x"..yy] >= 128 and 128 or 0)
			end
			activePico:Poke(adr, byte)
			adr += 1
		end		
		
	end
	-- default settings
	activePico:Poke(Pico.CHARSET  ,6)
	activePico:Poke(Pico.CHARSET+1,8)
	activePico:Poke(Pico.CHARSET+2,8)
	activePico:Poke(Pico.CHARSET+3,0)
	activePico:Poke(Pico.CHARSET+4,0)
	
	
end

-- Convert Image to Pico8-Palette and return a table with the data
function SurfaceGetPico8Image(surface, colconv, colrgb, doColor)
	local w,h,pitch = surface:GetSize()
	local data = surface:GetPixels()
	local pm = surface:GetPixelFormat()
	
	local pic = {}
	local count = {}
	
	-- reset count of the colors
	for i=0,15 do
		count[i] = 0
		count[i+128] = 0
	end	

	-- read color-data of the image and store it in the table
	for y = 0, h - 1 do
		local adr = pitch * y
		for x = 0, w - 1 do				
			local r1, g1, b1, a1 = pm:GetRGBA(data:getu32( adr ) )
			
			if config.doGreyScale then
				--convert to grey
				r1 = r1 * 0.299 + g1 * 0.587 + b1 * 0.114
				g1 = r1
				b1 = r1
			end
			
			-- store
			pic[x.."x"..y] = {r = r1, g  = g1, b = b1}
			adr += 4
			
			-- search nearest color of the complete pico8 palette and score them
			local col1 = activePico:ColorNearestALL(r1,g1,b1)
			count[col1] += 10 -- best match 10 points		
			
			local col2 = activePico:ColorNearestALL(r1,g1,b1,col1)
			count[col2] += 1 -- second best match 1 point
			
		end
	end
	
	-- helper for settings the palette in a good order
	local helper={}
	for i=0,15 do
		helper[i] = true
	end
	
	-- create a new palette with matching colors
	if doColor then
		-- sort list 
		local clist = {}
		for nb,count in pairs(count) do
			table.insert(clist, {nb = nb, count = count})
		end
		table.sort(clist,function(a,b) return (a.count > b.count) end)
		
		-- reset palette to default
		for i=0, Pico.PALLEN - 1 do
			activePico:Poke(Pico.PAL + i, i)
		end
		
		-- Set the colors 0-15 to the correct place in the palette
		for i = 0, Pico.PALLEN - 1 do
			if clist[i+1].count > 0 and helper[ clist[i+1].nb ] then
				helper[ clist[i+1].nb ] = false -- mark as used
				clist[i+1].count = -1
			end
		end
		-- then set colors 128-143 to place 0-15, if empty
		for i = 0, Pico.PALLEN - 1 do
			if clist[i+1].count > 0 and helper[ clist[i+1].nb - 128 ] then
				helper[ clist[i+1].nb - 128 ] = false -- mark as used
				activePico:Poke(Pico.PAL + clist[i+1].nb - 128, clist[i+1].nb)
				clist[i+1].count = -1
			end
		end
		-- fill the gaps
		local a = 0
		for i = 0, Pico.PALLEN - 1 do		
			if clist[i+1].count > 0 then
				-- search empty place
				while not helper[a] do
					a+=1
				end
				activePico:Poke(Pico.PAL + a,clist[i+1].nb)
				helper[ a ] = false -- mark as used
				clist[i+1].count = -1
			end
		end
		
		-- little trick - mark unused colors as colorcode 50 
		for i = 0, Pico.PALLEN - 1 do
			if helper[i] then
				activePico:Poke(Pico.PAL + i,50) -- set to not use!
			end
		end
		
	end

	local out = {}
	if config.doDithering then
		-- dither-code
		local dither		
		if config.doDitheringFloydSteinberg then
			-- update pixel with an bias
			local update = function(x, y, r, g, b, bias)
				adr = x.."x"..y
				if pic[adr] then
					pic[adr].r = math.clamp(0, 255, pic[adr].r + r * bias)
					pic[adr].g = math.clamp(0, 255, pic[adr].g + g * bias)
					pic[adr].b = math.clamp(0, 255, pic[adr].b + b * bias)
				end
			end

			dither = function(x,y)
				-- get the nearest color
				local adr = x.."x"..y
				local col = colconv( pic[adr].r, pic[adr].g, pic[adr].b )
				
				-- calculate the error
				local er, eg, eb = colrgb(col)
				er = pic[adr].r - er
				eg = pic[adr].g - eg
				eb = pic[adr].b - eb
				
				-- update neighboring pixels
				update(x + 1, y    , er, eg, eb, 7.0 / 16.0)
				update(x - 1, y + 1, er, eg, eb, 3.0 / 16.0)
				update(x    , y + 1, er, eg, eb, 5.0 / 16.0)
				update(x + 1, y + 1, er, eg, eb, 1.0 / 16.0)
				return col
			end
		else
			local colors = {}
			
			local ColorsAdd = function (f1,f2, c1r,c1g,c1b, c2r,c2g,c2b, pat, col1, col2)
				table.insert(colors, {
					r = (c1r * f1 + c2r * f2) \ (f1+f2),
					g = (c1g * f1 + c2g * f2) \ (f1+f2),
					b = (c1b * f1 + c2b * f2) \ (f1+f2),
					pat = pat,
					c1 = col1,
					c2 = col2
				})
			end
			
			for c1 = 0, 15 do
				local c1rx, c1gx, c1bx = colrgb(c1)
				local c1hx = c1rx * 0.299 + c1gx * 0.587 + c1bx * 0.144
				
				for c2 = c1, 15 do
				
					if c1 == c2 then
						ColorsAdd(1,1, c1rx,c1gx,c1bx, c1rx,c1gx,c1bx, 0xffff, c1,c1)
						
					else
						local col1, col2 = c1, c2
						local c1r, c1g, c1b, c1h = c1rx, c1gx, c1bx, c1hx
					
						local c2r, c2g, c2b = colrgb(c2)
						local c2h = c2r * 0.299 + c2g * 0.587 + c2b * 0.144
						
						if c1h < c2h then
							c1r, c1g, c1b, c1h, c2r, c2g, c2b, c2h = c2r, c2g, c2b, c2h, c1r, c1g, c1b, c1h
							col1,col2 = col2,col1
						end
						
						local dr,dg,db = c1r - c2r, c1g - c2g, c1b - c2b
						local a = dr*dr * 0.299 + dg*dg * 0.587 + db*db * 0.144
						if  a < 100*100*3 then
							--ColorsAdd( 1,15, c1r,c1g,c1b, c2r,c2g,c2b, 0x8000, col1,col2)
							--ColorsAdd( 2,14, c1r,c1g,c1b, c2r,c2g,c2b, 0x8020, col1,col2)
							--ColorsAdd( 3,13, c1r,c1g,c1b, c2r,c2g,c2b, 0xa020, col1,col2)
							--ColorsAdd( 4,12, c1r,c1g,c1b, c2r,c2g,c2b, 0xa0a0, col1,col2)
							--ColorsAdd( 5,11, c1r,c1g,c1b, c2r,c2g,c2b, 0xa4a0, col1,col2)
							--ColorsAdd( 6,10, c1r,c1g,c1b, c2r,c2g,c2b, 0xa4a1, col1,col2)
							--ColorsAdd( 7, 9, c1r,c1g,c1b, c2r,c2g,c2b, 0xa5a1, col1,col2)
							ColorsAdd( 8, 8, c1r,c1g,c1b, c2r,c2g,c2b, 0xa5a5, col1,col2)
							--ColorsAdd( 9, 7, c1r,c1g,c1b, c2r,c2g,c2b, 0xe5a5, col1,col2)
							--ColorsAdd(10, 6, c1r,c1g,c1b, c2r,c2g,c2b, 0xe5b5, col1,col2)
							--ColorsAdd(11, 5, c1r,c1g,c1b, c2r,c2g,c2b, 0xf5b5, col1,col2)
							--ColorsAdd(12, 4, c1r,c1g,c1b, c2r,c2g,c2b, 0xf5f5, col1,col2)
							--ColorsAdd(13, 3, c1r,c1g,c1b, c2r,c2g,c2b, 0xfdf5, col1,col2)
							--ColorsAdd(14, 2, c1r,c1g,c1b, c2r,c2g,c2b, 0xfdf7, col1,col2)
							--ColorsAdd(15, 1, c1r,c1g,c1b, c2r,c2g,c2b, 0xfff7, col1,col2)
							
						end
					end
				end
			end
	
			
			
			dither = function(x, y)
				local adr = x.."x"..y
				local pr,pg,pb = pic[adr].r, pic[adr].g, pic[adr].b 
				local best, choosen 
				
				for nb, col in pairs(colors) do
					--table.debug(col)
					local dr,dg,db = pr - col.r, pg - col.g, pb - col.b
					local a = dr*dr * 0.299 + dg*dg * 0.587 + db*db * 0.144
			
					if not best or best > a or (best == a and col.c1 == col.c2) then
						choosen = col
						best = a
					end
				end
				
				local i = (x % 4) + (y % 4)*4
				if 1<<i & choosen.pat != 0 then
					return choosen.c1
				else
					return choosen.c2
				end
			
			end
			
					
		end
		
		-- dither all pixels
		for y = 0, h - 1 do
			out[y] =  {}
			for x = 0, w - 1 do
				out[y][x] = dither(x, y)
			end
		end	

	else
		--nearest color
		for y = 0, h - 1 do
			out[y] =  {}
			for x = 0, w - 1 do			
				local adr
				adr = x.."x"..y
				out[y][x] = colconv( pic[adr].r, pic[adr].g, pic[adr].b )
			end
		end
	end

	-- correct palette
	for i = 0, Pico.PALLEN - 1 do
		if activePico:Peek(Pico.PAL + i)== 50 then
			activePico:Poke(Pico.PAL + i, i)
		end
	end

	return out
end

-- load an image to spritesheet / label
function ImageLoad128x128(file, colconv, colrgb, destAdr)
	-- load file
	local surface = SDL.Surface.Load(file)		
	if surface == nil then
		SDL.Request.Message(window, TITLE, "Couldn't load image\n" .. SDL.Error.Get() ,"OK STOP")
		return false
	end	
	
	-- scale to 128x128
	surface:SetBlendMode("NONE")
	surface:BlitScaled(nil, surfaceCache128x128, nil)
	surface:Free()
		
	-- convert to pico8 colors
	local pic = SurfaceGetPico8Image(surfaceCache128x128, colconv, colrgb, config.doColorOptimization and destAdr != Pico.LABEL)
		
	-- write to pico8-memory
	local outAdr = destAdr
	for y = 0, 127 do
		for x = 0,127, 2 do
			activePico:Poke( outAdr, pic[y][x] | ( pic[y][x + 1] << 4) )
			outAdr += 1
		end
	end	
	
end


--===================================================================
-----------------------------------------------------------PicoRemote
--===================================================================
-- used as a sound-engine :)

-- request the pico8 executeable
function PicoRemoteSetting()
	local file = RequestOpenFile(window,"Select pico8.exe",config.pico8execute or "pico8.exe",FILEFILTEREXECUTE)
	if file and file != "" then config.pico8execute = file end
	-- restart remote
	PicoRemoteStart() 
end

-- (re)start the remote control
function PicoRemoteStart()
	PicoRemoteStop()
	if config.doRemote then
		if config.pico8execute == nil or config.pico8execute == "" then
			return false
		end
		
		if config.pico8execute and config.pico8execute != "" then
			PicoRemote = {
				process = TinyProcess.Open('"'..config.pico8execute..'" '.."-run remote.p8 " .. (config.pico8parameter or ""),"",true),
				memory = {}, -- shadow-memory-copy to reduce transfer
				stat = {}, -- simulated stat-variable
				ready = false,
			}
			PicoRemote.process:Write(".\n") -- start heartbeat
			InfoBoxSet("Start remote pico8...")
			return true
		end
		InfoBoxSet("Couldn't start remote pico8.")
	end
	return false
end

-- quit remote control
function PicoRemoteStop()
	if PicoRemote and PicoRemote.process then 
		PicoRemote.process:Kill() -- send kill 
		PicoRemote.process:Wait() -- wait until it ends
		PicoRemote.process:Close() -- and remove handle
		PicoRemote.process = nil
		PicoRemote.ready = false
	end
end

-- write data to the remote (adr, size in pico8-remote memory, optional srcAdr in activePico-Memory)
function PicoRemoteWrite(adr,size,srcAdr)
	if PicoRemote and PicoRemote.ready then
		local hex = activePico:PeekHex(srcAdr or adr, size)
		
		local xadr = adr
		local changed = false
		local iStart = nil
		local iEnd = nil
		
		-- check if something has changed since last call
		for i = 1,#hex,2 do
			local v= tonumber( "0x".. hex:sub(i,i+1) ) or 0 
			if PicoRemote.memory[i + xadr] != v then
				-- jup changes
				PicoRemote.memory[i + xadr] = v
				changed = true

				-- to skip unchanged area
				-- set new start 
				if not iStart then iStart = xadr - adr end 
				-- set a new end-position
				iEnd = xadr - adr
			end
			xadr +=1
		end		
				
		
		if changed then
			-- send data to remote
			adr += iStart
			hex = hex:sub(iStart*2+1, iEnd*2+2)
			PrintDebug("picoremote: write @"..adr.. " "..#hex.."bytes")			
			PicoRemote.process:Write("@"..adr.."\n")		
			PicoRemote.process:Write("!"..hex.."\n")
			PrintDebug("picoremote: done")
			PicoRemoteOldAdr = adr 
			PicoRemoteOldHex = hex
		end
	end
end

-- start playing a music
function PicoRemoteMusic(nb)
	if PicoRemote and PicoRemote.ready then
		PicoRemote.process:Write("m"..nb.."\n")
	end
end

-- start playing a sfx 
function PicoRemoteSFX(nb,note,endnote)
	if PicoRemote and PicoRemote.ready then
		if note then
			endnote = endnote or note
			if endnote < note then endnote,note = note,endnote end
			local str = "s"..nb..","..note..","..(math.abs(note - endnote ) + 1).."\n"
			PicoRemote.process:Write(str)
		else
			PicoRemote.process:Write("s"..nb.."\n")
		end		
	end
end

-- return music/sfx status
function PicoRemoteStatus()
	if PicoRemote and PicoRemote.ready then
		return PicoRemote.stat[57] or false, PicoRemote.stat[54] or -1, 
				PicoRemote.stat[46] or -1,PicoRemote.stat[47] or -1,PicoRemote.stat[48] or -1,PicoRemote.stat[49] or -1,
				PicoRemote.stat[50] or -1,PicoRemote.stat[51] or -1,PicoRemote.stat[52] or -1,PicoRemote.stat[53] or -1
	else
		return false,-1, -1,-1,-1,-1, -1,-1,-1,-1
	end
end

-- update status and handle heartbeat - must be called regulary!
function PicoRemoteUpdate()
	if not PicoRemote or not PicoRemote.process then return end

	if not PicoRemote.process:IsRunning() then
		-- pico8 has stopped working - maybe user has closed id? restart
		--PrintDebug("Stop working?")
		PicoRemoteStop()
		PicoRemoteStart()
		
	else

		status = PicoRemote.process:Read()
		if status != "" then
			for a,str in pairs(status:split("\n")) do -- split status to lines
				
				if str == "." then
					-- heartbeat
					PicoRemote.process:Write(".\n")
					
				elseif str == "start" then
					-- pico8 is working
					InfoBoxSet("Remote pico8 is ready!")
					PicoRemote.ready = true
					PicoRemote.memory = {} -- reset transfered memory
					MainWindowResize() -- so the modules can send the memory

				elseif str:sub(1,1) == "!" then
					-- status-update
					local s = str:split()
					PicoRemote.stat[57] = (s[1] == "!true")
					for i=46,54 do
						PicoRemote.stat[i] = tonumber(s[i-44]) or -1
					end
					
				else
					-- should not happen!
					PrintDebug("Unkown Remote message:",str)
						
				end
			end
		end
	end
end


--===================================================================
--------------------------------------------------------------Tooltip
--===================================================================
local _tooltipRect 
local _tooltipText

-- display the current tooltip
function TooltipDraw()
	if not _tooltipText then return end

	DrawFilledRect(_tooltipRect, Pico.RGB[2],255,true)
	DrawText(_tooltipRect.x + 5, _tooltipRect.y + 5, _tooltipText, Pico.RGB[135])		
	DrawRect(_tooltipRect, COLBLACK,255,true)
	_tooltipText = nil
end

-- set Tooltip - brect is the object, which needs a tooltip
-- must be called every frame!
function TooltipText(text, brect)
	_tooltipText = text	
	-- calculate size (default left under the brect)
	local ww,hh = SizeText(_tooltipText)
	_tooltipRect = {x = brect.x - 1, y = brect.y + brect.h, w = ww + 10, h = hh + 10}
	
	-- check if the tooltip is complete visible
	local ow, oh = renderer:GetOutputSize()
    if ow < _tooltipRect.x + _tooltipRect.w + 5 then
		-- align to the right
		_tooltipRect.x = brect.x + brect.w - _tooltipRect.w + 1
	end
	if _tooltipRect.x < 0 then
		-- center
		_tooltipRect.x = (ow - _tooltipRect.w) \ 2
	end
	
	if oh < _tooltipRect.y + _tooltipRect.h + 5 then
		-- above the brect
		_tooltipRect.y = brect.y - _tooltipRect.h
	end	
end

--===================================================================
--------------------------------------------------------Window / Main
--===================================================================

_oldWinTitle = nil
function MainWindowTitle(str)
	if _oldWinTitle != str then
		window:SetTitle(TITLE.." v"..VERSION.. ((str and str!="") and (" - "..str) or ""))
		_oldWinTitle = str
	end
end

_drawMainWindowOldTimer = 0
-- draw the main window



function MainWindowDraw()
	-- background
	local ow, oh = renderer:GetOutputSize()



	-- blue top bar for modules and files
	DrawFilledRect({0, menu.size, ow, topLimit - 5-menu.size} ,  Pico.RGB[_TOOLBARBACK],255,true)
	
	-- blue/red background for module-content (depend on writeprotect)
	DrawFilledRect({0, topLimit - 5 , ow, oh - topLimit + 5 } , Pico.RGB[activePico.writeProtected and 130 or 1],255,true)
	
	local mmx,mmy = mx,my
	
	if menu:HasFocus() then
		mmx, mmy = -1,-1
	end
	
	if popup:HasFocus() then 
		mmx, mmy = -1,-1 -- deactivate all highlight outside popup
	end
	
	if scrollbar:Draw(mx, my) then 
		mmx, mmy = -1,-1 -- scrolling is active, don't highlight others
	end
	
	-- scrollbars inside the module
	if ModulesCallSub("scrollbar","Draw",mmx,mmy) then
		mmx, mmy = -1,-1
	end
	
	-- draw main-window buttons
	if buttons:Draw(mmx,mmy) then
		mmx, mmy = -1,-1
	end
	
	-- draw module content
	ModulesCall("Draw",mmx,mmy)
	
	-- buttons inside the module
	ModulesCallSub("buttons","Draw",mmx,mmy) 
	
	-- draw inputs control inside the module
	ModulesCallSub("inputs","Draw") 
	
	-- draw popup
	popup:Draw(mx, my)
	
	-- show tooltip
	TooltipDraw()
	
	-- draw the info box
	InfoBoxDraw()
	
	-- draw menu
	menu:Draw(mx,my)
		
	-- display max FPS for debug information
	local str = string.format("%03.3f %03.3f", SDL.Time.Get()-_drawMainWindowOldTimer, 1/(SDL.Time.Get()-_drawMainWindowOldTimer))
	
	-- free unused processor time 
	local wtime = (1000 / config.fpsCap) - (SDL.Time.Get() - _drawMainWindowOldTimer) * 1000 -1
	if wtime > 0 and wtime < 1000 then 
		SDL.Time.Delay(wtime)
	end	
	
	-- flip buffers	
	renderer:Present()
	
	-- output the stats to the window-title
	str ..= " - ".. string.format("%03.3f %03.3f", SDL.Time.Get()-_drawMainWindowOldTimer, 1/(SDL.Time.Get()-_drawMainWindowOldTimer))
	if config.debug then 
		MainWindowTitle(str)
	end
	
	_drawMainWindowOldTimer = SDL.Time.Get()
end

-- resize the complete window
function MainWindowResize()
	local ow, oh = renderer:GetOutputSize()
	
	FilesSetPosition(ow - 5, 5 + menu.size)
	ModulesSetPosition(5, 5 + menu.size)
	
	ModulesCall("Resize")
end

-- initalize everything, open main window
function Init()
	-- sort modules
	table.sort(modules, function (a,b) return a.sort < b.sort or (a.sort == b.sort and a.name < b.name) end)
	


	-- load configuration	
	ConfigLoad(configFile)
	ConsoleShow(config.debug)
		
	-- Init SDL
	if not SDL.Init("EVENTS VIDEO") then
		SDL.Request.Message(nil,TITLE,"Couldn't open SDL.\n" .. SDL.Error.Get(),"OK STOP" )
		return false
	end
	
	print("SDL-Version:",SDL.Version.Get())
	
		
	-- initalize sdl image
	if not SDL.Image.Init("BMP JPG PNG") then
		SDL.Request.Message(nil,TITLE,"Couldn't open SDL_Image.\n" .. SDL.Error.Get(),"OK STOP" )
		return false
	end
	
	print("SDL-Image-Version",SDL.Version.GetImage())
	
		
	-- open window
	window = SDL.Window.Create(TITLE, "CENTERED", "CENTERED", MINWIDTH, MINHEIGHT, "RESIZABLE HIDDEN")
	if window == nil then
		SDL.Request.Message(nil,TITLE,"Couldn't open main window.\n" .. SDL.Error.Get(),"OK STOP")
		return false
	end
	
	MainWindowTitle("")
	
	local surface = SDL.Surface.Load("jaP8e.png")
	if surface then
		window:SetIcon(surface)
		surface:Free()
	end
	
	--SDL.Event.State( "DROPFILE", "ENABLE" )
	--SDL.Event.State( "DROPTEXT", "ENABLE" )
	
	-- Renderer
	SDL.Hint.Set("RENDER_DRIVER","OPENGL")
	
	renderer = SDL.Render.Create(window, -1, "ACCELERATED PRESENTVSYNC TARGETTEXTURE")
	if renderer == nil then
		SDL.Request.Message(nil,TITLE,"Couldn't open renderer.\n" .. SDL.Error.Get(),"OK STOP")
		return false
	end
	local info = renderer:GetInfo()
	print("Renderer:",info.name)
	
	
	-- Menu and requester
	if not SDL.Gui.Init() then
		SDL.Request.Message(nil,TITLE,"Couldn't initalize SDL_Gui.\n" .. SDL.Error.Get(),"OK STOP")
		return false
	end

	-- load all textures
	if not TexturesInit() then
		SDL.Request.Message(nil,TITLE,"Couldn't create textures.\n" .. SDL.Error.Get(),"OK STOP")
		return false
	end
	
	-- drawing-routines
	if not DrawInit() then
		SDL.Request.Message(nil,TITLE,"Couldn't initalize draw-textures.\n" .. SDL.Error.Get(),"OK STOP")
		return false
	end

	-- Menu
	if not menu:Init() then
		SDL.Request.Message(nil,TITLE,"Couldn't initalize menus.\n","OK STOP")
		return false
	end
		
	-- can't fail...	
	buttons:Init()
	inputs:Init()
	scrollbar:Init()
	popup:Init()
	FilesInit()
		
	-- get some mouse cursors
	cursorArrow = SDL.Cursor.GetDefault()
	cursorHand = SDL.Cursor.Create("HAND")
	
	-- caluculate top limit
	local s
	_,s	= buttons:GetSize("+")	
	topLimit = menu.size + 5 + s + 5+5
	window:SetSize(MINWIDTH, MINHEIGHT + menu.size)
	window:SetMinimumSize(MINWIDTH, MINHEIGHT + menu.size)
	
	-- create a new file
	FilesNew()

	-- intalize all modules
	ModulesInit() 
		
	--FilesOpen("C:\\Users\\GPI2\\Documents\\!Dokumente\\!lua\\gfx\\compress_demo.p8")	
	
	PicoRemoteStart()
	
	SDL.TextInput.Start()	
	
	MainWindowResize()
	
	window:Show()
	PrintDebug("Initalized.")
	return true
end

-- free every resource
function Quit()
	if configFile then
		ConfigSave(configFile)
	end

	SDL.TextInput.Stop()
	
	PicoRemoteStop()
	
	FilesQuit()	
		
	ModulesQuit()
	
	buttons:Quit()
	inputs:Quit()
	scrollbar:Quit()
	popup:Quit()
	
	menu:Quit()
	
	DrawQuit()
	
	TexturesQuit()

	SDL.Gui.Quit()
	
	if renderer then
		renderer:Destroy()
		renderer = nil
	end
	
	if window then
		window:Destroy() 
		window = nil
	end
	
	
	cursorArrow = nil -- default cursor ownd by sdl
	if cursorHand then
		SDL.Cursor.Free( cursorHand )
		cursorHand = nil
	end
	
	SDL.Image.Quit()
	SDL.Quit()
	
    PrintDebug("Quit")
end

local function _TranslateKP(sym,scan,mod)
	if scan:sub(1,3) == "KP_" then
		if scan == "KP_ENTER" then
			scan,sym = "RETURN", "RETURN"
		elseif mod:hasflag("NUM")>0 then
			if scan == "KP_0" then 
				sym,scan = "0", "0"
			elseif scan == "KP_1" then 
				sym,scan = "1", "1"
			elseif scan == "KP_2" then 
				sym,scan = "2", "2"
			elseif scan == "KP_3" then 
				sym,scan = "3", "3"
			elseif scan == "KP_4" then 
				sym,scan = "4", "4"
			elseif scan == "KP_5" then 
				sym,scan = "5", "5"
			elseif scan == "KP_6" then 
				sym,scan = "6", "6"
			elseif scan == "KP_7" then 
				sym,scan = "7", "7"
			elseif scan == "KP_8" then 
				sym,scan = "8", "8"
			elseif scan == "KP_9" then 
				sym,scan = "9", "9"
			end
		else
			if scan == "KP_7" then 
				sym,scan = "HOME","HOME"
			elseif scan == "KP_8" then
				sym,scan = "UP", "UP"
			elseif scan == "KP_9" then
				sym,scan = "PAGEUP", "PAGEUP"
			elseif scan == "KP_4" then
				sym,scan = "LEFT", "LEFT"
			elseif scan == "KP_6" then
				sym,scan = "RIGHT", "RIGHT"
			elseif scan == "KP_1" then
				sym,scan = "END", "END"
			elseif scan == "KP_2" then
				sym,scan = "DOWN", "DOWN"
			elseif scan == "KP_3" then
				sym,scan = "PAGEDOWN", "PAGEDOWN"
			elseif scan == "KP_0" then
				sym,scan = "INSERT", "INSERT"
			elseif scan == "KP_PERIOD" then
				sym,scan = "DELETE", "DELETE"
			end				
		end		
	end
	return sym,scan
end


-- main routine
function main()
	

	if not Init() then
		Quit()
		return 1
	end
	
	PrintDebug("main is running")
	
	quit = false
	
	while(not quit) do
		
		-- Event-handling
		repeat
			ev = SDL.Event.Poll()		
			
			if ev.type == "QUIT" then
				-- user request a quit
				if not quit and FilesCheckAllSaved() then
					quit = true	
				end

			elseif ev.type=="USER" then
				-- userevent
				PrintDebug("---- userevent")
				table.debug(ev)
			
			elseif ev.type == "MOUSEBUTTONDOWN" then
				-- first check, if popup handle the event, then the next...
				if not menu:MouseDown(ev.x, ev.y, ev.button, ev.clicks) then
					if not SecureCall(popup.MouseDown,popup,ev.x, ev.y, ev.button, ev.clicks) then
						if not SecureCall(buttons.MouseDown, buttons, ev.x, ev.y, ev. button, ev.clicks) then
							if not ModulesCallSub("scrollbar", "MouseDown", ev.x, ev.y, ev.button, ev.clicks ) then
								if not ModulesCallSub("inputs", "MouseDown", ev.x, ev.y, ev.button, ev.clicks ) then
									if not ModulesCallSub("buttons", "MouseDown", ev.x, ev.y, ev.button, ev.clicks ) then
										ModulesCall("MouseDown", ev.x, ev.y, ev.button, ev.clicks )
									end
								end
							end
						end
					end
				end
				mx = ev.x
				my = ev.y				
				
			elseif ev.type == "MOUSEBUTTONUP" then	
				-- first check, if popup handle the event, then the next...
				if not menu:MouseUp(ev.x, ev.y, ev.button, ev.clicks) then
					if not SecureCall(popup.MouseUp, popup, ev.x, ev.y, ev.button, ev.clicks) then
						if not SecureCall(buttons.MouseUp, buttons, ev.x, ev.y, ev.button, ev.clicks) then 
							if not ModulesCallSub("scrollbar", "MouseUp", ev.x, ev.y, ev.button, ev.clicks) then 
								if not ModulesCallSub("inputs", "MouseUp", ev.x, ev.y, ev.button, ev.clicks) then 
									if not ModulesCallSub("buttons", "MouseUp", ev.x, ev.y, ev.button, ev.clicks) then 
										ModulesCall("MouseUp", ev.x, ev.y, ev.button, ev.clicks )
									end
								end
							end								
						end
					end
				end
				mx = ev.x
				my = ev.y
				
			elseif ev.type == "MOUSEMOTION" then	
				-- first check, if popup handle the event, then the next...
				if not menu:MouseMove(ev.x, ev.y, ev.button) then
					if not SecureCall(popup.MouseMove, popup, ev.x, ev.y, ev.button) then
						if not SecureCall(buttons.MouseMove, buttons, ev.x, ev.y, ev.button ) then 
							if not ModulesCallSub("scrollbar", "MouseMove", ev.x, ev.y, ev.button) then 
								if not ModulesCallSub("buttons", "MouseMove", ev.x, ev.y, ev.button) then 
									if not ModulesCallSub("inputs", "MouseMove", ev.x, ev.y, ev.button) then 
										ModulesCall("MouseMove", ev.x, ev.y, ev.button)
									end
								end
							end	
						end
					end
				end
				mx = ev.x
				my = ev.y
				
			elseif ev.type == "MOUSEWHEEL" then				
				local x,y
				if ev.direction == "NORMAL" then
					x, y = ev.x, ev.y
				else
					x, y = -ev.x, -ev.y
				end
				-- first check, if popup handle the event, then the next...
				if not menu:HasFocus() then
					if not SecureCall(popup.MouseWheel, popup, x, y, mx, my) then
						if not ModulesCallSub("inputs", "MouseWheel", x, y, mx, my) then
							ModulesCall("MouseWheel", x, y, mx, my)
						end
					end
				end
				
			elseif ev.type == "WINDOWEVENT" then
				if ev.event == "RESIZED" then
					-- window has resized
					MainWindowResize()
					menu:Close()
				
				elseif ev.event == "FOCUS_GAINED" then
					-- we got the focus
					hasFocus = true
					menu:Close()
					
				elseif ev.event == "FOCUS_LOST" then
					-- and lost it again
					hasFocus = false
					menu:Close()
					
				end
				
			elseif ev.type == "RENDER_TARGETS_RESET" then
				-- sometimes target-textures become invalid
				TexturesForceRedraws()
				
			elseif ev.type == "KEYDOWN" then
				--PrintDebug ("----- EVENT: "..tostring(ev.type).." -----")
				--table.debug(ev)
				ev.sym,ev.scancode = _TranslateKP(ev.sym,ev.scancode, ev.mod)
				-- print("down",ev.sym, ev.scancode, ev.mod)	
				 -- a message requester can filter a keyup!
		
				-- here first check, if a menu shortcut has pressed
				if not menu:KeyDown(ev.sym, ev.scancode, ev.mod) then
					if not SecureCall(popup.KeyDown, popup, ev.sym, ev.scancode, ev.mod) then
						--PrintDebug(ev.sym, ev.scancode, ev.mod)				
						if not ModulesCallSub("inputs", "KeyDown", ev.sym, ev.scancode, ev.mod) then
							if not ModulesCheckShorcut(ev.sym, ev.scancode, ev.mod) then
								if ev.sym == "DELETE" and ModulesExistCall("Delete") then
									ModulesCall("Delete")								
								else						
									ModulesCall("KeyDown",ev.sym, ev.scancode, ev.mod)
								end								
							end
						end
					end
				end
					
			elseif ev.type == "KEYUP" then
				--print("up",ev.sym, ev.scancode, ev.mod)	
				ev.sym,ev.scancode = _TranslateKP(ev.sym,ev.scancode, ev.mod)
				-- first check, if popup handle the event, then the next...
				if not menu:KeyUp(ev.sym, ev.scancode, ev.mod) then				
					if not SecureCall(popup.KeyUp, popup, ev.sym, ev.scancode, ev.mod) then
						if not ModulesCallSub("inputs", "KeyUp", ev.sym, ev.scancode, ev.mod) then
							ModulesCall("KeyUp",ev.sym, ev.scancode, ev.mod)
						end			
					end
				end
			
			
			elseif ev.type == "TEXTINPUT" then
				-- first check, if popup handle the event, then the next...
				if not menu:Input(ev.text) then
					if not SecureCall(popup.Input, popup, ev.text ) then
						if not ModulesCallSub("inputs","Input", ev.text) then
							ModulesCall("Input", ev.text) 
						end
					end
				end
			
			elseif ev.type == "DROPFILE" then
				print("DROPFILE")
				table.debug(ev)
				
			--[[
			elseif ev.type != nil then
				if ev.type != "MOUSEMOTION" and ev.type != "TEXTEDITING" then-- and ev.type!="WINDOWEVENT" and ev.type!="SYSWMEVENT" then
					
					PrintDebug ("----- EVENT: "..tostring(ev.type).." -----")
					table.debug(ev)
				end
			--]]
			end	
			
		until (ev.type == nil )		
		-- check for updates to store in the undo-buffer and set/unset unsaved-mark
		-- only when no mouse button is pressed
		local mb = SDL.Mouse.GetGlobalState()
		if mb == "NONE" then 
			activePico:UndoAddState()
			FilesCheckUpdate()
		end
		
		-- pico-remote-handling
		PicoRemoteUpdate()
		
		-- is running?
		FilesCheckRunning()
		
		-- draw main window and flip buffers
		MainWindowDraw()
	
	end
	
	Quit()
	
	PrintDebug("end")
	return 0
end

PrintDebug("jaP8e source code readed.")