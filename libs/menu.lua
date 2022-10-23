--===================================================================
-----------------------------------------------------KeyboardShortcut
--===================================================================
function ShortcutAddMoveCursor16x16(list,fn)
	local s
	s = ShortcutAdd(list, "$A", fn) s.off = -1 
	s = ShortcutAdd(list, "$MINUS", fn) s.off = -1
	s = ShortcutAdd(list, "$KP_MINUS", fn) s.off = -1

	s = ShortcutAdd(list, "$D", fn) s.off = 1
	s = ShortcutAdd(list, "$EQUALS", fn) s.off = 1
	s = ShortcutAdd(list, "$KP_PLUS", fn) s.off = 1

	s = ShortcutAdd(list, "$W", fn) s.off = -16
	s = ShortcutAdd(list, "$S", fn) s.off = 16
	
	s = ShortcutAdd(list, "SHIFT+$A", fn) s.off = -1 s.shift = true
	s = ShortcutAdd(list, "SHIFT+$MINUS", fn) s.off = -1 s.shift = true
	s = ShortcutAdd(list, "SHIFT+$KP_MINUS", fn) s.off = -1 s.shift = true
	
	s = ShortcutAdd(list, "SHIFT+$D", fn) s.off = 1 s.shift = true
	s = ShortcutAdd(list, "SHIFT+$EQUALS", fn) s.off = 1 s.shift = true
	s = ShortcutAdd(list, "SHIFT+$KP_PLUS", fn) s.off = 1 s.shift = true

	s = ShortcutAdd(list, "SHIFT+$W", fn) s.off = -16 s.shift = true
	s = ShortcutAdd(list, "SHIFT+$S", fn) s.off = 16 s.shift = true
	
	
end
function ShortcutAddTransform(list,fnFlipX,fnFlipY,fnRotateLeft,fnRotateRight,fnLeft,fnRight,fnUp,fnDown,fnInvert)
	ShortcutAdd(list, "F", fnFlipX)
	ShortcutAdd(list, "V", fnFlipY)
	ShortcutAdd(list, "R", fnRotateLeft)
	ShortcutAdd(list, "T", fnRotateRight)
	ShortcutAdd(list, "LEFT", fnLeft)
	ShortcutAdd(list, "RIGHT", fnRight)
	ShortcutAdd(list, "UP", fnUp)
	ShortcutAdd(list, "DOWN", fnDown)
	ShortcutAdd(list, "I", fnInvert)
end
function ShortCutAddSpeed(list,fnSlow,fnFast)
	ShortcutAdd(list, "LESS", fnSlow)
	ShortcutAdd(list, "$COMMA", fnSlow)
	ShortcutAdd(list, "SHIFT+$COMMA", fnSlow)
	
	ShortcutAdd(list, "SHIFT+LESS", fnFast)
	ShortcutAdd(list, "GREATER", fnFast)
	ShortcutAdd(list, "$PERIOD", fnFast)
	ShortcutAdd(list, "SHIFT+$PERIOD", fnFast)
end

