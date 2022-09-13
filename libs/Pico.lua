
Lib={}
Lib.__index = Lib

local ___ = {}

--  0x5f4c - current button states - 8 Bytes - we need simple some space to store it...
___.CUSTOMPOS = 0x5f4c
___.CUSTOMPOSLEN =  8
___.DEFAULTCUSTOMPOS = "3132300000000000"

Lib.FontAdjust  = {1,2,3,-4,-3,-2,-1,[0]=0}
Lib.FontAdjustRev = {[0]=0,[1]=1,[2]=2,[3]=3,[-4]=4,[-3]=5,[-2]=6,[-1]=7}

Lib.SPRITE      = 0x0000
Lib.SPRITEPOS   = 0x5F54
Lib.SPRITELEN   = 0x2000
Lib.MAPPOS 		= 0x5F56-- 0x10-0x2f, 0x80-0xff 
Lib.MAPWIDTH 	= 0x5F57
Lib.PAL 		= 0x5F10
Lib.PALLEN		= 0x0010
Lib.CHARSET		= 0x5600
Lib.CHARSETLEN  = 0x0800 
Lib.LABEL		= 0x6000
Lib.LABELLEN	= 0x2000
Lib.SFX			= 0x3200
Lib.SFXLEN		= 0x1100
Lib.SFXPOS		= ___.CUSTOMPOS + 1
Lib.MUSIC		= 0x3100
Lib.MUSICLEN    = 0x0100
Lib.MUSICPOS	= ___.CUSTOMPOS
Lib.SPRFLAG		= 0x3000
Lib.SPRFLAGLEN  = 0x0100
Lib.SPRFLAGPOS  = ___.CUSTOMPOS + 2
Lib.FREEMEM		= 0x4300
Lib.FREEMEMLEN  = 0x1300
Lib._license="0.1 by gpi"


___.METARAMDATA = "meta:4f78820c-0dc1-11ed-861d-0242ac120002"
___.METASAVEDATA    = "meta:1bdaec14-d23c-4c68-9cbb-45d80342eabf"
___.PICO8HEADER = "pico-8 cartridge // http://www.pico-8.com"
___.PICO8VERSION = 38 --2.5c


-- render spritesheet/label to sdl-data-object
function ___.Render(pico, index, data, pitch, dontRedrawFlag)
	if not dontRedrawFlag then
		pico[index.."RedrawNeeded"] = false
	end
	
	local isSprite = index == "sprite"
	if isSprite then
		padr = pico:Peek(Lib.SPRITEPOS) << 8
	else
		padr = Lib.LABEL
	end
	
	local adr,col
	for y=0, 127 do
		adr = pitch * y
		for x=0, 63 do -- two pixel in one byte!
			col = pico:Peek(padr) & 0xf
			if isSprite then
				col = pico:PaletteGetColor(col)
			end
			data:setu32(adr, ___.RGBHEX[col] & ( (isSprite and col==0) and 0x00ffffff or 0xffffffff)) -- color 0 on sprite is transparent!
			adr+=4
			
			col = (pico:Peek(padr)>>4)
			if isSprite then
				col = pico:PaletteGetColor(col)
			end				
			data:setu32(adr,___.RGBHEX[col] & ( (isSprite and col==0) and 0x00ffffff or 0xffffffff) ) -- color 0 on sprite is transparent!
			adr+=4
			padr+=1
		end
	end

end

--==========================================================================================
--------------------------------------------------------------------------------------Memory
--==========================================================================================

-- MemoryReset memory to default settings
function ___.MemoryReset(pico)
	pico:LuaReplace(0, pico:LuaLen()+1, "\n")
	pico.raw={lua = pico.raw.lua} -- reset all other metas
	pico.saveData={}
	pico.version = ___.PICO8VERSION
	for i=0,0xffff do
		if i == Lib.MAPPOS then
			pico:Poke(i,0x20)
		elseif i == Lib.MAPWIDTH then
			pico:Poke(i,128)
		elseif i >= Lib.PAL and i < Lib.PAL + Lib.PALLEN then
			pico:Poke(i,i-Lib.PAL)
		elseif i >= Lib.MUSIC and i < Lib.MUSIC + Lib.MUSICLEN then
			pico:Poke(i,0x40)
		elseif (i >= Lib.CHARSET and i < Lib.CHARSET + Lib.CHARSETLEN) then
			if i == Lib.CHARSET then
				pico:CharsetSetDefault()
			end
		elseif (i >= ___.CUSTOMPOS and i < ___.CUSTOMPOS + ___.CUSTOMPOSLEN) then
			if i == ___.CUSTOMPOS then
				pico:PokeHex(___.CUSTOMPOS, ___.DEFAULTCUSTOMPOS)
			end
		else
			pico:Poke(i,0)
		end
	end	
end

-- checks if the memory is empty
function ___.MemoryIsEmpty(pico,adr,size)
	for i = adr,adr + size - 1 do
		if pico:Peek(i) != 0 then 
			return false 
		end
	end
	return true
end

-- change value in memory - also handle undo and changes in sprites and so on
function Lib.Poke(pico,adr,value)

	if pico.writeProtected then return false end

	-- round adress
	adr=tonumber(adr) \ 1
	if adr<0 or adr>0xffff then
		return false
	end
	-- limit value
	value &= 0xff
		
	if pico.memory[adr] != value then
		-- changed memory -> change diffrent status 
		local gfxadr = pico.memory[pico.SPRITEPOS] << 8
		local sfxadr = pico.memory[pico.SFXPOS] << 8
		local mapadr = pico.memory[Lib.MAPPOS] << 8
		if adr == Lib.SPRITEPOS or 
		  (adr >= gfxadr      and adr < gfxadr      + Lib.SPRITELEN) or 
		  (adr >= Lib.PAL     and adr < Lib.PAL     + Lib.PALLEN)    then pico.spriteRedrawNeeded = true end
		if adr >= Lib.LABEL   and adr < Lib.LABEL   + Lib.LABELLEN   then pico.labelRedrawNeeded = true end
		if adr >= Lib.CHARSET and adr < Lib.CHARSET + Lib.CHARSETLEN then pico.charsetRedrawNeeded = true end
		if adr >= sfxadr      and adr < sfxadr      + Lib.SFXLEN     then pico.validSFX[ (adr-sfxadr) \ 68 ] = false end
		if adr == Lib.SFXPOS then for i=0,63 do pico.validSFX[ i ] = false end end				
		if adr == Lib.MAPPOS or 
		  (mapadr < 0x8000 and adr >= 0x1000 and adr <= 0x3000) or 
		  (mapadr >= 0x8000 and adr >= mapadr) then
			pico.recountNeeded = true
		end	
		
		-- update undo-values
		if pico.undoMemoryCached[adr] == nil then 
			pico.undoMemoryCached[adr] = true
			if adr != pico.undoAdr then
				pico.undoValues._pico ..= string.format("@%04x", adr)				
			end
			pico.undoAdr = adr + 1
			pico.undoValues._pico ..= string.format("%02x", pico.memory[adr])
			pico.undoValid = true
		end
		
		-- set memory
		pico.memory[adr]=value		
		
		--pico.saved = false
		pico:SetSaved(false)
	end
	return true
end

-- return a value in memory
function Lib.Peek(pico,adr)
	adr=math.tointeger(adr)
	if adr<0 or adr>0xffff then
		return 0
	end
	return pico.memory[adr]
end

