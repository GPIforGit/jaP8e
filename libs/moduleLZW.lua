

modules = modules or {}
local m = {
	name = "LZW", 
	sort = 90, 
}
table.insert(modules, m)


local _writeAdr = 0x8000 -- where to place the packed data
local _LZWList -- list with all lzw-packed data
local _LZWSelect -- selected item
local _ppLZWname -- dialog for enter a name
local _ppLZWdest -- dialog for enter a destination adress

local _progressBarPercent -- drawing a progressbar

local _rectBack	-- some rects
local _rectTitle
local _rectList
local _rectFillBar,_rectFillBarUsed

local _FORMATSTRINGHEX = "%2i   %-8s   %1s%04x, %4x   %04x, %4x   %1s%04x, %4x   %6.2f"
local _FORMATSTRING = "%2i   %-8s   %1s%04x,%5i   %04x,%5i   %1s%04x,%5i   %6.2f"
local _COLUMNSTRING = "00   nnnnnnnn   sssssssssss   pppppppppp   ddddddddddd   rrrrrr" -- used to find out, where the user has clicked
local _TITLESTRING  = "Nb     Name        Source       Packed     Destination   Ratio"

-- code for decompression
local _luaCode = [[
function lzw_decompress(nb)
 local ba,bb,di,bs,da,w,e = 0x6003,1,{},9,_lzwdata[nb*2] reload(0x6000,_lzwdata[nb*2-1],0x2000)for i=0,255 do di[i]=chr(i)end w=di[@0x6002] poke(da,ord(w)) da+=1 for i=2,%0x6000 do e=0 for bit=0,bs-1 do e|=peek(ba)&bb!=0 and 1<<bit or 0 ba+=bb\128 bb=(bb<<1)%255 end e=di[e]or w..sub(w,1,1)poke(da,ord(e,1,#e))da+=#e add(di,w..sub(e,1,1))
 if (1<<bs<=#di+1) bs+=1
 w=e end
end
]]
--[[ --better readable version
function lzw_decompress(nb)
 local _bitsadr,_bitsbit,dictionary,bitsize,destadr,w,entry = 0x6003,1,{},9,_lzwdata[nb*2]
 reload(0x6000,_lzwdata[nb*2-1],0x2000)
 for i = 0, 255 do dictionary[i] = chr(i) end
 w=dictionary[@0x6002]
 poke(destadr,ord(w)) destadr+=1
 for i = 2, %0x6000 do
  entry = 0  
  for bit = 0, bitsize - 1 do
   entry |= peek(_bitsadr) & _bitsbit != 0 and 1<<bit or 0
   _bitsadr += _bitsbit\128
   _bitsbit = (_bitsbit<<1)%255
  end  
  entry = dictionary[entry] or w .. sub(w,1, 1)
  poke(destadr,ord(entry,1,#entry))
  destadr += #entry
  add(dictionary, w .. sub(entry,1, 1))
  if (1<<bitsize<=#dictionary+1) bitsize+=1
  w = entry
 end
end
]]


--===================================================================
---------------------------------------------------------------unused
--===================================================================

-- compress and decompress - direct memory version
--[[
local _bitsAdr
local _bitsBit
local _bitsStart

function BitsPosition(adr)
	_bitsAdr = adr
	_bitsStart = adr
	_bitsBit = 1	
end

function BitsLen(adr)
	return _bitsAdr - _bitsStart + 1 - (_bitsBit == 1 and 1 or 0)
end

function Bits(srcSize,b)
	local ret=0
	for i = 0, srcSize - 1 do
		if b then
			activePico:Poke(_bitsAdr, activePico:Peek(_bitsAdr) & ~(_bitsBit * (~b&1)) | (b&1) *_bitsBit )
			b>>=1
		else
			ret |= activePico:Peek(_bitsAdr) & _bitsBit != 0 and 1<<i or 0
		end
		_bitsAdr += _bitsBit\128 -- when bits was on 128, next would be 256 -> next byte
		_bitsBit = (_bitsBit<<1)%255 -- overflow 256 to 1
	end
	return ret
end

function LZWCompress(destAdr,srcAdr,srclen)
	local dictionary, dict_size, w,bitsize, c = {}, 255, "",8
	
	BitsPosition(destAdr+2) -- 2 bytes for token count  

	for i = 0, 255 do dictionary[string.char(i)] = i end
	
	for i = 1, srclen do
		c = string.char(activePico:Peek(srcAdr))     
		srcAdr+=1

		if dictionary[w .. c] then
			w ..= c
		else
			Bits(bitsize, dictionary[w])
			dict_size += 1			
			if 1<<bitsize<=dict_size then bitsize+=1 end
			dictionary[w .. c] = dict_size
			w = c
		end
	end
	Bits(bitsize,dictionary[w])
	
	activePico:Poke2(destAdr,dict_size-254) -- store token-count 
	return BitsLen() + 2 -- token-count!
end

function LZWDecompress(destAdr,srcAdr)
	local dictionary, bitsize,odest,w,entry = {}, 9,destAdr
	for i = 0, 255 do dictionary[i] = string.char(i) end

	BitsPosition(srcAdr+2)
	w=dictionary[Bits(8)]
	activePico:PokeString(destAdr,w) destAdr+=1
	for i = 2, activePico:Peek2(srcAdr) do
		entry = dictionary[ Bits(bitsize)] or w .. w:sub(1, 1)

		activePico:PokeString(destAdr,entry)
		destAdr += #entry

		table.insert(dictionary, w .. entry:sub(1, 1))
		if 1<<bitsize<=#dictionary+1 then bitsize+=1 end

		w = entry
	end
	return destAdr-odest
end

--]]

--===================================================================
-----------------------------------------------------------------misc
--===================================================================

-- calcualte the value of the string, return false/true,v1,v2
local function _Calc(str)
	local myenv = {}

	local f,err = load("return " .. tostring(str),"userinput","t",myenv)

	if not f then
		SDL.Request.Message(window, TITLE, tostring(err) ,"OK STOP")
		return false
	end
	
	local ok,a,b = pcall(f)

	if not ok then
		SDL.Request.Message(window, TITLE, tostring(a) ,"OK STOP")
		return false
	end

	return true, a, b
end

-- copy decompress code to clipboard
local function _CopyUncompressCode()
	SDL.Clipboard.SetText(_luaCode)
	InfoBoxSet("Copied decompress code to clipboard.")
end


--===================================================================
-----------------------------------------------------------------BITS
--===================================================================

local _stringBits
local _stringByte

-- set a string as cache for _StringBits
local function _StringBitsSet(str)
	_sBits = 1	
	_sStr = str or ""
	_sPos = 1
	_sByte = _sStr:byte(_sPos) or 0
end

-- read or write bits in bits-string-cache - if bits is nil, the function read, otherwise write
local function _StringBits(bitSize,bits)
	local ret = 0
	for i = 0, bitSize - 1 do
		if bits then
			-- write data
			_sByte = _sByte & ~(_sBits * (~bits&1)) | (bits&1) *_sBits 
			bits>>=1
		else
			-- read data
			ret |= _sByte & _sBits != 0 and 1<<i or 0		
		end
		if _sBits == 128 then
			-- next byte
			if _sStr:byte(_sPos) != _sByte then
				-- store changed byte
				_sStr = _sStr:sub(1, _sPos -1) .. string.char(_sByte) .. _sStr:sub(_sPos + 1)
			end
			-- next read byte position
			_sPos += 1
			_sByte = _sStr:byte(_sPos) or 0
			_sBits = 1
		else
			-- next read bit position
			_sBits <<= 1
		end		
	end
	
	-- store changed byte
	if _sStr:byte(_sPos) != _sByte and _sBits != 1 then
		_sStr = _sStr:sub(1, _sPos -1) .. string.char(_sByte) .. _sStr:sub(_sPos + 1)
	end
	
	return ret
end

-- return cached bits-string-cache
local function stringBitsGet()
	return _sStr
end

--===================================================================
------------------------------------------------------------------LZW
--===================================================================

-- compress the string in lzw-format and return a compressed string
local function _LZWStringCompress(str)
	local dictionary, dict_size, w,bitsize, c = {}, 255, "",8
	
	_StringBitsSet()
	
	for i = 0, 255 do dictionary[string.char(i)] = i end
	
	for i = 1,#str do
		c = str:sub(i,i)

		if dictionary[w .. c] then
			w ..= c
		else
			_StringBits(bitsize, dictionary[w])
			dict_size += 1			
			if 1<<bitsize<=dict_size then bitsize+=1 end
			dictionary[w .. c] = dict_size
			w = c
		end
	end
	_StringBits(bitsize,dictionary[w])
	
	local token = dict_size-254
	--activePico:Poke2(destAdr,dict_size-254) -- store token-count 
	--PrintDebug(token, token & 0xff, token>>8)
	return string.char(token & 0xff, token>>8) .. stringBitsGet()
end

-- decompress the lzw string and return the original string
local function _LZWStringDecompress(str)
	_StringBitsSet(str)
	local tokens = _StringBits(8) + (_StringBits(8)<<8)
	local ret

	local dictionary, bitsize,w,entry = {}, 9
	for i = 0, 255 do dictionary[i] = string.char(i) end
	
	w=dictionary[_StringBits(8)]
	ret = w
	
	for i = 2, tokens do
		entry = dictionary[ _StringBits(bitsize)] or w .. w:sub(1, 1)

		ret..= entry

		table.insert(dictionary, w .. entry:sub(1, 1))
		if 1<<bitsize<=#dictionary+1 then bitsize+=1 end

		w = entry
	end
	return ret
end

--===================================================================
-----------------------------------------------------------------LIST
--===================================================================

-- read in _LZWLIST all pack in a string and store it in .pack
local function _ListInsertPack()
	for nb,d in pairs(_LZWList) do
		d.pack = activePico:PeekString(d.packAdr, d.packSize)		
	end
end

-- erase pack-memory-area and restore the data from _ListInsertPack
local function _ListRemovePack()
	activePico:MemorySet(_baseAdr, 0, _limitSize)
	_writeAdr = _baseAdr
	for nb,d in pairs(_LZWList) do
		activePico:PokeString(_writeAdr, d.pack)
		d.packAdr = _writeAdr
		d.packSize = #d.pack
		d.pack = nil
		_writeAdr += d.packSize		
	end
end

-- initalize list
local function _ListInitalize()
	_LZWList = activePico:SaveDataGet("LZW","list") or {}
	_baseAdr = activePico:SaveDataGet("LZW","baseAdr") or 0x8000
	_limitSize = activePico:SaveDataGet("LZW","limitSize") or 0x4300 -- ROM Size
	_writeAdr = _baseAdr
	for nb,d in pairs(_LZWList) do
		if d.name == nil then d.name="" end
		if d.packAdr >= _baseAdr then
			-- find new write-position
			local adr = d.packAdr + d.packSize
			if adr > _writeAdr then
				_writeAdr = adr
			end
		end
		-- check if the unpacked data is identical to source or dest
		local unpack = _LZWStringDecompress( activePico:PeekString(d.packAdr, d.packSize) )
		d.equalSrc =  unpack == activePico:PeekString(d.srcAdr, d.srcSize) 		
		d.equalDest =  unpack == activePico:PeekString(d.destAdr, d.srcSize) 		
	end
	
	--[[ debugcode!
	if _LZWList[1] then
		str = _LZWStringCompress(activePico:PeekString(_LZWList[1].srcAdr,_LZWList[1].srcSize))
		PrintDebug("compress",#str, _LZWList[1].packSize)
		for nb,code in str:codes() do
			if activePico:Peek(_LZWList[1].packAdr + nb - 1) != code then
				PrintDebug("mist",nb, activePico:Peek(_LZWList[1].packAdr + nb - 1) , code)
				break
			end
		end
		PrintDebug("--")
	end
	
	if _LZWList[1] then
		str = _LZWStringDecompress(activePico:PeekString(_LZWList[1].packAdr,_LZWList[1].packSize))
		PrintDebug("decompress",#str, _LZWList[1].srcSize)
		for nb,code in str:codes() do
			if activePico:Peek(_LZWList[1].srcAdr + nb - 1) != code then
				PrintDebug("mist",nb, activePico:Peek(_LZWList[1].srcAdr + nb - 1) , code)
				break
			end
		end
		PrintDebug("--")
		
	end
	--]]
end

-- remove all unneeded elements in list and stores it in the to save data
local function _ListFinalize()
	-- remove all packs, if present
	for nb,d in pairs(_LZWList) do
		d.pack = nil
		d.equalSrc = nil
		d.equalDest = nil
	end
	-- save only if changed
	if #_LZWList == 0 and activePico:SaveDataGet("LZW","list") != nil then
		activePico:SaveDataSet("LZW","list",nil)
		
	elseif #_LZWList != 0 then
		activePico:SaveDataSet("LZW","list",_LZWList)
	end	
	
	if _baseAdr != (activePico:SaveDataGet("LZW","baseAdr") or 0x8000) then
		activePico:SaveDataSet("LZW","baseAdr",_baseAdr)
	end	
	
	if _limitSize != (activePico:SaveDataGet("LZW","limitSize") or 0x7fff) then
		activePico:SaveDataSet("LZW","limitSize",_limitSize)
	end	
end

-- compress a range and store it to the lzwList
local function _ListAddCompressedMemory(posStart,posEnd)
	if posStart == posEnd then return false end
	
	-- prepare list
	_ListInitalize()
	
	-- compress
	local srcSize = posEnd - posStart + 1
	local pack = _LZWStringCompress( activePico:PeekString( posStart, srcSize))
	local packSize = #pack
	local destAdr = posStart
	local name = ""

	-- try to find a good name
	if posStart == activePico:MusicAdr(0) then
		destAdr = Pico.MUSIC
		name = "Music"
	elseif posStart == activePico:SFXAdr(0) then
		destAdr = Pico.SFX
		name = "Sound"
	elseif posStart == activePico:SpriteAdr(0) then
		destAdr = Pico.SPRITE
		name = "Sprite"
	elseif posStart == activePico:SpriteFlagAdr(0) then
		destAdr = Pico.SPRFLAG
		name = "SprFlag"
	elseif posStart == Pico.CHARSET then
		name = "Charset"
	elseif posStart == Pico.PAL then
		name = "Palette"		
	end
	
	-- add, when fit in the pack-space
	if _writeAdr + packSize >= _baseAdr + _limitSize then
		InfoBoxSet(string.format("Out of space! %i / %i", _writeAdr + packSize - _baseAdr, _limitSize ))
		return false
	end
	
	-- add entry
	table.insert(_LZWList, { 
		srcAdr = posStart,
		srcSize = srcSize,
		packAdr = _writeAdr,
		packSize = packSize,
		destAdr = destAdr,
		sha1 = sha1.sha1(pack),
		name = name,
	})
	-- write memory
	activePico:PokeString(_writeAdr,pack)
	_writeAdr += packSize
	-- finish list
	_ListFinalize()
	
	InfoBoxSet(string.format("Compressed %i to %i, %.2f", srcSize, packSize, packSize / srcSize * 100))	
	return true
end

-- checks the memory, if lost packed data are presents.
local function _ListValidate()
	local new = {}
	
	-- check sha1 and copy valid data to new list
	for nb,d in pairs(_LZWList) do
		d.pack = activePico:PeekString(d.packAdr, d.packSize)
		if sha1.sha1(d.pack) == d.sha1 then
			table.insert(new, d)
		end
	end
	
	local t = SDL.Time.Get()
	
	local adr = _baseAdr
	while adr < _writeAdr + _limitSize - 2 do
	
		-- draw a progress bar
		_progressBarPercent = (adr - _baseAdr) / _limitSize * 100
		if (SDL.Time.Get() - t) > 0.033 then
			MainWindowDraw()
			t = SDL.Time.Get()
			while SDL.Event.Poll().type do end
		end
	
		-- scan memory for pack data
		local tokens = activePico:Peek2(adr)
		if  tokens > 10 and tokens < _limitSize-(adr - _baseAdr)  then
			local pack = activePico:PeekString(adr, _limitSize - (adr - _baseAdr))
			local src = _LZWStringDecompress(pack)
			
			-- check if repack data is equal unknown data
			local repack = _LZWStringCompress(src)
			if repack == pack:sub(1,#repack) then						
				local ok = true
				-- already in the list?
				for nb,d in pairs(new) do
					if d.pack == repack then 
						ok = false
						break
					end
				end
				
				if ok then
					-- no insert
					table.insert(new, { 
						srcAdr = 0x0000,
						srcSize = #src,
						packAdr = adr,
						packSize = #repack,
						destAdr = 0x0000,
						pack = repack,
						sha1 = sha1.sha1(repack),
						name = "<found>",
					})
				end
				
				adr += #repack - 1 -- +1 comes later!
			end
	
		end
		adr += 1
	end
	
	_progressBarPercent = nil

	-- use new list and rebuild pack-memory
	_LZWList = new
	_ListRemovePack()
	_ListFinalize()
	
	InfoBoxSet("Validated.")
	MainWindowResize()
end

-- move or delete current entry (0=delete, +/-1 move)
local function _ListMoveDelete(delta)
	-- search current entry
	local sel
	for nb,d in pairs(_LZWList) do
		if d == _LZWSelect then sel = nb break end
	end
	if not sel then return false end
	
	-- swap 
	local swap = sel + delta
	if swap < 1 or swap > #_LZWList then return false end
	
	-- build pack list
	_ListInsertPack()

	if sel != swap then 
		-- move
		_LZWList[sel], _LZWList[swap] = _LZWList[swap], _LZWList[sel]
	else
		-- delete
		table.remove(_LZWList,sel)
		_LZWSelect = nil
	end
	
	-- rebuild
	_ListRemovePack()
	_ListFinalize()	
	m:Resize()
	return true
end

-- when the base-adr has changed, this function read all data and move it to the new position
local function _ListReposition()
	_ListInsertPack()
	_ListRemovePack()
	_ListFinalize()	
	m:Resize()
end

-- update the current element with the data from source
local function _ListUpdateFromSource()
	if not _LZWSelect then return end
	
	_ListInsertPack()
	
	_LZWSelect.pack = _LZWStringCompress( activePico:PeekString( _LZWSelect.srcAdr, _LZWSelect.srcSize) )
	_LZWSelect.sha1 = sha1.sha1(_LZWSelect.pack)
	_writeAdr = _baseAdr
			
	_ListRemovePack()
	_ListFinalize()
	
	m:Resize()
	InfoBoxSet("Updated.")
end

-- unpack the current element to the destination
local function _ListUnpackToDestination()
	if not _LZWSelect then return end
	activePico:PokeString( _LZWSelect.destAdr, _LZWStringDecompress( activePico:PeekString( _LZWSelect.packAdr, _LZWSelect.packSize) ) )
	InfoBoxSet(string.format("Unpacked to 0x%04x, %i bytes.", _LZWSelect.destAdr, _LZWSelect.srcSize))
	m:Resize()
end

-- unpack the current element to the source
local function _ListUnpackToSource()
	if not _LZWSelect then return end
	activePico:PokeString( _LZWSelect.srcAdr, _LZWStringDecompress( activePico:PeekString( _LZWSelect.packAdr, _LZWSelect.packSize) ) )
	InfoBoxSet(string.format("Unpacked to 0x%04x, %i bytes.", _LZWSelect.srcAdr, _LZWSelect.srcSize))
	m:Resize()
end

-- copy the table with the adresses to the clipboard
local function _ListCopyTableToClipboard()
	--_lzwdata = split "0x0000,0x0000,0x3c2e,0xe000,0x1411,0x5f56"
	
	local str = "_lzwdata = split \""
	for nb,d in pairs(_LZWList) do
		str ..= (nb > 1 and "," or "") .. string.format("0x%04x,0x%04x", d.packAdr, d.destAdr)	
	end
	str ..="\""
	
	SDL.Clipboard.SetText(str)
	InfoBoxSet("Copied table code to clipboard.")	
end


--===================================================================
---------------------------------------------------------------MODULE
--===================================================================

-- initalize
function m.Init(m)
	local w2,h2 = SizeText("+",2)
	m.buttons = buttons:CreateContainer()
	m.scrollbar = scrollbar:CreateContainer()
	m.inputs = inputs:CreateContainer()
	
	-- Add a Button in Hex-Module
	moduleHex:API_AddGetRange("LZW range",_ListAddCompressedMemory)
	
	-- we need a scrollbar
	m.scrollbar:Add("list",1,1,false)
	
	-- and some input/buttons
	local b,inp
	b = m.buttons:Add("validate","Validate",200,nil)
	b.OnClick = _ListValidate
	
	b = m.buttons:Add("reposition","Reposition",200,nil)
	b.OnClick = _ListReposition
	
	b = m.buttons:Add("up","Up",200,nil)
	b.OnClick = function(but) _ListMoveDelete(-1) end
	
	b = m.buttons:Add("down","Down",200,nil)
	b.OnClick = function(but) _ListMoveDelete(1) end
	
	b = m.buttons:Add("delete","Delete",200,nil)
	b.OnClick = function(but) _ListMoveDelete(0) end
	
	b = m.buttons:Add("updateSrc","Update from Source", 200, nil)
	b.OnClick = _ListUpdateFromSource
	
	b = m.buttons:Add("unpackDest", "Unpack to Destination",200,nil)
	b.OnClick = _ListUnpackToDestination
	
	b = m.buttons:Add("unpackSrc", "Unpack to Source", 200, nil)
	b.OnClick = _ListUnpackToSource
	
	b = m.buttons:Add("copyCode", "Copy decompress code", 200, nil)
	b.OnClick = _CopyUncompressCode
	
	b = m.buttons:Add("copyTable", "Copy table code", 200, nil)
	b.OnClick = _ListCopyTableToClipboard
	
	inp = m.inputs:Add("range","Range:","",200)
	inp.OnTextChange = function(inp, text)
		local f,a,b = _Calc(text)
		if f then
			a = math.clamp(0,0xffff,tonumber(a) or 0)
			b = math.clamp(a + 1,0x10000,a + (tonumber(b) or 0))
			_baseAdr = a
			_limitSize = b - a
			_ListFinalize()
			m:Resize()
		end
	end
	
	-- change name dialog
	_ppLZWname = popup:Add("lzwName",0,0)
	inp = _ppLZWname.inputs:Add("name", "", "", w2 * 8, h2 )
	inp.textLimit = 8
	inp.OnTextChange = function (inp,text)
		if _LZWSelect then
			_LZWSelect.name = text
			_ListFinalize()
			m:Resize()
		end
		_ppLZWname:Close()
	end
	_ppLZWname:Resize()
	
	-- change dest dialog
	_ppLZWdest = popup:Add("lzwDest",0,0)
	inp = _ppLZWdest.inputs:Add("dest", "", "", w2 * 11, h2 )
	inp.OnTextChange = function (inp,text)
		if _LZWSelect then
			_LZWSelect.destAdr = (tonumber(text) or _LZWSelect.destAdr) & 0xffff		
			_ListFinalize()		
			m:Resize()
		end
		_ppLZWdest:Close()
	end
	_ppLZWdest:Resize()
	
	
	-- custom menu
	m.menuBar = SDL.Menu.Create()	
	
	MenuAddFile(m.menuBar)
	MenuAddPico8(m.menuBar)
	MenuAddSettings(m.menuBar)
	MenuAddDebug(m.menuBar)


	return true
end

-- free resources
function m.Quit(m)
	m.buttons:DestroyContainer()
	m.inputs:DestroyContainer()
	m.scrollbar:DestroyContainer()
	m.menuBar:Destroy()
	popup:Remove(_ppLZWdest)
	popup:Remove(_ppLZWname)
end

-- focus got
function m.FocusGained(m)
	_ListInitalize()	
end

-- focus lost
function m.FocusLost(m)
	_ListFinalize()
end

-- resize
function m.Resize(m)
	local w2,h2 = SizeText("+",2)
	local w1,h1 = SizeText("+")
	local ow, oh = renderer:GetOutputSize()

	-- update list
	_ListInitalize()
	
	-- position list
	_rectBack  = {x = 5 + (ow - MINWIDTH) \ 2, y = topLimit, w = #_TITLESTRING * w2 + 10, h = oh - topLimit - 5}
	_rectTitle = {x = _rectBack.x, y = _rectBack.y, w = _rectBack.w, h = h2 + 10}
	_rectList  = {x = _rectTitle.x + 5, y = _rectTitle.y + _rectTitle.h + 5, w = _rectTitle.w - 10, h = _rectBack.h - _rectTitle.h - 10}
	
	-- position scrollbar
	m.scrollbar.list:SetPos(_rectBack.x + _rectBack.w + 5, _rectList.y, BARSIZE, _rectList.h)
	m.scrollbar.list:SetValues(nil, _rectList.h \ h2, #_LZWList)
	
	-- position buttons
	m.buttons.validate:SetPos(_rectBack.x + _rectBack.w + 5 + BARSIZE + 5,topLimit)
	m.buttons.reposition:SetDown()
	m.buttons.up:SetDown(10)
	m.buttons.down:SetDown()
	m.buttons.delete:SetDown(10)
	m.buttons.updateSrc:SetDown(10)
	m.buttons.unpackSrc:SetDown()
	m.buttons.unpackDest:SetDown()
	m.buttons.copyCode:SetDown(10)
	m.buttons.copyTable:SetDown()
	
	-- fill bar (indicate how full the pack-memory is)
	_rectFillBar = {x = _rectBack.x + _rectBack.w + 5 + BARSIZE + 5, y = oh - 5 - h1 - 10, h = h1 +10}
	_rectFillBar.w = ow - _rectFillBar.x - 5
	_rectFillBarUsed = table.copy(_rectFillBar)
	_rectFillBarUsed.w = _rectFillBar.w * (_writeAdr - _baseAdr) \ _limitSize
	
	-- position range input
	m.inputs.range:SetPos(_rectFillBar.x, _rectFillBar.y - 5 - m.inputs.range.rectBack.h)
	m.inputs.range:Resize(_rectFillBar.w)
	
end

function m.Draw(m)
	local w2,h2 = SizeText("+",2)
	local ow, oh = renderer:GetOutputSize()
	
	-- draw fill bar
	DrawFilledRect(_rectFillBar, COLGREY,nil,true)
	renderer:SetClipRect(_rectFillBarUsed)
	DrawFilledRect(_rectFillBar, Pico.RGB[13],nil,true)
	renderer:SetClipRect(nil)
	local str = string.format("%.2f%%", (_writeAdr - _baseAdr) * 100 / _limitSize)
	local w,h = SizeText(str)
	DrawText(_rectFillBar.x + (_rectFillBar.w - w)\2, _rectFillBar.y + (_rectFillBar.h - h) \ 2, str,Pico.RGB[7])
	
	-- update range text
	if not m.inputs:HasFocus() then
		m.inputs.range.text = string.format("0x%04x, ".. (config.sizeAsHex and "0x%04x" or "%i"),_baseAdr, _limitSize)
	end
	
	-- background
	DrawFilledRect(_rectBack, COLDARKGREY,nil,true)
	DrawFilledRect(_rectTitle, COLGREY,nil,true)
	
	-- draw title
	DrawText( _rectTitle.x + 5, _rectTitle.y + 5, _TITLESTRING, Pico.RGB[15], 2)
	
	renderer:SetClipRect(_rectList)
	
	local offset,page = m.scrollbar.list:GetValues()	
	local xx,yy = _rectList.x, _rectList.y
	for i=0,page do
		local nb = i + offset + 1
		local d = _LZWList[nb]
		
		if d then 
			-- highlight selected
			if d == _LZWSelect then
				DrawFilledRect({_rectBack.x, yy, _rectBack.w, h2}, Pico.RGB[2])
			end
			-- draw line
			_,yy = DrawText(xx,yy, string.format(config.sizeAsHex and _FORMATSTRINGHEX or _FORMATSTRING,nb, d.name or "", 
													d.equalSrc and "=" or "!",d.srcAdr, d.srcSize, 
													d.packAdr, d.packSize, 
													d.equalDest and "=" or "!",d.destAdr, d.srcSize, 
													d.packSize / d.srcSize * 100), d.packSize > 0x2000 and COLRED or Pico.RGB[7], 2)
		end	
	end
	renderer:SetClipRect(nil)
	
	-- draw a progress bar, if needed
	if _progressBarPercent then
		local str = string.format("%3.2f%%", _progressBarPercent)
		local w,h = SizeText(str,2)
		
		
		
		local rect = {0, oh / 2 - h, ow , h * 2} 
		DrawFilledRect(rect, COLGREY, 255, true)
		rect.w = ow * _progressBarPercent \ 100
		renderer:SetClipRect(rect)
		rect.w = ow
		DrawFilledRect(rect, Pico.RGB[8], 255, true)
		renderer:SetClipRect(nil)
		DrawText((ow - w) \ 2, (oh - h) \ 2, str, Pico.RGB[7],2)
	end
	
	
end

-- mouse-handling
function m.MouseDown(m, mx, my, mb, clicks)
	local w2,h2 = SizeText("+",2)
	if SDL.Rect.ContainsPoint(_rectList, {mx, my}) then
		local x,y = (mx - _rectList.x) \ w2, (my - _rectList.y) \ h2
		if y < #_LZWList then
			local old = _LZWSelect
			_LZWSelect = _LZWList[y+1]
						
			if mb == "LEFT" and clicks > 1 and old == _LZWSelect then
				-- doubleclick - check column
				local sel = _COLUMNSTRING:sub(x,x)
				local startX = ((_COLUMNSTRING:find(sel,1,true) or x) - 1) * w2 + _rectList.x
				if sel == "n" then
					-- rename 
					_ppLZWname:Open(startX,y * h2 + _rectList.y + h2)
					_ppLZWname.inputs.name.text = _LZWSelect.name or ""
					_ppLZWname.inputs:SetFocus(_ppLZWname.inputs.name,true)
					
				elseif sel == "s" then
					-- open source in hex module
					moduleHex:API_SelectRange(_LZWSelect.srcAdr, _LZWSelect.srcAdr + _LZWSelect.srcSize - 1 )
					
				elseif sel == "p" then
					-- open packdata in hex module
					moduleHex:API_SelectRange(_LZWSelect.packAdr, _LZWSelect.packAdr + _LZWSelect.packSize - 1)
					
				elseif sel == "d" then
					-- rename dest
					_ppLZWdest:Open(startX,y * h2 + _rectList.y + h2)
					_ppLZWdest.inputs.dest.text = string.format("0x%04x", _LZWSelect.destAdr or 0)
					_ppLZWdest.inputs:SetFocus(_ppLZWdest.inputs.dest,true)
				end
			end
			
		else
			_LZWSelect = nil
		end
	end
	
end

-- wheel scroll list
function m.MouseWheel(m, wx, wy, mx, my)
	local barPos = m.scrollbar.list:GetValues()
	m.scrollbar.list:SetValues(barPos - wy)	
end

-- delete entry
function m.Delete(m)
	m.buttons.delete:OnClick()
end

return m