function ShortcutAdd(list, key, fn)
	if not list or not key or not fn then
		return nil
	end
	--config["Shortcut_"..name] = config["Shortcut_"..name] or key
	--configComment["Shortcut_"..name] = comment .. " / $ = scancode"
	local m1, m2, k, s = key:match("([^%+]-)%+?([^%+]-)%+?([^%+]-)$")
	if k:sub(1,1) == "$" then
		s = k:sub(2)
		k = nil
	end
	--print("ADD",m1,m2,k,s)
	
	table.insert(list, {OnClick = fn, sym = k, scan = s, ctrl = (m1 == "CTRL" or m2 == "CTRL"), shift = (m1 == "SHIFT" or m2 == "SHIFT"), alt = (m1 == "ALT" or m2 == "ALT")} )
	return list[#list]
end

function ShortcutCheck(list, sym, scan, mod)
	if not list then return false end
	local s = mod:hasflag("SHIFT") > 0
	local c = mod:hasflag("CTRL") > 0
	local a = mod:hasflag("ALT") > 0
	
	for id,e in pairs(list) do
		if (e.sym == sym or e.scan == scan) and e.ctrl == c and e.shift == s and e.alt == a then
			return true, SecureCall(e.OnClick,e)		
		end
	end
	return false
end

--===================================================================
-----------------------------------------------------------------MENU
--===================================================================

menu = { size = 0 }
menu.__index = menu

metaBar = {}
metaBar.__index = metaBar

metaSub = {}
metaSub.__index = metaSub

metaEntry = {}
metaEntry.__index = metaEntry

function menu.Init(m)
	local w,h = SizeText("x")
	m.size = h + 10
	


	m.default = m:CreateBar()
	
	m.default:AddFile()
	m.default:AddEdit()	
	m.default:AddPico8()
	--m.default:AddZoom()
	m.default:AddSettings()
	m.default:AddModule()
	m.default:AddDebug()
	
	-- attach default menu
	m:Set(m.default)	
	return true
end

function menu.Quit(m)
	
	return true
end

function menu.Set(m,bar)
	if bar then
		m.current = bar
	end
	
	m.open = nil
	_mLock = nil
	
	-- update default-entry check marks
	m.current:Set("saveTransparentBlack", config.saveTransparentBlack)
	m.current:Set("doGreyScale", config.doGreyScale)
	m.current:Set("doColorOptimization", config.doColorOptimization)
	m.current:Set("doDithering", config.doDithering)	
	m.current:Set("clipboardAsHex", config.clipboardAsHex)
	m.current:Set("autooverviewzoom", config.doAutoOverviewZoom)	
	m.current:Set("doRemote", config.doRemote)	
	m.current:Set("writeProtectedPico8", config.writeProtectedPico8)
	m.current:Set("sizeAsHex", config.sizeAsHex)
	m.current:Set("debugmsg",config.debug)
	m.current:Set("doDitheringFloydSteinberg", config.doDitheringFloydSteinberg)
	MenuSetZoom(bar)
	if _modulesActive then
		m.current:Set("Module" .. _modulesActive.name)
	end
	-- call module-menu-update
	ModulesCall("MenuUpdate",m.current)
	
	-- caluclate menu
	local w,h = SizeText(" ")
	local x = 0	
	local headerKeys = {}
	for nb,sub in pairs(m.current.entry) do
		local y = 0
		local tw,th = SizeText(sub.text)
		sub.rectBack = { x = x, y = y, w = tw + w * 2, h = menu.size }
		sub.rectText = { x = x + w, y = (menu.size - th)\2, w = tw, h = th}	
		sub.rectLink = { x = x + 1, y = y + menu.size - 1, w = tw + w * 2 - 2, h = 2}
		sub.pos = nb
		
		for pos = 1, #sub.text do
			local char = sub.text:sub(pos,pos):upper()
			if ((char >= "A" and char <= "Z") or (char >= "0" and char <= "9")) and not headerKeys[char] then
				headerKeys[char] = true
				sub.menuKey = char
				sub.menuPos = SizeText(sub.text:sub(1,pos-1))
				break
			end		
		end
		
		
		y += menu.size
		
		local leftw, rightw, eh = 0, 0, 0
		local entryKeys = {}
		for nb, entry in pairs(sub.entry) do
			local left,right = entry.text:match("([^\t]*)\t?([^\t]*)")
			entry.textLeft = left
			entry.textRight = right
			entry.pos = nb
			
			if entry.OnClick then
				leftw = math.max(leftw, (SizeText(left)) )			
				rightw = math.max(rightw, (SizeText(right)) )			
				eh += h + 10
				
				for pos = 1, #left do
					local char = left:sub(pos,pos):upper()
					if ((char >= "A" and char <= "Z") or (char >= "0" and char <= "9")) and not entryKeys[char] then
						entryKeys[char] = true
						entry.menuKey = char
						entry.menuPos = SizeText(left:sub(1,pos-1))
						break
					end		
				end
				
				
			elseif entry.text != "" then
				eh += h + 10				
			else
				eh += 1 + 6
			end
			
		end
		sub.rectEntries = { x = x, y = y, w = w * 3 + leftw + w + rightw + w, h = eh }
		
		for nb, entry in pairs(sub.entry) do
			entry.posText = {x = x + w * 3, y = y + 5}
			entry.posSymbol = { x = x + w, y = y + 5}			
			entry.posKey = {x = x + w * 3 + leftw + w + rightw - (SizeText(entry.textRight)), y = y + 5}
			
			if entry.OnClick then
				entry.rectBack = {x = x, y = y, w = sub.rectEntries.w, h = h + 10}			
				y += h + 10
			elseif entry.text != "" then
				local tw,th = SizeText(entry.text)
				entry.rectBack = {x = x + w * 3, y = y + (h + 10) / 2, w = sub.rectEntries.w -w * 3 - 2, h = 1}			
				entry.posText.x += w * 2 --(sub.rectEntries.w - w * 3 - tw) \ 2
				entry.rectText = {x = entry.posText.x - 5, y = y, w = tw + 10, h = h + 10}
				
				y += h + 10
			else
				entry.rectBack = {x = x + w * 3, y = y + 3, w = sub.rectEntries.w - w * 3 -  2, h = 1}							
				y += 1 + 6
			end
		end
		
		
		x += tw + w * 2
	end
	
end

function menu.Draw(m, mx, my)
	if not m.current then return false end
	
	local a = SDL.Keyboard.GetModState():hasflag("ALT") > 0
	
	local ow, oh = renderer:GetOutputSize()
	local point = {x = mx, y = my}
	-- menu background
	DrawFilledRect({0,0,ow,m.size},COLDARKGREY )
	
	for nb,sub in pairs(m.current.entry) do
		if sub == m.open or (not m.open and SDL.Rect.ContainsPoint(sub.rectBack, point)) then
			DrawFilledRect(sub.rectBack,COLGREY)
			DrawRect(sub.rectBack,COLLIGHTGREY)
		end
		DrawText(sub.rectText.x, sub.rectText.y, sub.text,COLDARKWHITE)
		
		if a and not m.open then
			DrawText(sub.rectText.x + sub.menuPos, sub.rectText.y + 1, "_", COLWHITE)
		end
		
	end
	
	if m.open then
		for nb,entry in pairs(m.open) do
			DrawFilledRect(m.open.rectEntries,COLGREY)
			DrawRect(m.open.rectEntries,COLLIGHTGREY)
			DrawFilledRect(m.open.rectLink,COLGREY)
			
			for nb, entry in pairs(m.open.entry) do
				if entry.OnClick then
					local hover = (m.selectedEntry == entry)
					
					if hover then
						DrawFilledRect(entry.rectBack,COLLIGHTGREY)
					end
					
					if a and entry.menuPos then						
						DrawText(entry.posText.x + entry.menuPos, entry.posText.y + 1, "_", COLWHITE)
					end
					
					DrawText(entry.posText.x, entry.posText.y, entry.textLeft,hover and COLWHITE or COLDARKWHITE)
					DrawText(entry.posKey.x, entry.posKey.y, entry.textRight,hover and COLWHITE or COLDARKWHITE)
					if entry.radio == "TOOGLE" then
						DrawText(entry.posSymbol.x, entry.posSymbol.y, entry.checked and "\x13" or "\x1b", entry.checked and COLGREEN or COLDARKWHITE)
					elseif entry.radio then
						DrawText(entry.posSymbol.x, entry.posSymbol.y, entry.checked and "\x11" or "\x1b", entry.checked and COLGREEN or COLDARKWHITE)
					end
					
					
					
				else
					DrawFilledRect(entry.rectBack,COLLIGHTGREY)
					if entry.text != "" then
						DrawFilledRect(entry.rectText,COLGREY)
						DrawText(entry.posText.x, entry.posText.y, entry.textLeft,COLLIGHTGREY)
					end
				end
				
			end
		end		
	end
		
	return true
end

function menu.HasFocus(m)
	return m.open != nil
end

local _mLock

function menu.Close(m)
	if m.open then
		m.open = nil
		_mLock = nil
	end
end

function menu.MouseDown(m, mx, my, button, clicks)
	if button == "LEFT" then
		local point = {x = mx, y = my}
		
		if not m.open and my < m.size then
			-- click on menu bar
			for nb,sub in pairs(m.current.entry) do
				if SDL.Rect.ContainsPoint(sub.rectBack, point) then
					m.open = sub
					_mLock = "MENUBAR"
					m.selectedEntry = nil
					m.doKeyboard = false
					return true
				end
			end
			
			
		elseif m.open and not SDL.Rect.ContainsPoint(m.open.rectEntries, point) then
			m.open = nil
			return true
		end
	end	
	
	return m.open != nil
end
function menu.MouseUp(m, mx, my, button, clicks)
	if m.open and button == "LEFT" then
		local point = {x = mx, y = my}
		for nb, entry in pairs(m.open.entry) do
			if entry.OnClick and SDL.Rect.ContainsPoint(entry.rectBack, point) then
				entry:SetRadio()
				SecureCall( entry.OnClick, entry)
				m.open = nil
				_mLock = nil
				return true
			end
		end	
		
		if not _mLock then 
			m.open = nil
		else
			_mLock = nil
		end
	end


	return m.open != nil
end
function menu.MouseMove(m, mx, my, button)
	if m.open then
		local point = {x = mx, y = my}
		
		if my < m.size then		
			if not m.doKeyboard then
				m.selectedEntry = nil
			end
			for nb,sub in pairs(m.current.entry) do
				if SDL.Rect.ContainsPoint(sub.rectBack, point) then
					m.open = sub
					if m.doKeyboard then
						m.selectedEntry = sub.entry[1]
					end
					return true
				end
			end

		else
			for nb, entry in pairs(m.open.entry) do
				if entry.OnClick and SDL.Rect.ContainsPoint(entry.rectBack, point) then
					m.selectedEntry = entry
					return true
				end
			end
			if not m.doKeyboard then
				m.selectedEntry = nil
			end
		end
	end	
	return m.open != nil
end

function menu.Get(m)
	return m.current
end

function menu.GetId(m,id)
	for nb,sub in pairs(m.current.entry) do
		for nb,entry in pairs(sub.entry) do
			if id == entry.id then
				return entry
			end
		end
	end
	return nil
end

function menu.IsCheckd(m,id)
	local entry = m:GetId(id)
	return (entry and entry.checked)
end

function menu.KeyDown(m, sym, scan, mod)
	local s = mod:hasflag("SHIFT") > 0
	local c = mod:hasflag("CTRL") > 0
	local a = mod:hasflag("ALT") > 0

	if a and not c and not s then
		if not m.open then
			for nb,sub in pairs(m.current.entry) do
				if sub.menuKey == sym then
					m.open = sub
					m.selectedEntry = sub.entry[1]
					m.doKeyboard = true
					return true
				end
			end
			
		else
			for nb, entry in pairs(m.open.entry) do
				if entry.menuKey == sym then
					entry:SetRadio()
					SecureCall( entry.OnClick, entry)
					m.open = nil
					_mLock = nil
					return true
				end
			end
		end
	end
	
	if not a and not c and not s and m.open then
		if not m.selectedEntry then
			m.selectedEntry = m.open.entry[1]
		else
			if scan == "UP" or scan == "DOWN" then
				repeat
					m.selectedEntry = m.open.entry[math.rotate(m.selectedEntry.pos + (scan == "UP" and -1 or 1), 1, #m.open.entry)]
				until m.selectedEntry.OnClick
			end
			
			if scan == "LEFT" or scan == "RIGHT" then
				m.open = m.current.entry[ math.rotate( m.open.pos + (scan == "LEFT" and -1 or 1), 1, #m.current.entry) ]
				m.selectedEntry = m.open.entry[ math.clamp(m.selectedEntry.pos, 1, #m.open.entry) ]
				while (not m.selectedEntry.OnClick) do
					m.selectedEntry = m.open.entry[math.rotate(m.selectedEntry.pos + 1, 1, #m.open.entry)]
				end				
			end
			
			if scan == "RETURN" or scan == "SPACE" then
				if m.selectedEntry.OnClick then
					m.selectedEntry:SetRadio()
					SecureCall( m.selectedEntry.OnClick, m.selectedEntry)
					m.open = nil
					_mLock = nil
					return true
				end
			end
			
			if scan == "ESCAPE" then
				m.open = nil
				_mLock = nil
				return true
			end
			
		end
	end	
	
	for nb,sub in pairs(m.current.entry) do
		for nb,entry in pairs(sub.entry) do
			if (entry.sym == sym or entry.scan == scan) and entry.ctrl == c and entry.shift == s and entry.alt == a then
				entry:SetRadio()
				SecureCall( entry.OnClick, entry)
				m.open = nil
				_mLock = nil			
				return true
			end
		end
	end
	
	return menu.open != nil
end

function menu.KeyUp(m, sym, scan, mod)
	return menu.open != nil
end

function menu.Input(m, str)
	return menu.open != nil
end

function menu.Call(m,id,...)
	local entry = m:GetId(id)
	if entry and entry.id == id and entry.OnClick then
		return true, SecureCall( entry.OnClick, entry,...)
	end
	return false
end

function menu.CreateBar(m)
	local bar = { 
		entry = {},
		parent = m,
	}
	setmetatable(bar,metaBar)
	return bar
end

function metaBar.Destroy(bar,text)
	for key,value in pairs(bar) do
		bar[key] = nil
	end	
	setmetatable(bar,nil)
end

function metaBar.Add(bar,text)
	local sub = {
		text = text, 
		entry ={},
		parent = bar
	}
	setmetatable(sub,metaSub)
	table.insert(bar.entry, sub)
	return sub
end

function metaBar.Set(bar,id,flag)
	local entry = bar.parent:GetId(id)
	if entry then
		if flag != nil then
			entry.checked = flag
		else
			entry:SetRadio()
		end
	end
end

function metaSub.Add(sub,id,text,fn,key,radio)
	key = key or ""
	local m1, m2, k, s = key:match("([^%+]-)%+?([^%+]-)%+?([^%+]-)$")
	if k:sub(1,1) == "$" then
		s = k:sub(2)
		k = nil
	end

	local entry = {
		parent = sub,
		id = id,
		text = text or "",
		checked = false,
		sym = k, 
		scan = s, 
		ctrl = (m1 == "CTRL" or m2 == "CTRL"), 
		shift = (m1 == "SHIFT" or m2 == "SHIFT"), 
		alt = (m1 == "ALT" or m2 == "ALT"),
		OnClick = fn,
		radio = radio,
	}
	setmetatable(entry,metaEntry)
	table.insert(sub.entry, entry)
	return entry
end

function metaEntry.SetRadio(entry)
	if entry.radio == "TOOGLE" then		
		entry.checked = not entry.checked
	elseif type(entry.radio) == "string" then
		for nb, e in pairs(entry.parent.entry) do
			if e.radio == entry.radio then
				e.checked = (e==entry)
			end
		end	
	end	
end


-- Add File-Menu to a bar
function metaBar.AddFile(bar)
	local mFile = bar:Add("File")
	--***************************
	mFile:Add("new", "New \t ctrl+n", function(e) FilesNew() end, "CTRL+N")
	mFile:Add("open", "Open ... \t ctrl+o", function(e) FilesOpen() end, "CTRL+O")	
	mFile:Add("save", "Save \t ctrl+s", function(e) FilesSave(true) end, "CTRL+S")	
	mFile:Add("saveas", "Save as... \t F12", function(e) FilesSave() end, "F12")
	mFile:Add("reload", "Reload \t ctrl+r", function(e) FilesReload() end, "CTRL+R")
	mFile:Add("close", "Close \t ctrl+w", function (e) FilesRemove() end, "CTRL+W")
	--mFile:Add()
	mFile:Add("file_export","Export")
	mFile:Add("export_spritessheet", "Spritesheet image",
		function (e)
			local file = RequestSaveFile(window, "Export spritesheet image", "spritesheet.png", FILEFILTERIMAGE)
			if file == nil then return false end
			data,pitch = SurfaceLock( surfaceCache128x128 )
			activePico:SpriteRender(data, pitch, true)
			SurfaceUnlock( surfaceCache128x128 )			
			SurfaceSave(surfaceCache128x128, file)
		end
	)
	mFile:Add("export_label", "Label image",
		function (e)
			local file = RequestSaveFile(window, "Export label image", "label.png", FILEFILTERIMAGE)
			if file == nil then return false end
			data,pitch = SurfaceLock( surfaceCache128x128 )
			activePico:LabelRender(data, pitch, true)
			SurfaceUnlock( surfaceCache128x128 )			
			SurfaceSave(surfaceCache128x128, file)
		end
	)
	mFile:Add("export_charset", "Font image",
		function (e)
			local file = RequestSaveFile(window, "Export font image", "font.png", FILEFILTERIMAGE)
			if file == nil then return false end
			data,pitch = SurfaceLock( surfaceCache128x128 )
			activePico:CharsetRender(data,pitch)
			SurfaceUnlock( surfaceCache128x128 )			
			SurfaceSave(surfaceCache128x128, file)
		end
	)
	mFile:Add("export_map", "Map image",
		function (e)
			local file = RequestSaveFile(window, "Export map image", "map.png", FILEFILTERIMAGE)
			if file == nil then return false end
			ImageSaveMap(file)
		end
	)
	
	mFile:Add("file_import","Import")
	----------------------------------------------------------
	mFile:Add("import_spritessheet", "Spritesheet image",
		function (e)
			local file = RequestOpenFile(window, "Import spritesheet image", "spritesheet.png", FILEFILTERIMAGE)
			if file == nil then return false end
			
			ImageLoad128x128(
				file, 
				function(r,g,b) return activePico:ColorNearestPalette(r, g, b) end, 
				function(col) local c = activePico:PaletteGetRGB(col) return c.r, c.g, c.b end,
				activePico:Peek(Pico.SPRITEPOS) << 8
			)			
			
		end
	)
	mFile:Add("import_label", "Label image",
		function (e)
			local file = RequestOpenFile(window, "Import label image", "label.png", FILEFILTERIMAGE)
			if file == nil then return false end
			
			ImageLoad128x128(
				file, 
				function(r,g,b) return activePico:ColorNearest(r, g, b) end, 
				function(col) local c = Pico.RGB[col] return c.r, c.g, c.b end,
				Pico.LABEL
			)
			
			
		end
	)
	mFile:Add("import_Charset", "Font image",
		function (e)
			local file = RequestOpenFile(window, "Import font image", "font.png", FILEFILTERIMAGE)
			if file == nil then return false end
			
			ImageLoadCharset(file)			
			
		end
	)
	mFile:Add("import_map", "Map image",
		function (e)
			local file = RequestOpenFile(window, "Import map image", "map.png", FILEFILTERIMAGE)
			if file == nil then return false end
			
			ImageLoadMap(
				file, 
				function(r,g,b) return activePico:ColorNearest(r, g, b) end, 
				function(col) local c = Pico.RGB[col] return c.r, c.g, c.b end
			)
			
			
		end
	)
	mFile:Add()
	---------------------------------------------
	mFile:Add("exit", "Exit \t alt+f4",
		function (e)
			SDL.Event.Push( {type="QUIT",timestamp=0} )
		end
	)
		
	
	return mFile
end

-- Add Edit-Menu to a bar
function metaBar.AddEdit(bar)
	local mEdit = bar:Add("Edit")
	--***************************
	mEdit:Add("undo", "Undo \t ctrl+z",
		function (e)
			local done, luaChanges = activePico:Undo() 
			if done then												
				MainWindowResize()
				ModulesCall("Undo")
				if luaChanges then
					InfoBoxSet("Undo Lua code.")
				else
					InfoBoxSet("Undo")
				end
			end
		end,
		"CTRL+Z"
	)		
	mEdit:Add("redo", "Redo \t ctrl+y",
		function (e)
			local done, luaChanges =activePico:Redo() 
			if done then														
				MainWindowResize()
				ModulesCall("Redo")
				if luaChanges then
					InfoBoxSet("Redo Lua code.")
				else
					InfoBoxSet("Redo")
				end
			end
		end,
		"CTRL+Y"
	)
	mEdit:Add("copy", "Copy \t ctrl+c",
		function (e)
			local str
			if popup:HasFocus() then
				str = popup:Copy()
				if str != "" and str then
					InfoBoxSet("Copied '"..str.."'.")
				end
				
			elseif ModulesCallSub("inputs","HasFocus") then
				str =  ModulesCallSub("inputs", "Copy")
				if str != "" and str then
					InfoBoxSet("Copied '"..str.."'.")
				end
			else
				str = ModulesCall("Copy")
			end
			
			
			if str != "" and str then
				SDL.Clipboard.SetText(str)
			end
		end,
		"CTRL+C"
	)
	
	mEdit:Add("copyHey", "Copy as Hex \t shift+ctrl+c",
		function (e)
			local str
			
			if not popup:HasFocus() and not ModulesCallSub("inputs","HasFocus") then				
				str = ModulesCall("CopyHex")
			end			
			
			if str != "" and str then
				SDL.Clipboard.SetText(str)
			end
		end,
		"CTRL+SHIFT+C"
	)
	
	
	mEdit:Add("cut", "Cut \t ctrl+x",
		function (e)
			local str
			if popup:HasFocus() then
				str = popup:Copy()
				if str != "" and str then
					InfoBoxSet("Copied '"..str.."'.")
				end
				
			elseif ModulesCallSub("inputs","HasFocus") then
				str =  ModulesCallSub("inputs", "Copy")
				if str != "" and str then
					InfoBoxSet("Copied '"..str.."'.")
				end
			else
				str = ModulesCall("Copy")
			end
			if str != "" and str then
				SDL.Clipboard.SetText(str)
				ModulesCall("Delete")
			end
		end,
		"CTRL+X"
	)
	mEdit:Add("paste", "Paste \t ctrl+v",
		function (e)
			if SDL.Clipboard.HasText() then 
				local str = SDL.Clipboard.GetText()
				if str:sub(1,6) == "[cart]" and str:sub(-7) == "[/cart]" then
					-- a cart has been pasted
					
					-- create a temp file
					local name = os.tmpname()
					local fin = io.open(name,"w+b")
					if fin then
						str = str:sub(7,-8)
						for i = 1,#str,2 do
							fin:write( string.char(tonumber("0x" .. str:sub(i,i+1)) or 0) )
						end						
						fin:close()
						
						-- load temp file as png
						FilesOpen(name, true)
						
						-- and remove it
						os.remove(name)
					end
				
				elseif popup:HasFocus() then
					popup:Paste(str)
				elseif not ModulesCallSub("inputs", "Paste", str) then 
					ModulesCall("Paste", str)
				end
			end
		end,
		"CTRL+V"
	)
	
	mEdit:Add("pasteHex", "Paste Hex \t shift+ctrl+v",
		function (e)
			if SDL.Clipboard.HasText() then 
				local str = SDL.Clipboard.GetText()
				if not popup:HasFocus() and not ModulesCallSub("inputs","HasFocus") then
					ModulesCall("PasteHex", str)
				end
			end
		end,
		"CTRL+SHIFT+V"
	)
	
	
	mEdit:Add("delete", "Delete \t del",
		function (e)
			if not inputs:HasFocus() then	
				ModulesCall("Delete")					
			end
		end
		-- keyboard shortcut is handled directly in main!
	)
	mEdit:Add("selectAll", "Select all \t ctrl+a",
		function (e)
			ModulesCall("SelectAll")
		end,
		"CTRL+A"
	)	
		
	return mEdit
end

-- Add Pico-8-Menu to a bar
function metaBar.AddPico8(bar)
	local mPico = bar:Add("Pico-8")
	--****************************
	mPico:Add("run", "Save and Run\t F5", 
		function (e)	
			FilesRun()
		end,
		"F5"
	)
	mPico:Add("export", "Export..",
		function (e)
			FilesExport()
		end,
		nil
	)
	mPico:Add()
	mPico:Add("pico8execute", "Set Pico8 executeable",
		function(e)
			PicoRemoteSetting()
		end
	)
	
	mPico:Add("writeProtectedPico8", "Write protect while running", 
		function(e)
			config.writeProtectedPico8 = e.checked
		end,
		nil,
		"TOOGLE"
	)
	
	mPico:Add("doRemote", "Use pico 8 remote for audio",
		function (e)
			config.doRemote = e.checked
			if config.doRemote then
				config.doRemote = PicoRemoteStart()
			else
				PicoRemoteStop()
			end
		end,
		nil,
		"TOOGLE"
	)	
		
	mPico:Add("resetPalette", "Reset palette to default",
		function (e)
			for i=0, Pico.PALLEN - 1 do
				activePico:Poke(Pico.PAL + i, i)
			end
		end
	)
end

-- Add Modules-Menu to a bar
function metaBar.AddModule(bar)
	local mModule = bar:Add("Modules")
	for nb,m in pairs(modules) do
		local key = nil
		if nb < 10 then
			key = "CTRL+"..nb
		elseif nb == 10 then
			key = "CTRL+0"
		end
	
		mModule:Add("Module" .. m.name, m.name.."\t ".. (key or ""), 
			function (e)
				ModuleActivate(m)
			end,
			key,
			"modules"
		)		
	end
end

-- Add Zoom-Menu to a bar
function metaBar.AddZoom(bar)	
	local menuZoom = bar:Add("Zoom")
	--*************************
	for nb,z in pairs(zoomLevels) do
		local e = menuZoom:Add(z[1], z[3],
			MenuSetZoom,
			nil,
			"zoom"
		)
		e.index = z[1]
		
	end
	menuZoom:Add()
	menuZoom:Add("autooverviewzoom", "Automatic zoom on sprite/font/label",
		function (e)
			config.doAutoOverviewZoom = not e.checked
		end,
		nil,
		"TOOGLE"
	)
	
	return menuZoom
	
end

-- Add Settings-Menu to a bar
function metaBar.AddSettings(bar)
	local mSettings = bar:Add("Options")
	--***********************************
	
	mSettings:Add("sizeAsHex", "Use hex values for size",
		function (e)
			config.sizeAsHex = e.checked
		end,
		nil,
		"TOOGLE"
	)		
	
	
	mSettings:Add()
	
	mSettings:Add("doDithering", "use dithering",
		function (e)
			config.doDithering = e.checked
		end,
		nil,
		"TOOGLE"
	)
	
	mSettings:Add("doDitheringFloydSteinberg", "  use Floyd-Steinberg for dithering",
		function(e)
			config.doDitheringFloydSteinberg = e.checked
		end,
		nil,
		"TOOGLE"
	)			
			
	mSettings:Add("doColorOptimization", "optimize color palette when importing spritesheet",
		function (e)
			config.doColorOptimization = e.checked
		end,
		nil,
		"TOOGLE"
	)
	
	mSettings:Add("doGreyScale", "'black & white' import",
		function (e)
			config.doGreyScale = e.checked
		end,
		nil,
		"TOOGLE"
	)
	
	mSettings:Add("saveTransparentBlack", "Save transparent black on images",
		function (e)
			config.saveTransparentBlack = e.checked
		end,
		nil,
		"TOOGLE"
	)
	
	return mSettings
end

-- Add Debug-Menu to a bar
function metaBar.AddDebug(bar)
	local mDebug = bar:Add("Debug")
	mDebug:Add("dodebug","Start debug", 
		function(e)
			print("Type 'cont' for continue")
			debug.debug ()
		end, 
		nil
	)
	mDebug:Add()
	mDebug:Add("debugmsg","Show debug messages",
		function(e)
			config.debug = e.checked
			ConsoleShow(config.debug)
			MainWindowTitle()
		end,
		nil,
		"TOOGLE"
	)
end	


local _menuZoomCurrent

-- Set zoom level (id or pixel)
function MenuSetZoom(id)
	if type(id) == "table" then
		id = id.index
	end
	id = id or _menuZoomCurrent

	for nb,z in pairs(zoomLevels) do
		if z[1] == id or z[2] == id then
			-- change entry in the menu bar
			menu.current:Set(z[1])			
			-- set zoom
			_menuZoomCurrent = z[2]
			ModulesCall("ZoomChange", z[2] )
			return true
			
		end
	end

	return false
end

-- return current zoom level
function MenuGetZoom(id)
	return _menuZoomCurrent
end

-- "scroll" through zoom levels
function MenuRotateZoom(up)
	if not config.doAutoOverviewZoom then return false end
	
	-- select maximum/minimum
	local sel = up and zoomLevels[#zoomLevels][2] or zoomLevels[1][2]
		
	-- scan if a zoom level is higher than current but lower than selected
	for nb,z in pairs(zoomLevels) do
		if (up and _menuZoomCurrent < z[2] and z[2] < sel) or (not up and _menuZoomCurrent > z[2] and z[2] > sel)   then
			sel = z[2]
		end			
	end

	-- activate selected 
	if sel != _menuZoomCurrent then 
		MenuSetZoom(sel)
	end
end

return menu