-- Poke a hexstring to memory
function Lib.PokeHex(pico, adr, str, limit)
	limit = math.min( limit or (#str\2), #str\2)
	for i = 1,limit * 2,2 do
		pico:Poke(adr, tonumber( "0x".. str:sub(i,i+1) ) or 0 )
		adr +=1
	end
end

-- return a hexstring from memory
function Lib.PeekHex(pico, adr, size)
	local ret = ""
	for i=0, size - 1 do
		ret ..= string.format("%02x", pico:Peek(adr + i))
	end
	return ret
end

-- compare memory mit hex-string
function Lib.MemoryCompareHex(pico, adr, str, limit)
	limit = math.min( limit or (#str\2), #str\2)
	for i = 1,limit * 2,2 do
		if 	pico:Peek(adr) != (tonumber( "0x".. str:sub(i, i+1) ) or 0) then
			return false
		end
		adr +=1
	end
	return true
end

-- Poke a escaped string to memory
function Lib.PokeChar(pico, adr, str, limit)
	local endLimit = adr + (limit or #str) -- #str is bigger than needed, because of escape sequences
	local pos = 1
	while pos <= #str and adr < endLimit do
		local c = nil
		-- search next valid char / escaped utf8-sequenz
		for nb,seq in pairs(___.PICOCHARSESCAPED) do
			if str:sub(pos, pos + #seq - 1) == seq then
				-- found code
				c = nb
				pos += #seq
		
				-- \0 can be \000! skip additional optional 0
				if c == 0 and str:byte(pos) == 48 and str:byte(pos + 1) == 48 then
					pos += 2
				end
				break
			end
		end
		if c == nil then
			-- error in string -> quit
			return false
		end
		-- Poke value
		pico:Poke(adr, c)
		adr += 1
	end	
	return true
end

-- Peek a escaped string from memory
function Lib.PeekChar(pico,adr,size)
	local zero = false
	local ret = ""
	for i = 0,size-1 do
		local c = pico:Peek(adr + i)
		if zero and c>=0x30 and c<=0x39 then -- numbers!
			ret ..="00"
			zero = false
		end
		if c == 0 then
			zero = true
			ret ..= "\\0"
		else
			ret ..= ___.PICOCHARSESCAPED[c]
			zero = false
		end
		
	end
	return ret
end

-- peek a string
function Lib.PeekString(pico, adr, size)	
	return string.char( table.unpack(pico.memory,adr,adr+size-1))
end

-- poke a string
function Lib.PokeString(pico, adr, str)
	for nb,code in str:codes() do
		pico:Poke(adr, code)
		adr += 1
	end
end

-- Poke 16bit value
function Lib.Poke2(pico,adr,value)
	pico:Poke(adr+1, (value>>8) & 0xff)
	pico:Poke(adr, value & 0xff)
	return true
end

-- Peek a 16 bit value
function Lib.Peek2(pico,adr)
	return (pico:Peek(adr + 1) << 8) + pico:Peek(adr)
end

-- Poke a 32 bit value - pico-style (float 0x0000.0000)
function Lib.Poke4(pico,adr,value)
	value *= 0x10000
	pico:Poke(adr+3, (value>>24) & 0xff)
	pico:Poke(adr+2, (value>>16) & 0xff)
	pico:Poke(adr+1, (value>>8) & 0xff)
	pico:Poke(adr  , value & 0xff)
	return true
end

-- Peek a 32 bit value - pico-style
function Lib.Peek4(pico,adr)
	return ( (pico:Peek(adr+3)<<24) + (pico:Peek(adr+2)<<16) + (pico:Peek(adr+1)<<8) + pico:Peek(adr) ) / 0x10000
end

-- Poke a 32 bit value 
function Lib.Poke32(pico,adr,value)
	pico:Poke(adr+3, (value>>24) & 0xff)
	pico:Poke(adr+2, (value>>16) & 0xff)
	pico:Poke(adr+1, (value>>8) & 0xff)
	pico:Poke(adr  , value & 0xff)
	return true
end

-- Peek a 32 bit value
function Lib.Peek32(pico,adr)
	adr=math.tointeger(adr)
	if adr<0 or adr>0xfffc then
		return false
	end
	return ( (pico:Peek(adr+3)<<24) + (pico:Peek(adr+2)<<16) + (pico:Peek(adr+1)<<8) + pico:Peek(adr) ) 
end

-- Set Memory to value
function Lib.MemorySet(pico, adr, value, size)
	for x = adr,adr + size - 1 do
		pico:Poke(x, value)
	end
end

--==========================================================================================
----------------------------------------------------------------------------------------main
--==========================================================================================

-- create a new pico8 "instance"
function Lib.Create(renderer)
	local pico = { 
		raw = {lua = "\n"},
		undoIDCount = 0,
		undoID = 0,
		undoIDSaved = -1,
		renderer = renderer,
		saveData={}, -- additional data in key=value format
		undoFunc={}, -- a custom undo action
		undoValues={ _pico = "", _lua = {} }, -- custom undo
		undoValid = false, -- current created undo is valid
		undoAdr = -1, -- current undo-scan-adress
		count = {}, -- how often a sprite is used in the map
		redoCache={}, -- all redo-action
		undoCache={}, -- all undo-action
		memory={}, -- memory
		undoMemoryCached={}, -- memoryposition is stored in current undo-scan
		spriteRedrawNeeded=false, 
		labelRedrawNeeded=false, 
		recountNeeded=true, -- mp has changed
		validSFX={}, -- texture of sfx is valid / up to date
		emptySFX={}, -- sfx is empty (texture muss be created)
		dominateSFX={}, -- dominate Wave form in SFX (texture muss be created)
		writeProtected = false,
	}
	for i=0,0xffff do
		pico.memory[i] = i % 256 -- fill with random - just for fun :) - we need a value - any value will do it!
	end

	setmetatable(pico,Lib)
	
	___.MemoryReset(pico)
	
	-- reset undo		
	___.UndoResetValues(pico)
	
	pico.redoCache = {}
	pico.undoCache = {}
	pico:SetSaved()
	
	return pico
end

-- Destroy pico
function Lib.Destroy(pico)
	-- at the moment, nothing to do
end
		
-- Set a additonal data in key-value-format
function Lib.SaveDataSet(pico, name, key, value)
	if pico.writeProtected then return false end
	
	-- create a empty table if not present
	if pico.saveData[name] == nil then
		pico.saveData[name] = {}
	end
	if (type(value) != "table" and pico.saveData[name][key] != value) or (type(value) == "table" and not table.compare(pico.saveData[name][key], value)) then
		-- add a custom undo action
		if not (pico.saveData[name][key] == nil and value == "") then -- replace nil with "" should not perform an undo-action!
			pico:UndoSetCustom(
				"_savedata", 
				function (x)
					-- 1 = saveData.name tabel, 2 = key, 3 = value
					local ret = {x[1],x[2],x[1][x[2]]}
					x[1][x[2]] = x[3]
					return ret
				end,
				{pico.saveData[name], key, pico.saveData[name][key]}
			)
		end
		if type(value) == "table" then
			pico.saveData[name][key] = table.copy(value) -- save a copy!
		else
			pico.saveData[name][key] = value
		end
	end
end

-- Return a saved data in key-value-format		
function Lib.SaveDataGet (pico,name,key)
	if pico.saveData[name] == nil then
		pico.saveData[name] = {}
	end
	if type(pico.saveData[name][key]) == "table" then
		return table.copy(pico.saveData[name][key])
	else
		return pico.saveData[name][key]
	end
end

-- Empty -> when no undo/redo exist
function Lib.IsEmpty(pico)
	return pico.undoValid == false and #pico.undoCache == 0 and #pico.redoCache == 0
end

-- pico has saved?
function Lib.IsSaved (pico)
	return pico.saved
end

-- set save state
function Lib.SetSaved (pico, state)
	state = (state == nil) and true or state	

	if state then
		pico:UndoAddState()
		-- store ID for restoring saved-state
		pico.undoIDSaved = pico.undoIDCount
	end
	pico.saved = state
end

--==========================================================================================
-----------------------------------------------------------------------------color / palette
--==========================================================================================

-- Pico8 Palette in RGBA-Format (32Bit)
___.RGBHEX = {
	-- original palette
	[0]   = 0xFF000000, [1]   = 0xFF532B1D, [2]   = 0xFF53257E, [3]   = 0xFF518700, [4]   = 0xFF3652AB, [5]   = 0xFF4F575F, [6]   = 0xFFC7C3C2, [7]   = 0xFFE8F1FF, [8]   = 0xFF4D00FF, [9]   = 0xFF00A3FF, [10]  = 0xFF27ECFF, [11]  = 0xFF36E400, [12]  = 0xFFFFAD29, [13]  = 0xFF9C7683, [14]  = 0xFFA877FF, [15]  = 0xFFAACCFF,
	-- extended
	[128] = 0xFF141829, [129] = 0xFF351D11, [130] = 0xFF362142, [131] = 0xFF595312, [132] = 0xFF292F74, [133] = 0xFF3B3349, [134] = 0xFF7988A2, [135] = 0xFF7DEFF3, [136] = 0xFF5012BE, [137] = 0xFF246CFF, [138] = 0xFF2EE7A8, [139] = 0xFF43B500, [140] = 0xFFB55A06, [141] = 0xFF654675, [142] = 0xFF596EFF, [143] = 0xFF819DFF
}

-- search best matching color in the pico8 palettes (all in use)
function Lib.ColorNearestALL(pico, r, g, b, notcol)
	-- ignore this color to get the second best choice
	notcol = notcol or -1
	-- best = lower is better
	local best,col = 200000,0
	
	for i=0,0xf do
		-- normal palette
		local scol = Lib.RGB[i]
		if scol then 
			-- calcualte "distance"
			local dr,dg,db = scol.r - r, scol.g - g, scol.b - b
			-- ingnore sqrt(dr*dr + dg*dg + db*db) - because when x < y is true, sqrt(x) < sqrt(y) is also true
			-- also use luma-geryscale factors 
			local a = dr*dr * 0.299 + dg*dg * 0.587 + db*db * 0.144
			if a < best and notcol != i then
				best = a
				col = i
			end
		end

		-- extended palette, same as above
		local scol = Lib.RGB[i+128]
		if scol then 
			local dr,dg,db = scol.r - r, scol.g - g, scol.b - b
			local a = dr*dr * 0.299 + dg*dg * 0.587 + db*db * 0.144
			if a < best and notcol != i+128 then
				best = a
				col = i+128
			end	
		end
		
	end
	return col	
end

-- search best matching color in the defaul Pico8 palette (Label)
function Lib.ColorNearest(pico, r, g, b, notcol)
	-- comments see ColorNearestALL
	notcol = notcol or -1
	local best,col = 200000,0
	for i=0,0xf do
		local scol = Lib.RGB[i]
		if scol then 
			local dr,dg,db = scol.r - r, scol.g - g, scol.b - b
			local a = dr*dr * 0.299 + dg*dg * 0.587 + db*db * 0.144
			if a < best and notcol != i then
				best = a
				col = i
			end			
		end
	end
	return col	
end

-- search best matching color in the custom Pico8 palette (Sprite)
function Lib.ColorNearestPalette(pico, r, g, b)
	-- comments see ColorNearestALL
	local best,col = 200000,0
	for i=0,0xf do
		local scol = pico:PaletteGetRGB(i)
		if scol then 
			local dr,dg,db = scol.r - r, scol.g - g, scol.b - b
			local a = dr*dr * 0.299 + dg*dg * 0.587 + db*db * 0.144
			if a < best then
				best = a
				col = i
			end			
		end
	end
	return col	
end

-- Color in SDl-Format
Lib.RGB = {}	
for nb,c in pairs(___.RGBHEX) do
	Lib.RGB[nb] = {r = c & 0xff, g= (c>>8) & 0xff, b = (c>>16) & 0xff, a = (c>>24) & 0xff}
end

-- return sdl color of the custom pico8 palette
function Lib.PaletteGetRGB(pico,i)
	return Lib.RGB[pico:Peek( Lib.PAL + (i & 0xf) )]
end

-- set color in palette
function Lib.PaletteSetColor(pico, c1, c2)
	pico:Poke(pico.PAL + (c1 & 0xff), c2 & 0x8f)
end

-- get color in palete
function Lib.PaletteGetColor(pico, c1)
	return pico:Peek(pico.PAL + (c1 & 0xf)) & 0x8f
end


--==========================================================================================
----------------------------------------------------------------------------------------Undo
--==========================================================================================

-- reset current undo - valus
function ___.UndoResetValues(pico)
	pico.undoValues = { _pico = "", _lua = {} }
	pico.undoAdr = -1
	pico.undoValid = false
	pico.undoMemoryCached = {}
end

-- Set a custom pico undo. the function must take the value v and restore with it the old value - and should return the "current" value before overwriting it.
-- see SaveDataSet for an example, only the first call is saved!
function Lib.UndoSetCustom (pico, name, f, v)
	if pico.writeProtected then return false end
	if pico.undoValues[name] then
		return pico.undoValues[name]
	end
	
	local old = pico.undoValues[name]
	pico.undoFunc[name] = f
	pico.undoValues[name] = v
	pico.undoValid = true
	
	pico:SetSaved(false)
	
	return old 
end

-- store all actions with Poke, SaveData and store it in a new undo-sate
function Lib.UndoAddState(pico)
	if pico.writeProtected then return false end
	if pico.undoValid  then
		-- save only 1000 states
		if #pico.undoCache > 1000 then
			table.remove(pico.undoCache,1)
		end
		
		pico.undoIDCount += 1
		pico.undoValues._ID = pico.undoID
		pico.undoID = pico.undoIDCount
			
		-- insert current values in the cache
		table.insert(pico.undoCache, pico.undoValues)			
		
		-- reset current values
		___.UndoResetValues(pico)
		
		-- remove redoCache, if present
		if #pico.redoCache > 0 then
			pico.redoCache = {}
		end			
		
		return true
	end
	return false
end

-- restore an "Undo-State" (values)
function ___.UndoRestoreValues(pico, values)
	local changesLuaCode = false

	-- reset undo values
	___.UndoResetValues(pico)

	-- restore memory
	local i,adr = 1,0
	while i <= #values._pico do
		if values._pico:sub(i,i) == "@" then
			i += 1
			adr = tonumber("0x"..values._pico:sub(i,i+3))
			i += 4
		else
			pico:Poke(adr, tonumber("0x"..values._pico:sub(i,i+1)))
			i += 2
			adr += 1
		end				
	end
	
	-- restore lua
	pico.undoValues._luaCursor = pico._undoCursorPos
	pico.undoValues._luaCursorEnd = pico._undoCursorPosEnd
	pico._undoCursorPos = values._luaCursor
	pico._undoCursorPosEnd = values._luaCursorEnd
	
	for nb,d in ipairs(values._lua) do
		pico:LuaReplace(d[1], d[3], d[2])		
		changesLuaCode = true
	end
	
	-- restore costum undo 
	for n,f in pairs(pico.undoFunc) do
		if values[n] != nil then
			pico.undoValues[n] = f(values[n])
		end
	end
	
	-- correct ids
	pico.undoValues._ID = pico.undoID
	pico.undoID = values._ID
	
	-- now on "saved" state?
	if pico.undoID == pico.undoIDSaved then
		pico.saved = true
	end
	
	return changesLuaCode
end



-- perform an undo
function Lib.Undo(pico)
	if pico.writeProtected then return false end
	-- create a new state, when a value exist
	pico:UndoAddState()
			
	-- no state exist -> quit		
	if #pico.undoCache <= 0 then
		return false
	end
		
	-- restore values
	local luaChanges = ___.UndoRestoreValues(pico, table.remove(pico.undoCache) )
		
	-- add undo-values as redo	
	table.insert(pico.redoCache, pico.undoValues)
		
	-- reset undo values
	___.UndoResetValues(pico)
	return true, luaChanges
end

-- perform an redo
function Lib.Redo(pico)
	if pico.writeProtected then return false end
	-- there are changes? -> redo is not valid
	if pico.undoValid then
		return false
	end
	
	-- no data in redo cache -> exit
	if #pico.redoCache <= 0 then
		return false
	end
		
	-- restore values
	___.UndoRestoreValues(pico, table.remove(pico.redoCache) )
	
	-- save in undo-cache
	table.insert(pico.undoCache, pico.undoValues)
	
	-- reset values
	___.UndoResetValues(pico)
	return true		
end


--==========================================================================================
--------------------------------------------------------------------------String / Character
--==========================================================================================

-- convert a string "{ tabledata }" to a real table
function ___.StringToTable(str)
	-- we use lua to translate it to a "function"
	local myenv = {}	
	local f,err = load("return " .. tostring(str),___.METASAVEDATA,"t",myenv)
	if not f then
		SDL.Request.Message(window, TITLE, tostring(err) ,"OK STOP")
		return {}
	end
	
	-- and call the function in save mode
	local ok,a = pcall(f)
	if not ok then
		SDL.Request.Message(window, TITLE, tostring(a) ,"OK STOP")
		return {}
	end

	-- to return a table
	return a or {}
end

-- convert a table to a string
function ___.TableToString(t, deep)
	-- security-check to prevent endless table-links
	deep=deep or 0
	if deep>10 then return "{}\n" end

	-- not a table, so return a empty table
	if type(t) != "table" then return "{}\n" end
	
	local str = "{\n"	
	for k,v in pairs(t) do
		str ..= string.rep("\t",deep+1)-- indent for better reading
		-- key
		if type(k) == "string" then 
			str ..= "[\"" .. k:escape() .. "\"] = "
		else
			str ..= "["..tonumber(k).."] = "
		end
		-- value
		if type(v)=="table" then
			str ..=  ___.TableToString(v,deep+1) 
		elseif type(v)=="string" then
			str ..= "\"" .. v:escape() .. "\""
		else
			str ..= tostring(v)
		end		
		str ..= ",\n"
	end
	
	return str .. string.rep("\t",deep) .. "}"
end

-- UTF8-Chars for P8SCII
___.PICOCHARS = { 
	[0]="\0", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "\t", "\n", "ᵇ", "ᶜ", "\r", "ᵉ", "ᶠ", 
	"▮", "■", "□", "⁙", "⁘", "‖", "◀", "▶", "「", "」", "¥", "•", "、", "。", "゛", "゜", 
	" ", "!", "\"", "#", "$", "%", "&", "'", "(", ")", "*", "+", ",", "-", ".", "/", 
	"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ":", ";", "<", "=", ">", "?", 
	"@", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", 
	"P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "[", "\\", "]", "^", "_", 
	"`", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", 
	"p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "{", "|", "}", "~", "○", 
	"█", "▒", "🐱", "⬇️", "░", "✽", "●", "♥", "☉", "웃", "⌂", "⬅️", "😐", "♪", "🅾️", "◆", 
	"…", "➡️", "★", "⧗", "⬆️", "ˇ", "∧", "❎", "▤", "▥", "あ", "い", "う", "え", "お", "か", 
	"き", "く", "け", "こ", "さ", "し", "す", "せ", "そ", "た", "ち", "つ", "て", "と", "な", "に", 
	"ぬ", "ね", "の", "は", "ひ", "ふ", "へ", "ほ", "ま", "み", "む", "め", "も", "や", "ゆ", "よ", 
	"ら", "り", "る", "れ", "ろ", "わ", "を", "ん", "っ", "ゃ", "ゅ", "ょ", "ア", "イ", "ウ", "エ", 
	"オ", "カ", "キ", "ク", "ケ", "コ", "サ", "シ", "ス", "セ", "ソ", "タ", "チ", "ツ", "テ", "ト", 
	"ナ", "ニ", "ヌ", "ネ", "ノ", "ハ", "ヒ", "フ", "ヘ", "ホ", "マ", "ミ", "ム", "メ", "モ", "ヤ", 
	"ユ", "ヨ", "ラ", "リ", "ル", "レ", "ロ", "ワ", "ヲ", "ン", "ッ", "ャ", "ュ", "ョ", "◜", "◝"
}

-- escaped variant for transfer over clipboard
___.PICOCHARSESCAPED = { 
	[0]="\\0", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "\\t", "\\n", "ᵇ", "ᶜ", "\\r", "ᵉ", "ᶠ", 
	"▮", "■", "□", "⁙", "⁘", "‖", "◀", "▶", "「", "」", "¥", "•", "、", "。", "゛", "゜", 
	" ", "!", "\\\"", "#", "$", "%", "&", "'", "(", ")", "*", "+", ",", "-", ".", "/", 
	"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ":", ";", "<", "=", ">", "?", 
	"@", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", 
	"P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "[", "\\\\", "]", "^", "_", 
	"`", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", 
	"p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "{", "|", "}", "~", "○", 
	"█", "▒", "🐱", "⬇️", "░", "✽", "●", "♥", "☉", "웃", "⌂", "⬅️", "😐", "♪", "🅾️", "◆", 
	"…", "➡️", "★", "⧗", "⬆️", "ˇ", "∧", "❎", "▤", "▥", "あ", "い", "う", "え", "お", "か", 
	"き", "く", "け", "こ", "さ", "し", "す", "せ", "そ", "た", "ち", "つ", "て", "と", "な", "に", 
	"ぬ", "ね", "の", "は", "ひ", "ふ", "へ", "ほ", "ま", "み", "む", "め", "も", "や", "ゆ", "よ", 
	"ら", "り", "る", "れ", "ろ", "わ", "を", "ん", "っ", "ゃ", "ゅ", "ょ", "ア", "イ", "ウ", "エ", 
	"オ", "カ", "キ", "ク", "ケ", "コ", "サ", "シ", "ス", "セ", "ソ", "タ", "チ", "ツ", "テ", "ト", 
	"ナ", "ニ", "ヌ", "ネ", "ノ", "ハ", "ヒ", "フ", "ヘ", "ホ", "マ", "ミ", "ム", "メ", "モ", "ヤ", 
	"ユ", "ヨ", "ラ", "リ", "ル", "レ", "ロ", "ワ", "ヲ", "ン", "ッ", "ャ", "ュ", "ョ", "◜", "◝"
}

-- UTF8-Code to PicoChars
___.UTF8PICOCHARS = {}
do
	for nb,str in pairs(___.PICOCHARS) do
		___.UTF8PICOCHARS[utf8.codepoint(str)] = string.char(nb)
	end
	___.UTF8PICOCHARS[65039] = "" -- dummy character - added after arrow up/down/left/right
	for nb = 0, 255 do-- extended latin / Latin-1 Supplement
		if ___.UTF8PICOCHARS[nb] == nil then ___.UTF8PICOCHARS[nb] = string.char(nb) end
	end
end

-- convert a string from utf8 to p8scii
function Lib.StringUTF8toPico(pico, str)
	local ret = ""
	for p,code in utf8.codes(str) do
		ret ..= ___.UTF8PICOCHARS[code] or ""
	end
	return ret
end

-- convert a string from p8scii to utf8
function Lib.StringPicoToUTF8(pico, str)
	local ret = ""
	for p in str:gmatch(".") do
		ret ..= ___.PICOCHARS[p:byte()]
	end
	return ret
end


--==========================================================================================
---------------------------------------------------------------------------------Load / Save
--==========================================================================================

-- Convert Memory to hex string and write it to the file
function ___.FileWriteMemory(file,pico,adr,size,count)
	while size > 1 and not ___.MemoryIsEmpty(pico,adr,size) do 
		for i = 1,count do
			file:write(string.format("%02x",pico:Peek(adr)))
			adr += 1
			size -= 1
		end
		file:write("\n")
		
	end	
	return adr
end

-- Convert Memory to hex string (reversed order = sprite/label) and write it to the file	
function ___.FileWriteMemoryReversedOrder(file, pico, adr, size, count)
	while size > 1 and not ___.MemoryIsEmpty(pico,adr,size) do 
		for i = 1,count do
			file:write(string.reverse(string.format("%02x",pico:Peek(adr))))
			adr += 1
			size -= 1
		end
		file:write("\n")		
	end	
	return adr
end

-- load a rom-file
function Lib.LoadRom(pico,file)
	local fin, err = io.open(file,"rb")
	if fin == nil then
		return false, "can't open file: "..tostring(err)
	end
	
	if fin:seek("end") != 32768 then
		fin:close()
		return false, "wrong file size"
	end
	
	fin:seek("set")
	local str = fin:read("a")
	fin:close()
	
	-- set default values
	___.MemoryReset(pico)
					
	-- decompress lua
	local lua, err = ___.LuaDecompress(pico,str)	
	if lua == nil then
		return false, err
	end
	pico:LuaReplace(0, pico:LuaLen() + 1, lua)
	
	-- we copy the rom data
	for i=0x0000,0x42ff do
		pico:Poke(i, str:byte(i+1) or 0)
	end
			
	return true, "OK"
end

-- load a png-file
function Lib.LoadP8PNG(pico,file)
	local surface = SDL.Surface.Load(file,"PNG")
	if surface == nil then
		return false, SDL.Error.Get()
	end
	
	local data = surface:GetPixels()
	local pm = surface:GetPixelFormat()
	local w,h,pitch = surface:GetSize()
	
	if w != 160 or h != 205 then
		surface:Free()
		return false, "wrong png dimensions"
	end
	
	-- set default values
	___.MemoryReset(pico)
	
	-- read hidden data
	local str = ""
	for y = 0, h - 1 do
		for x = 0, w-1 do
			local r, g, b, a 	= pm:GetRGBA(data:getu32( pitch * y + x * 4) )
			str ..= string.char( (((a & 3) << (3 * 2)) | ((r & 3) << (2 * 2)) | ((g & 3) << (1 * 2)) | ((b & 3) << (0 * 2))) )
		end
	end
	
	-- label
	for y = 0, 127 do
		for x = 0, 127 do
			local r1, g1, b1, a1 = pm:GetRGBA(data:getu32( pitch * (y + 24) + (x + 15) * 4) )
			local r2, g2, b2, a2 = pm:GetRGBA(data:getu32( pitch * (y + 24) + (x + 16) * 4) )
			pico:Poke( Lib.LABEL + y * 64 + x \ 2, pico:ColorNearest( r1, g1, b1) | (pico:ColorNearest( r2, g2, b2 ) << 4))
		end
	end
	surface:Free()
		
	-- check sh1 checksum
	local cartSHA1 = ""		
	for i=0, 19 do
		cartSHA1 ..= string.format("%02x", str:byte(0x8007 + i) or 0)
	end
	if sha1.sha1(str:sub(1,0x8000)) != cartSHA1 and cartSHA1 != "0000000000000000000000000000000000000000" then -- old format doesn't have a checksum
		return false, "sha1 checksum error"
	end

				
	-- decompress lua
	local lua, err = ___.LuaDecompress(pico,str)
	if lua == nil then
		return false, err
	end
	pico:LuaReplace(0, pico:LuaLen() + 1, lua)
	
	-- we copy the rom data
	for i=0x0000,0x42ff do
		pico:Poke(i, str:byte(i+1) or 0)
	end
		
	return true, "OK"
end

-- load a p8-file
function Lib.LoadP8(pico,file)
	local fin, err = io.open(file,"r")
	local line

	if fin == nil then
		return false, "can't open file: "..tostring(err)
	end
	
	-- check header
	line = fin:read("l")
	if line != ___.PICO8HEADER then
		fin:close()
		return false,"not a pico8 p8 file"
	end
		
	line = fin:read("l")
	pico.version = tonumber(line:sub(9,-1))
	if line:sub(1,7)!="version" then 
		fin:close()
		return false,"missing pico version"
	end
	
	-- reset to default
	___.MemoryReset(pico)
		
	-- read full file
	local saveData = ""	
	local mode,i,adr = "void"
	local lua = ""
	for line in fin:lines("l") do
			
		if line:sub(1,2)=="__" and line:sub(-2,-1)=="__" then
			-- section selector
			mode = line:sub(3,-3)			
			
			if mode =="gfx" then
				adr=Lib.SPRITE
			elseif mode == "gff" then
				adr=Lib.SPRFLAG
			elseif mode == "map" then
				adr=0x2000
			elseif mode == "music" then
				adr=Lib.MUSIC
			elseif mode == "sfx" then
				adr=Lib.SFX
			elseif mode == "label" then
				adr=Lib.LABEL -- use the "screen" for the label
			elseif mode == ___.METARAMDATA then
				adr=0x0000
			elseif mode == ___.METASAVEDATA then
				adr=0x0000
			elseif mode == "lua" then
				lua = ""
				adr = 0
			else
				pico.raw[mode]=""
				adr=0
			end
			
		elseif mode == ___.METASAVEDATA then
			saveData ..= " "..line
		
		elseif mode == ___.METARAMDATA then
			line = line:trim()
			if line:sub(1,1) == "@" then
				adr = tonumber("0x" .. line:sub(2)) or 0
			elseif line != "" then
				for i=1,#line,2 do
					local hex = tonumber("0x".. line:sub(i,i+1))
					pico:Poke(adr,hex)
					adr+=1
				end
			end
					
		elseif mode =="gfx" or mode=="label" then
			line = line:trim()
			if line!="" then
				for i=1,#line,2 do
					local hex = tonumber("0x"..line:sub(i,i+1):reverse())
					pico:Poke(adr,hex)
					adr+=1
				end
			end
				
		elseif mode == "gff" or mode == "map" then
			line = line:trim()
			if line!="" then 
				for i=1,#line,2 do
					local hex = tonumber("0x"..line:sub(i,i+1))
					pico:Poke(adr,hex)
					adr+=1
				end
			end
		
		elseif mode == "music" then
			line = line:trim()
			if line!="" then 
				local high,p1,p2,p3,p4
				high = tonumber("0x".. line:sub(1,2))
				p1= tonumber("0x".. line:sub(4,5)) | (high&1!=0 and 0x80 or 0x00)
				p2= tonumber("0x".. line:sub(6,7)) | (high&2!=0 and 0x80 or 0x00)
				p3= tonumber("0x".. line:sub(8,9)) | (high&4!=0 and 0x80 or 0x00)
				p4= tonumber("0x".. line:sub(10,11)) | (high&8!=0 and 0x80 or 0x00)
				pico:Poke(adr,p1) adr+=1
				pico:Poke(adr,p2) adr+=1
				pico:Poke(adr,p3) adr+=1
				pico:Poke(adr,p4) adr+=1			
			end
			
		elseif mode == "sfx" then
			line = line:trim()
			if line!="" then 
				for i=1,32 do
					local hex = ___.SFXConvert20to16( tonumber("0x".. line:sub(i*5+4,i*5+4+4)) )
					pico:Poke2(adr,hex) adr+=2
				end
				
				for i=1,8,2 do
					local hex = tonumber("0x"..line:sub(i,i+1))
					pico:Poke(adr,hex) adr+=1
				end
			end
			
		elseif mode == "lua" then
			lua ..= pico:StringUTF8toPico(line) .. "\n"
			
		else
			-- save in raw-table 
			pico.raw[mode] ..= pico:StringUTF8toPico(line) .. "\n"
		end
		
		
	
	end
	
	pico:LuaReplace(0, pico:LuaLen()+1, lua)
		
	fin:close()

	if saveData != "" then
		pico:UndoSetCustom(
			"_savedatastr",
			function (x)
				-- 1 = pico, 2 = str
				local ret = {x[1], ___.TableToString(x[1].saveData)}
				x[1].saveData = ___.StringToTable(x[2])
				return ret
			end,
			{pico,___.TableToString(saveData)}
		)
		pico.saveData = ___.StringToTable(saveData)
	end
		
	return true, "OK"
end

-- save a p8-file
function Lib.Savep8(pico,file)
	local file, err = io.open(file,"w")
	local line

	if file == nil then
		return false, "can't create file: "..tostring(err)
	end
	
	-- header
	file:write(___.PICO8HEADER .."\n")	
	file:write("version ".. (pico.version > ___.PICO8VERSION and pico.version or ___.PICO8VERSION).."\n")
	
	-- write lua-code and all unknown "pages"
	for what,data in pairs(pico.raw) do
		file:write("__" .. what .. "__\n")
		file:write(pico:StringPicoToUTF8(data)) -- ends always with a \n
	end
	
	-- gfx
	if not ___.MemoryIsEmpty(pico, Lib.SPRITE, Lib.SPRITELEN) then
		file:write("__gfx__\n")
		___.FileWriteMemoryReversedOrder(file, pico, Lib.SPRITE, Lib.SPRITELEN, 64)
	end
	-- label
	if not ___.MemoryIsEmpty(pico, Lib.LABEL, Lib.LABELLEN) then
		file:write("__label__\n")
		___.FileWriteMemoryReversedOrder(file, pico, Lib.LABEL, Lib.LABELLEN, 64)
	end
	-- gff
	if not ___.MemoryIsEmpty(pico, Lib.SPRFLAG, Lib.SPRFLAGLEN) then
		file:write("__gff__\n")
		___.FileWriteMemory(file,pico, Lib.SPRFLAG, Lib.SPRFLAGLEN, 128)
	end
	-- map
	if not ___.MemoryIsEmpty(pico,0x2000,0x1000) then
		file:write("__map__\n")
		___.FileWriteMemory(file,pico, 0x2000,0x1000, 128)		
	end
	-- sfx
	if not ___.MemoryIsEmpty(pico,Lib.SFX, Lib.SFXLEN) then
		file:write("__sfx__\n")
		do
			local adr,size = Lib.SFX, Lib.SFXLEN
			for line=1,64 do
				local str = ""
				if ___.MemoryIsEmpty(pico,adr,size) then break end
			
				for i=1,32 do
					str = str .. string.format("%05x", ___.SFXConvert16to20( pico:Peek2(adr) ) ) 
					adr += 2 size -= 2
				end
				for i=1,4 do 
					file:write( string.format("%02x", pico:Peek(adr))) adr += 1 size -= 1
				end
				file:write(str.."\n")
			end
		end
	end
	-- music
	if not ___.MemoryIsEmpty(pico, Lib.MUSIC, Lib.MUSICLEN) then
		file:write("__music__\n")
		do 
			local adr = Lib.MUSIC
			for i=1,64 do
				local p1,p2,p3,p4 = pico:Peek(adr), pico:Peek(adr+1), pico:Peek(adr+2), pico:Peek(adr+3)
				adr +=4
				
				file:write( 
					string.format(
						"%02x %02x%02x%02x%02x\n",
						((p1>>7)) | ((p2>>7) <<1) | ((p3>>7) <<2) | ((p4>>7) <<3),
						p1 & 0x7f,
						p2 & 0x7f,
						p3 & 0x7f,
						p4 & 0x7f
					)
				)
				
			end
		end
	end	
	
	-- RAM - Data
	file:write("__"..___.METARAMDATA.."__\n")
	if pico:Peek(Lib.SPRITEPOS) != 0x00 then
		file:write( string.format("@%04x\n%02x\n", Lib.SPRITEPOS, pico:Peek(Lib.SPRITEPOS)) )
	end
	
	if pico:Peek(Lib.MAPPOS) != 0x20 then
		file:write( string.format("@%04x\n%02x\n", Lib.MAPPOS, pico:Peek(Lib.MAPPOS)) )
	end
	
	if pico:Peek(Lib.MAPWIDTH) != 0x80 then
	  file:write( string.format("@%04x\n%02x\n", Lib.MAPWIDTH, pico:Peek(Lib.MAPWIDTH)) )
	end	
	-- save palette
	if not pico:MemoryCompareHex( Lib.PAL, "000102030405060708090a0b0c0d0e0f") then
		file:write( string.format("@%04x\n", Lib.PAL) )
		___.FileWriteMemory(file, pico, Lib.PAL, Lib.PALLEN, 16)
	end
	
	-- free to use
	if not ___.MemoryIsEmpty(pico,Lib.FREEMEM, Lib.FREEMEMLEN) then
		file:write( string.format("@%04x\n",Lib.FREEMEM) )
		___.FileWriteMemory(file, pico, Lib.FREEMEM, Lib.FREEMEMLEN, 128)
	end
	
	-- Save charset only if changed from default
	if not pico:MemoryCompareHex( Lib.CHARSET, ___.DEFAULTCHARSET) then
		file:write( string.format("@%04x\n", Lib.CHARSET) )
		___.FileWriteMemory(file, pico, Lib.CHARSET, Lib.CHARSETLEN, 128)		
	end
	
	-- Save customPos
	if not pico:MemoryCompareHex( ___.CUSTOMPOS, ___.DEFAULTCUSTOMPOS) then
		file:write( string.format("@%04x\n", ___.CUSTOMPOS) )
		___.FileWriteMemory(file, pico, ___.CUSTOMPOS, ___.CUSTOMPOSLEN, 8)		
	end
	
	-- save high-memory
	if not ___.MemoryIsEmpty(pico, 0x8000,0x8000) then
		file:write( string.format("@%04x\n", 0x8000) )
		___.FileWriteMemory(file, pico, 0x8000,0x8000, 128)
	end
	
	-- Addition save data
	file:write("__"..___.METASAVEDATA.."__\n")
	file:write( ___.TableToString( pico.saveData ) .."\n")
	
	
	file:close()
	
	return true, "OK"
end


--==========================================================================================
-----------------------------------------------------------------------------------------MAP
--==========================================================================================

-- return the memory-adress of the position in the map
function Lib.MapAdr(pico,x,y)
	local size, width, height = pico:MapSize()
	local offset = x + y * width
	
	if offset >= size then
		return 0
	end

	local adr = (pico:Peek(pico.MAPPOS)<<8) + offset
	
	-- remap memory
	if adr >= 0x3000 and adr <= 0x3fff then
		adr -= 0x2000
	end
	
	return adr
end

-- return size, width and height of the map
function Lib.MapSize(pico)
	local adr,width,size = pico:Peek(Lib.MAPPOS) << 8, pico:Peek(Lib.MAPWIDTH)
	if width == 0 then width = 256 end
	if adr>=0x1000 and adr < 0x2000 then
		size = 0x3000 - adr
	elseif adr >= 0x2000 and adr < 0x3000 then
		size = 0x4000 - adr 
	elseif adr >= 0x8000 then
		size = 0x10000 - adr
	else
		return 0,0,0
	end
	return size, width, math.floor((size or 0)/width)
end

-- return sprite on map-position
function Lib.MapGet(pico,x,y)
	local adr = pico:MapAdr(x,y)
	return adr>0 and pico:Peek(adr) or 0	
end

-- set sprite on map-position
function Lib.MapSet(pico,x,y,value)
	local adr = pico:MapAdr(x,y)
	return adr>0 and pico:Poke(adr,value) or false	
end

-- count how often the char is in the map
function Lib.MapCount (pico, char)
	if pico.recountNeeded == true then
		pico.recountNeeded = false
		-- reset
		for i = 0,255 do
			pico.count[i] = 0
		end
		-- recount
		local s,w,h = pico:MapSize()
		for y = 0, h - 1 do 
			for x = 0, w - 1 do
				pico.count[ pico:MapGet(x,y) ] += 1
			end
		end		

	end
	return pico.count[char]
end


--==========================================================================================
--------------------------------------------------------------------------------------SPRITE
--==========================================================================================

-- Get Adress of the music
function Lib.SpriteFlagAdr(pico,nb)
		return (pico:Peek(Lib.SPRFLAGPOS)<<8) + math.clamp(0, 255, nb or 0)
end


-- get a sprite flag
function Lib.SpriteFlagGet(pico, char, flag)
	return ( pico:Peek(pico:SpriteFlagAdr(char & 0xff)) & (1 << (flag & 0xf))) > 0 --and true or false
end

-- set a sprite flag
function Lib.SpriteFlagSet(pico, char, flag, bool)
	local adr = pico:SpriteFlagAdr(char & 0xff)
	if bool then
		pico:Poke(adr, pico:Peek(adr) |   (1 << (flag & 0xf)) )
	else
		pico:Poke(adr, pico:Peek(adr) & ~ (1 << (flag & 0xf)) )	
	end
end

-- return adress of the sprite on position x,y or character x
function Lib.SpriteAdr(pico, x, y)
	if y == nil then
		return (x & 0xf) * 4 + (x>>4) * 8 * 64 + (pico:Peek(pico.SPRITEPOS)<<8)
	end
	return x \ 2 + y * 64	+ (pico:Peek(pico.SPRITEPOS)<<8)
end

-- Set Pixel in Spritesheet
function Lib.SpriteSetPixel(pico, x, y, col)
	if x < 0 or x > 127 or y < 0 or y > 127 then
		return false
	end
	local adr = pico:SpriteAdr(x,y) -- address of the sprite pixel
	if x & 1 == 0 then
		pico:Poke(adr, (pico:Peek(adr) & 0xf0) | (col & 0xf) )		-- even pixel
	else
		pico:Poke(adr, (pico:Peek(adr) & 0x0f) | ((col & 0xf)<<4) )	-- odd pixel
	end

	return true
end

-- Get Pixel in Spritesheet
function Lib.SpriteGetPixel(pico, x, y)
	if x < 0 or x > 127 or y < 0 or y > 127 then
		return 0
	end
	local adr = pico:SpriteAdr(x,y)	-- address of the sprite pixel
	if x & 1 == 0 then
		return pico:Peek(adr) & 0xf			-- even pixel
	else
		return (pico:Peek(adr) >> 4) & 0xf	-- odd pixel
	end
end

-- Render sprite to data-object
function Lib.SpriteRender(pico,data,pitch,dontRedrawFlag)
	return ___.Render(pico,"sprite",data,pitch,dontRedrawFlag)	
end

-- return if a poke has changed the sprite
function Lib.SpriteChanged(pico)
	return pico.spriteRedrawNeeded
end


--==========================================================================================
---------------------------------------------------------------------------------------Label
--==========================================================================================

-- Set Pixel in Label
function Lib.LabelSetPixel(pico, x, y, col)
	if x < 0 or x > 127 or y < 0 or y > 127 then
		return false
	end
	local adr = x \ 2 + y * 64 + Lib.LABEL	-- address of the sprite pixel
	if x & 1 == 0 then
		pico:Poke(adr, (pico:Peek(adr) & 0xf0) | (col & 0xf) )		-- even pixel
	else
		pico:Poke(adr, (pico:Peek(adr) & 0x0f) | ((col & 0xf)<<4) )	-- odd pixel
	end

	return true
end

-- Get Pixel in Label
function Lib.LabelGetPixel(pico, x, y)
	if x < 0 or x > 127 or y < 0 or y > 127 then
		return 0
	end
	local adr = x\2 + y*64 + Lib.LABEL	-- address of the sprite pixel
	if x & 1 == 0 then
		return pico:Peek(adr) & 0xf			-- even pixel
	else
		return (pico:Peek(adr) >> 4) & 0xf	-- odd pixel
	end
end

-- render label to data-object
function Lib.LabelRender(pico,data,pitch,dontRedrawFlag)
	return ___.Render(pico,"label",data,pitch,dontRedrawFlag)
end

-- label has changed 
function Lib.LabelChanged(pico)
	return pico.labelRedrawNeeded
end

--==========================================================================================
-------------------------------------------------------------------------------------Charset
--==========================================================================================

-- Name of the character
Lib.CHARNAME = { [0] = "stop printing", "Repeat next", "solid background", "Move horizontally", "Move vertically", "Move cursor", "Special command", "Audio command", "Backspace", "Tab", "Newline", "Decorate character", "foreground color", "Carriage return", "Costum font", "Default font", "Vertical rectangle", "Filled square", "Hollow square", "Five dot", "Four dot", "Pause", "Back", "Forward", "starting quote", "ending quote", "Yen sign", "Interpunct", "Japanese comma", "Japanese full stop", "dakuten", "handakuten", " ", "!", "\"", "#", "$", "%", "&", "'", "(", ")", "*", "+", ",", "-", ".", "/", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ":", ";", "<", "=", ">", "?", "@", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "[", "\\", "]", "^", "_", "`", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "{", "|", "}", "~", "Hollow circle", "Rectangle", "Checkerboard", "Jelpi", "MouseDown key", "Dot pattern", "Throwing star", "Ball", "Heart", "Eye", "Man", "House", "Left key", "Face", "Musical note", "O key", "Diamond", "Ellipsis", "Right key", "Five-pointed star", "Hourglass", "Up key", "Birds", "Sawtooth", "X key", "Horiz lines", "Vert lines", "a", "i", "u", "e", "o", "ka", "ki", "ku", "ke", "ko", "sa", "shi", "su", "se", "so", "ta", "chi", "tsu", "te", "to", "na", "ni", "nu", "ne", "no", "ha", "hi", "fu", "he", "ho", "ma", "mi", "mu", "me", "mo", "ya", "yu", "yo", "ra", "ri", "ru", "re", "ro", "wa", "wo", "n", "Sokuon", "Digraph: ya", "Digraph: yu", "Digraph: yo", "a", "i", "u", "e", "o", "ka", "ki", "ku", "ke", "ko", "sa", "shi", "su", "se", "so", "ta", "chi", "tsu", "te", "to", "na", "ni", "nu", "ne", "no", "ha", "hi", "fu", "he", "ho", "ma", "mi", "mu", "me", "mo", "ya", "yu", "yo", "ra", "ri", "ru", "re", "ro", "wa", "wo", "n", "Sokuon", "Digraph: ya", "Digraph: yu", "Digraph: yo", "Left arc", "Right arc"}

-- pico8 charset as custom font
___.DEFAULTCHARSET ="040806000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007070707070000000007070700000000000705070000000000050205000000000005000500000000000505050000000004060706040000000103070301000000070101010000000000040404070000000507020702000000000002000000000000000001020000000000000303000000050500000000000002050200000000000000000000000000020202000200000005050000000000000507050705000000070306070200000005040201050000000303060507000000020100000000000002010101020000000204040402000000050207020500000000020702000000000000000201000000000007000000000000000000020000000402020201000000070505050700000003020202070000000704070107000000070406040700000005050704040000000701070407000000010107050700000007040404040000000705070507000000070507040400000000020002000000000002000201000000040201020400000000070007000000000102040201000000070406000200000002050501060000000006050705000000000303050700000000060101060000000003050503000000000703010600000000070301010000000006010507000000000505070500000000070202070000000007020203000000000503050500000000010101060000000007070505000000000305050500000000060505030000000006050701000000000205030600000000030503050000000006010403000000000702020200000000050505060000000005050702000000000505070700000000050202050000000005070403000000000704010700000003010101030000000102020204000000060404040600000002050000000000000000000007000000020400000000000007050705050000000705030507000000060101010600000003050505070000000701030107000000070103010100000006010105070000000505070505000000070202020700000007020202030000000505030505000000010101010700000007070505050000000305050505000000060505050300000007050701010000000205050306000000070503050500000006010704030000000702020202000000050505050600000005050507020000000505050707000000050502050500000005050704070000000704020107000000060203020600000002020202020000000302060203000000000407010000000000020502000000007F7F7F7F7F000000552A552A55000000417F5D5D3E0000003E6363773E0000001144114411000000043C1C1E100000001C2E3E3E1C000000363E3E1C080000001C3677361C0000001C1C3E1C140000001C3E7F2A3A0000003E6763673E0000007F5D7F417F0000003808080E0E0000003E636B633E000000081C3E1C0800000000005500000000003E7363733E000000081C7F3E220000003E1C081C3E0000003E7763633E000000000552200000000000112A44000000003E6B776B3E0000007F007F007F00000055555555550000000E041E2D2600000011212125020000000C1E20201C000000081E08241A0000004E043E4526000000225F12120A0000001E083C1106000000100C020C10000000227A2222120000001E2000023C000000083C10020C000000020202221C000000083E080C08000000123F12021C0000003C107E043800000002073202320000000F020E101C0000003E404020180000003E10080810000000083804023C00000032071278180000007A42020A72000000093E4B6D660000001A272273320000003C4A494946000000123A123A1A000000236222221C0000000C00082A4D000000000C1221400000007D79113D5D0000003E3C081E2E00000006247E2610000000244E04463C0000000A3C5A46300000001E041E4438000000143E2408080000003A56523008000000041C041E0600000008023E201C00000022222620180000003E1824723000000004362C26640000003E182442300000001A272223120000000E641C28780000000402062B1900000000000E1008000000000A1F120400000000040F150D00000000040C060E0000003E2014040200000030080E0808000000083E2220180000003E0808083E000000107E181412000000043E242232000000083E083E080000003C24221008000000047C1210080000003E2020203E000000247E242010000000062026100C0000003E20101826000000043E240438000000222420100C0000003E222D300C0000001C083E08040000002A2A20100C0000001C003E080400000004041C2404000000083E080804000000001C00003E0000003E2028102C000000083E305E08000000202020100E0000001024244442000000021E02021C0000003E2020100C0000000C12214000000000083E082A2A0000003E201408100000003C003E001E000000080424427E00000040281068060000001E041E043C000000043E2404040000001C1010103E0000001E101E101E0000003E003E201800000024242420100000001414145432000000020222120E0000003E2222223E0000003E2220100C0000003E203C2018000000062020100E000000001510080600000000041E140400000000000C081E000000001C18101C00000008046310080000000810630408000000"

-- Set current Charset
function Lib.CharsetSetDefault (pico)
	pico:PokeHex(Lib.CHARSET, ___.DEFAULTCHARSET)
end

-- get a pixel in charset
function Lib.CharsetGetPixel(pico,x,y)
	if x < 0 or x > 127 or y < 8 or y > 127 then -- first line is always blank!
		return 0
	end
	local c =  ((y \ 8) << 4) + (x \ 8)
	return pico:Peek(Lib.CHARSET + c * 8 + (y % 8)  ) >> (x % 8) & 1 
end

-- set a pixel in charset
function Lib.CharsetSetPixel(pico,x,y,v)
	if  x < 0 or x > 127 or y < 8 or y > 127 then -- first line is always blank!
		return false
	end
	local c =  ((y \ 8) << 4) + (x \ 8)
	local adr = Lib.CHARSET + c * 8 + (y % 8)
	if v != 0 then 		
		pico:Poke(adr, pico:Peek(adr) |  (1 << (x % 8) ) )
	else
		pico:Poke(adr, pico:Peek(adr) &  ~(1 << (x % 8) ) )
	end
end

-- render Charset to data object
function Lib.CharsetRender(pico,data,pitch)
	pico.charsetRedrawNeeded = false
	
	local adr
	for y=0,127 do
		adr = pitch*y
		for x=0,127 do 
			local col = pico:CharsetGetPixel(x,y)
			if col != 0 then col = 7 end
					
			data:setu32(adr, ___.RGBHEX[col] & ( col==0 and 0x00ffffff or 0xffffffff) )
			adr+=4
		end
	end

end

-- charset changed  
function Lib.CharsetChanged(pico)
	return pico.charsetRedrawNeeded
end

-- Set Variable width
function Lib.CharsetSetVariable(pico, char, adjust, oneup)
	if char < 16 then return end
	local adr = Lib.CHARSET + char \ 2
	local shift = (char & 1) * 4
	local mask = 0xf << shift
	adjust = math.clamp(-4,3, adjust\1)
	local value = (Lib.FontAdjustRev[adjust] | ( oneup and 8 or 0)	) << shift
	pico:Poke(adr, (pico:Peek(adr) & ~ mask) | ( value & mask) )
end

-- Get Variable width
function Lib.CharsetGetVariable(pico, char)
	if char < 16 then return 0,false end
	local adr = Lib.CHARSET + char \ 2
	local shift = (char & 1) * 4
	local value = (pico:Peek(adr) >> shift) & 0xf
	return Lib.FontAdjust[value & 7], (value & 8) == 8
end

--==========================================================================================
-----------------------------------------------------------------------------------------SFX
--==========================================================================================

-- names of notes
Lib.NOTENAME = {"C ","C#","D ","D#","E ","F ","F#","G ","G#","A ","A#","B "}

-- convert sfx-data in p8-file-format (20bit) to p8-memory-format (16bit)
___.SFX16BIT={ 0x0001,  0x0002,  0x0004,  0x0008,  0x0010,  0x0020,  0x0040,  0x0080,  0x0100,  0x0200,  0x0400,  0x0800,  0x1000,  0x2000,  0x4000,  0x8000}
___.SFX20BIT={0x01000, 0x02000, 0x04000, 0x08000, 0x10000, 0x20000, 0x00100, 0x00200, 0x00400, 0x00010, 0x00020, 0x00040, 0x00001, 0x00002, 0x00004, 0x00800}

-- file to memory format
function ___.SFXConvert20to16(hex)
	local value,i = 0
	for i=1, #___.SFX20BIT do
		if (hex & ___.SFX20BIT[i]) != 0 then
			value |= ___.SFX16BIT[i]
		end
	end
	return value
end

-- memory to file format
function ___.SFXConvert16to20(bin)
	local value,i = 0
	for i=1, #___.SFX16BIT do
		if bin & ___.SFX16BIT[i] != 0 then
			value |= ___.SFX20BIT[i]
		end
	end
	return value
end

-- get SFX-Adress
function Lib.SFXAdr(pico, nb)
	return (pico:Peek(Lib.SFXPOS)<<8) + math.clamp(0,63, nb or 0) * 68
end

-- get table with the sfx-data
function Lib.SFXGet(pico, nb)
	nb = math.clamp(0,63, nb or 0)
	
	local sfxadr = pico:SFXAdr(nb)
	local byte = pico:Peek(sfxadr+64)
	
	-- convert settings
	local sfx = {
		nb = nb,
		editormode = byte & 1,
		noiz = (byte >> 1) & 1,
		buzz = (byte >> 2) & 1,
		detune = byte \ 8 % 3,
		reverb = byte \ 24 % 3,
		dampen = byte \ 72 % 3,
		unused = byte \ 216,
		
		speed = pico:Peek(sfxadr + 65),
		loopStart = pico:Peek(sfxadr + 66),
		loopEnd = pico:Peek(sfxadr + 67),
		notes = {}
	}
	-- convert notes
	for i = 0, 31 do
		local word = pico:Peek2(sfxadr + i * 2)
		local eff = (word >> 12) & 0x7
		table.insert(
			sfx.notes, 
			{
				pitch = word & 0x3f,
				wave = ((word >> 6) & 0x7) | ((word>>15) <<3),
				volume = (word >> 9) & 0x7,
				effect = eff,
			}
		)
	end
	-- Additional visibile information - because of effect 1, 6, 7
	for i = 0, 31 do	
		local eff,vol = sfx.notes[i + 1].effect, sfx.notes[i + 1].volume
		if eff == 1 and i > 0 and vol > 0 then			
			sfx.notes[i].alwaysVisible = true
			
		elseif not sfx.notes[i + 1].alwaysVisible and (eff == 6 or eff == 7) then
			for a = (i \ 4)*4 + 1, (i \ 4)*4 + 4 do
				sfx.notes[a].alwaysVisible = true
			end
		
		end		
	end
	return sfx
end

-- set table with sfx-data
function Lib.SFXSet(pico, nb, sfx)
	local byte = sfx.editormode & 1
	local sfxadr = pico:SFXAdr(nb)
	byte |= (sfx.noiz & 1) << 1
	byte |= (sfx.buzz & 1) << 2
	byte += math.clamp(0, 2, sfx.detune) * 8
	byte += math.clamp(0, 2, sfx.reverb) * 24
	byte += math.clamp(0, 2, sfx.dampen) * 72
	byte += sfx.unused * 216
	for i = 0, 31 do
		local note = sfx.notes[i+1]
		local word
		word = (note.pitch & 0x3f) | ((note.wave & 0x7) << 6) | ((note.volume & 0x7) << 9 ) | ((note.effect & 0x7) << 12) | (((note.wave >> 3) &1) << 15)
		pico:Poke2(sfxadr + i * 2, word)
	end
	pico:Poke(sfxadr + 64, byte)
	pico:Poke(sfxadr + 65, sfx.speed)
	pico:Poke(sfxadr + 66, sfx.loopStart)
	pico:Poke(sfxadr + 67, sfx.loopEnd)		
end

-- render sfx to data object and calculate empty, dominate
function Lib.SFXRender(pico,nb,data,pitch)
	nb = math.clamp(0,63,nb or 0)
		
	--clear
	local adr,col
	for y = 0, 63 do
		adr = pitch*y
		for x = 0, 32 do 
			data:setu32(adr,0)
			adr += 4
		end
	end

	--setgrah
	local sfxadr = pico:SFXAdr(nb)
	pico.emptySFX[nb] = true
	
	local maxWave,maxCount,maxList=0,0,{}
	
	for i = 0, 31 do
		local word = pico:Peek2(sfxadr + i * 2)
		local npitch = word & 0x3f
		local wave = ((word >> 6) & 0x7) | ((word>>15) <<3)
		local volume = (word >> 9) & 0x7
		if volume > 0 then
			data:setu32(pitch * (63 - npitch) + i * 4, ___.RGBHEX[ (wave < 8) and (wave + 8) or 3 ] )
			maxList[wave] = (maxList[wave] or 0) + 1
			if maxList[wave] > maxCount then
				maxWave = wave
				maxCount = maxList[wave]
			end
			
			pico.emptySFX[nb] = false
		end
		
	end
	
	pico.dominateSFX[nb] = maxWave

	pico.validSFX[nb]=true

end

-- sfx was changed
function Lib.SFXChanged(pico,nb)
	return not pico.validSFX[nb]
end

-- sfx is empty
function Lib.SFXEmpty(pico,nb)
	return pico.emptySFX[nb]
end

-- return the most used wave form
function Lib.SFXDominate(pico,nb)
	return pico.dominateSFX[nb] or 0
end

--==========================================================================================
---------------------------------------------------------------------------------------Music
--==========================================================================================

-- Get Adress of the music
function Lib.MusicAdr(pico,nb)
	return (pico:Peek(Lib.MUSICPOS)<<8) + math.clamp(0, 63, nb or 0) * 4
end

-- Get Music data in a table
function Lib.MusicGet(pico, nb)
	local adr = pico:MusicAdr(nb)
	local b1,b2,b3,b4 = pico:Peek(adr), pico:Peek(adr + 1), pico:Peek(adr + 2), pico:Peek(adr + 3)
	return {
		nb = nb,
		sfx = {b1 & 63, b2 & 63, b3 & 63, b4 & 63},
		disabled = {b1 & 64 != 0, b2 & 64 != 0, b3 & 64 != 0, b4 & 64 != 0},
		beginLoop = b1 & 128 != 0,
		endLoop = b2 & 128 != 0,
		stop = b3 & 128 != 0,
		unused = b4 & 128 != 0,
	}
end

-- Set Music data from table
function Lib.MusicSet(pico, nb, t)
	local adr = pico:MusicAdr(nb)
	pico:Poke(adr  , (t.sfx[1] & 63) | (t.disabled[1] and 64 or 0) | (t.beginLoop and 128 or 0) )
	pico:Poke(adr+1, (t.sfx[2] & 63) | (t.disabled[2] and 64 or 0) | (t.endLoop and 128 or 0) )
	pico:Poke(adr+2, (t.sfx[3] & 63) | (t.disabled[3] and 64 or 0) | (t.stop and 128 or 0) )
	pico:Poke(adr+3, (t.sfx[4] & 63) | (t.disabled[4] and 64 or 0) | (t.unused and 128 or 0) )
end


--==========================================================================================
-----------------------------------------------------------------------------------------LUA
--==========================================================================================

-- string.byte on lua-code
function Lib.LuaCodes(pico, s, e)
	return pico.raw.lua:codes(s,e)
end

-- string.sub on lua-code
function Lib.LuaSub(pico, s, e)
	return pico.raw.lua:sub(s,e)
end

-- string.byte on lua-code
function Lib.LuaByte(pico, s, e)
	return pico.raw.lua:byte(s,e)
end

-- replace a string in lua-code - used for insert and delete characters in lua-code
function Lib.LuaReplace(pico, p, pend, str)
	if pico.writeProtected then return false end
	table.insert(pico.undoValues._lua, 1, {p , pico.raw.lua:sub(p+1,pend) , p + #str })		
	pico.raw.lua = pico.raw.lua:sub(1, p) .. str .. pico.raw.lua:sub(pend + 1,-1)	
	pico.undoValid = true
	pico:SetSaved(false)
	return p + #str	
end

-- return length in lua-code
function Lib.LuaLen(pico)
	return #pico.raw.lua
end

-- save cursor position for lua-code / undo
function Lib.LuaSetUndoCursor(pico, c, cEnd)
	pico.undoValues._luaCursor = c
	pico.undoValues._luaCursorEnd = cEnd
end

-- get the position of the last undo/redo
function Lib.LuaGetUndoCursor(pico)
	return pico._undoCursorPos, pico._undoCursorPosEnd
end

-- string.find on lua-code
function Lib.LuaFind(pico, a,b,c,d)
	return pico.raw.lua:find(a,b,c,d)
end

--==========================================================================================
----------------------------------------------------------------------------------Decompress
--==========================================================================================

local src_buf = {}
local bit = 1
local src_pos = {}

local PXA_MIN_BLOCK_LEN = 3
local BLOCK_LEN_CHAIN_BITS = 3
local BLOCK_DIST_BITS = 5
local TINY_LITERAL_BITS = 4

local LITERALS = 60

local literal = "^\n 0123456789abcdefghijklmnopqrstuvwxyz!#%(){}[]<>+=/*:;.,~_"

local function getbit()
	local ret = (src_buf[src_pos] & bit != 0) and 1 or 0
	bit <<= 1
	if bit == 256 then
		bit = 1
		src_pos += 1
	end	
	return ret
end

local function getval(bits)
	local val = 0
	if bits == 0 then return 0 end

	for i = 0, bits-1 do
		val |= getbit() << i
	end

	return val
end

local function getchain(link_bits, max_bits)
	local i
	local max_link_val = (1 << link_bits) - 1
	local val = 0
	local vv = max_link_val
	local bits_read = 0

	while vv == max_link_val do
		vv = getval(link_bits)
		bits_read += link_bits
		val += vv
		if bits_read >= max_bits then 
			return val
		end
	end
	
	return val
end

local function getnum()
	local bits = (3 - getchain(1, 2)) * BLOCK_DIST_BITS
	return getval(bits),bits
end

local function READ_VAL()
	local ret =  src_buf[src_pos]
	src_pos += 1
	return ret
end

-- PXA_READ_VAL(x)  getval(8)

function ___.LuaDecompress(pico, str)
	-- https://github.com/dansanderson/lexaloffle/blob/main/pxa_compress_snippets.c
	src_buf = {}
	src_pos = 0
	
	local out_p = {}
	local dest_pos = 0
	
	for i=0x4300,0x7fff do
		src_buf[i-0x4300] = str:byte(i+1)
	end
	
	if src_buf[0] == 58 and src_buf[1] == 99 and src_buf[2] == 58 and src_buf[3] == 00 then
		-- :c:
		local block_offset
		local block_length
		local val
		local len,len2

		READ_VAL()
		READ_VAL()
		READ_VAL()
		READ_VAL()


		len = READ_VAL() * 256		
		len += READ_VAL()
		
		
		len2 = READ_VAL() * 256		
		len2 += READ_VAL()
		
		while dest_pos < len do
			val = READ_VAL()
		
			if val < LITERALS then
				if val == 0 then 
					out_p [dest_pos] = READ_VAL()
				else
					out_p [dest_pos] = literal:byte(val+1);
				end
				dest_pos += 1			
			else
				block_offset = val - LITERALS
				block_offset *= 16
				val = READ_VAL()
				block_offset += val % 16
				block_length = (val \ 16) + 2
				
				for i=0, block_length-1 do
					out_p[dest_pos + i] = out_p[dest_pos + i - block_offset]
				end
				
				dest_pos += block_length
			end
		end
		
	elseif src_buf[0] == 0x00 or src_buf[1] == 0x70 or src_buf[2] == 0x78 or src_buf[3] == 0x61 then
		-- pxa compression
		
		local i
		local literal={} 	-- int 256
		local literal_pos={} -- int [256];


		bit = 1
		byte = 0

		for i=0,255 do
			literal[i] = i
			literal_pos[i] = i
		end
		
		local header = {} --[8];
		
		for i=0,7 do
			header[i] = getval(8)
		end

		local raw_len  = header[4] * 256 + header[5]
		local comp_len = header[6] * 256 + header[7]
		
		local first = true

		while src_pos < comp_len and dest_pos < raw_len do 

			local block_type = getbit()
			
			
			if block_type == 0 then

				local block_offset,bits_len = getnum()
				block_offset += 1
				if bits_len == 10 and block_offset == 1  then
					-- special case - uncompressed memory
					while true do
						local c = getval(8)
						if c == 0 then break end
						out_p[dest_pos] = c
						dest_pos += 1
					end
						
				else
					local block_len = getchain(BLOCK_LEN_CHAIN_BITS, 100000) + PXA_MIN_BLOCK_LEN

					while block_len > 0 do 
						out_p[dest_pos] = out_p[dest_pos - block_offset] or 0
						dest_pos += 1
						block_len -= 1
					end
				end

				out_p[dest_pos] = 0			

			else
			
				local lpos = 0
				local bits = 0

				local safety = 0
				while getbit() == 1 and safety < 16 do 
					safety += 1
					
					lpos += (1 << (TINY_LITERAL_BITS + bits))
					bits += 1
				end

				bits += TINY_LITERAL_BITS
				lpos += getval(bits)

				if lpos > 255 then 
					return nil, "decompression error"
				end

				local c = literal[lpos]

				out_p[dest_pos] = c
				dest_pos += 1
				out_p[dest_pos] = 0
				
				for i = lpos,1,-1 do
					literal[i] = literal[i-1]
					literal_pos[ literal[i] ] += 1
				end
				
				literal[0] = c
				literal_pos[c] = 0
			end
		end
		
	else		
		-- no compression
		
		out_p = src_buf
		dest_pos = #src_buf
		
	end
	

	local ret = ""
	str = ""
	for i=0, dest_pos+1 do
		if out_p[i] == 13 or out_p[i] == 10 or out_p[i] == 0 or out_p[i] == nil then
			ret..= str .."\n"
			str = ""
			if out_p[i] == 0 or out_p[i] == nil then
				break
			end
		else 
			str ..= string.char(out_p[i])
		end		
	end
	
	return ret, "OK"
end



return Lib

