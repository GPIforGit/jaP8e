modules = modules or {}

local m = {
	name = "Pattern", -- name
	sort = 75,  --- sort order - 0-100 is reserved, also init-order
}
table.insert(modules, m)

local _texPattern
local _opt = 0x101c
local _ZOOM = 4
local _rectDest = { x = 0, y = 0, w = 4 * _ZOOM, h = 4 * _ZOOM}
local _rectFillp
local _rectEdit
local _lock
local _selTemplate = 0
local _template = {0x5a5a, 0x511f, 0x7d7d, 0xb81d, 0xf99f, 0x51bf, 0xb5bf, 0x999f, 0xb11f, 0xa0e0, 0x9b3f, 0xb1bf, 0xf5ff, 0xb15f, 0x1b1f, 0xf5bf, 0x7adf, 0x0f0f, 0x5555, 0xcc33, 0x8421, 0x1248, 0x4242, 0x05a0, 0x4a12, 0x2584, 0x1f4f, 0x75d5, 0x7888, 0xc3c3, 0x55aa, 0x8000, 0x8020, 0xa020, 0xa0a0, 0xa4a0, 0xa4a1, 0xa5a1, 0xa5a5, 0xe5a5, 0xe5b5, 0xf5b5, 0xf5f5, 0xfdf5, 0xfdf7, 0xfff7, 0xffff }

local function _GetPattern(i)
	i = i or _selTemplate
	local ret = activePico:SaveDataGet("fillPattern",i) or _template[i]
	return ret or 0
end

local function _SetPattern(i,pat)
	i = i or _selTemplate
	if pat == _template[i] or (_template[i] == nil and pat == 0) then
		activePico:SaveDataSet("fillPattern",i,nil)
	else
		activePico:SaveDataSet("fillPattern",i,pat)
	end
end



local function _ButOption(b)
	if _opt & b.index != 0 then
		_opt &= ~ b.index
	else
		_opt |= b.index
	end
	m:Resize()
end
local function _ButColor1(b)
	_opt = (_opt & 0xfff0) | b.index
	m:Resize()
end
local function _ButColor2(b)
	_opt = (_opt & 0xff0f) | (b.index << 4)
	m:Resize()
end

local function _Val(text)
	local a,b = string.match(text, "^%s*0x(%x*)%.(%x*)%s*$")
	if not a and not b then a,b = string.match(text, "^%s*0x(%x*)%s*$"),0 end	
	if a and b then
		return tonumber("0x"..a), tonumber("0x"..(b.."0000"):sub(1,4))
	end
	
	a,b = string.match(text, "^%s*([%-]?%d*)%.(%d*)%s*$")
	if not a and not b then a,b = string.match(text, "^%s*([%-]?%d*)%s*$"),0 end
	if a and b then
		a = tonumber(a)
		b = tonumber("0."..b)
		if a < 0 and b > 0 then 
			return (a-1) & 0xffff, (1-b)* 0x10000 \1
		end
		
		return a & 0xffff, b * 0x10000 \1
	end
	
	a,b = string.match(text, "^%s*0b([01]*)%.([01]*)%s*$")
	if not a and not b then a,b = string.match(text, "^%s*0b([01]*)%s*$"),"0" end
	if a and b then
		local value = 0
		for i=0,15 do			
			if a:sub(-1-i,-1-i) == "1" then
				value |= 1<<i
			end
		end
		local value2 = 0
		for i=0,15 do
			if b:sub(1+i,1+i) == "1" then
				value2 |= 1<<(15-i)
			end
		end
		return value,value2
	end
	return nil,nil
end

local function _inpFillp(inp)
	local a,b = _Val(inp.text)	
	if a and b then		
		_SetPattern(_selTemplate, a)
		_opt &= 0x10ff
		if b & 0x8000 != 0 then _opt |= 0x100 end
		if b & 0x4000 != 0 then _opt |= 0x200 end
		if b & 0x2000 != 0 then _opt |= 0x400 end
	end
	m:Resize()
end

local function _inpColorPat(inp)
	local a,b = _Val(inp.text)
	if a and b then
		_SetPattern(_selTemplate, b)
		_opt = a | 0x1000
	end
	m:Resize()	
end

local function _inpColor(inp)
	local a = _Val(inp.text)
	if a then
		_opt = (_opt & 0xff00) | (a & 0xff)
	end
	m:Resize()
end
	
local function _inpTextChange(inp)
	local value = _Val(inp.text)		
	if value then
		_SetPattern(_selTemplate, value)
	end
	m:Resize()
end

local function _DotGet(x,y)
	local i = x + (y * 4)
	local pat = _GetPattern(_selTemplate)
	return pat & (1 << i) != 0 
end

local function _DotSet(x,y,state)
	local i = x + (y * 4)
	local pat = _GetPattern(_selTemplate)
	
	if state then
		pat |= 1 << i
	else
		pat &= ~(1 << i)
	end
	
	_SetPattern(_selTemplate, pat)	
end

local function _Shift(dx,dy)
	local w,h = overArea.cellRect.w, overArea.cellRect.h
	local xs,xe
	local ys,ye
	
	if dx == -1 then
		xs = 0
		xe = 2
	elseif dx == 1 then
		xs = 2
		xe = 0
	else
		xs = 0
		xe = 3
	end
	
	if dy == -1 then
		ys = 0
		ye = 2
	elseif dy == 1 then
		ys = 2
		ye = 0
	else
		ys = 0
		ye = 3
	end

	for yy = ys, ye, (ys<ye and 1 or -1)  do
		for xx = xs, xe, (xs<xe and 1 or -1)  do
			local x2 = (xx + dx) % 4
			local y2 = (yy + dy) % 4
			local s1,s2 = _DotGet(xx,yy), _DotGet(x2,y2)
			_DotSet(xx,yy,s2)
			_DotSet(x2,y2,s1)
		end
	end
	m:Resize()
end

local function _ButInvert()
	local pat = _GetPattern(_selTemplate)
	pat = (~pat) & 0xffff
	_SetPattern(_selTemplate, pat)
	m:Resize()
end

local function _ButFlipX()
	for y = 0,3 do
		for x = 0,1 do
			local p1,p2 = _DotGet(x,y), _DotGet(3-x,y)
			_DotSet(x,y,p2)
			_DotSet(3-x,y,p1)
		end
	end
	m:Resize()
end
local function _ButFlipY()
	for x = 0,3 do
		for y = 0,1 do
			local p1,p2 = _DotGet(x,y), _DotGet(x,3-y)
			_DotSet(x,y,p2)
			_DotSet(x,3-y,p1)
		end
	end
	m:Resize()
end

local function _ButTurnRight(but)
	for z = 0, 1 do
		for d = 0, 2 - z * 2 do
			local s1 = _DotGet(z+d,z)
			local s2 = _DotGet(3-z,z+d)
			local s3 = _DotGet(3-z-d,3-z)
			local s4 = _DotGet(z,3-z-d)

			_DotSet(z+d,z,s4)
			_DotSet(3-z,z+d,s1)
			_DotSet(3-z-d,3-z,s2)
			_DotSet(z,3-z-d,s3)
		end
	end
	m:Resize()
end

-- rotate to left
local function _ButTurnLeft(but)
	for z = 0, 1 do
		for d = 0, 2 - z * 2 do
			local s1 = _DotGet(z+d,z)
			local s2 = _DotGet(3-z,z+d)
			local s3 = _DotGet(3-z-d,3-z)
			local s4 = _DotGet(z,3-z-d)

			_DotSet(z+d,z,s2)
			_DotSet(3-z,z+d,s3)
			_DotSet(3-z-d,3-z,s4)
			_DotSet(z,3-z-d,s1)
		end
	end
	m:Resize()
end


local function _initShortcut()
	local SelPattern = function(s)
		if not s.shift and _selTemplate + s.off >= 0 and _selTemplate + s.off <= 255 then
			_selTemplate += s.off
		end
		m:Resize()
	end

	m.shortcut = {}
	ShortcutAddMoveCursor16x16(m.shortcut,SelPattern)
	
	ShortcutAddTransform(m.shortcut,
		_ButFlipX,_ButFlipY,
		_ButTurnLeft,_ButTurnLeft,
		m.buttons.shiftLeft.OnClick,m.buttons.shiftRight.OnClick,
		m.buttons.shiftUp.OnClick,m.buttons.shiftDown.OnClick,
		_ButInvert
	)		
end

function m.Init(m)
	m.buttons = buttons:CreateContainer()
	m.inputs = inputs:CreateContainer()
	local b
	
	b = m.buttons:Add("flipX", "Flip x", 100)
	b.OnClick = _ButFlipX
	b = m.buttons:Add("flipY", "Flip y", 100)
	b.OnClick = _ButFlipY
	
	b = m.buttons:Add("turnLeft", "Turn left",100)
	b.OnClick = _ButTurnLeft
	b = m.buttons:Add("turnRight", "Turn right",100)
	b.OnClick = _ButTurnRight
	
	b = m.buttons:Add("shiftLeft", "Shift left",100)
	b.OnClick = function() _Shift(1,0) end
	b = m.buttons:Add("shiftRight", "Shift right",100)
	b.OnClick = function() _Shift(-1,0) end
	b = m.buttons:Add("shiftUp", "Shift up",100)
	b.OnClick = function() _Shift(0,1) end
	b = m.buttons:Add("shiftDown", "Shift down",100)
	b.OnClick = function() _Shift(0,-1) end
	
	b = m.buttons:Add("invert","Invert",100)
	b.OnClick = _ButInvert
	
	b = m.inputs:Add("hex", "", "0x0000.0  ")
	b.OnTextChange = _inpTextChange
	
	b = m.inputs:Add("bin", "Pattern:", "0b0000000000000000.000  ")	
	b.OnTextChange = _inpTextChange
	
	b = m.inputs:Add("dez", "", "+32767.125  ")
	b.OnTextChange = _inpTextChange
	
	b = m.inputs:Add("col", "Color:", "0x00  ")
	b.OnTextChange = _inpColor
	
	b = m.inputs:Add("colDez", "", "256  ")
	b.OnTextChange = _inpColor
	
	b = m.inputs:Add("colpat",   "Color-Pattern:", "0b0000000000000000      ")
	b.OnTextChange = _inpColorPat
	
	b = m.inputs:Add("fillp", "fillp  :", "0b0000000000000000.000  ")	
	b.OnTextChange = _inpFillp
	b = m.inputs:Add("fillpHex","", "0x0000.0  ")
	b.OnTextChange = _inpFillp
	b = m.inputs:Add("fillpDez","", "+32767.125  ")
	b.OnTextChange = _inpFillp
	
	b = m.buttons:Add("trans", "Transparency",nil,nil,"TOOGLE")
	b.index = 0x0100
	b.OnClick = _ButOption
	b = m.buttons:Add("sprites", "Apply to Sprites",nil,nil,"TOOGLE")
	b.index = 0x0200
	b.OnClick = _ButOption
	b = m.buttons:Add("pal2", "Apply Secondary Palette Globally",nil,nil,"TOOGLE")
	b.index = 0x0400
	b.OnClick = _ButOption
	
	local w = m.buttons.trans.rectBack.h
	
	for i = 0,15 do
		b = m.buttons:AddColor("pal2"..i, COLBLACK,w,w,"PAL1")
		b.index = i
		b.OnClick = _ButColor2
		b = m.buttons:AddColor("pal1"..i, COLBLACK,w,w,"PAL2")
		b.index = i
		b.OnClick = _ButColor1
	end
		
	_texPattern = renderer:CreateTexture("RGBA32","STREAMING",4,4)
	_texTemplate = renderer:CreateTexture("RGBA32","STREAMING",128,128)
	
	_initShortcut()
	
	return true
end

function m.Quit(m)
	m.buttons:DestroyContainer()
	m.inputs:DestroyContainer()
	
	if _texPattern then
		_texPattern:Destroy()
		_texPattern = nil
	end	
	if _texTemplate then
		_texTemplate:Destroy()
		_texTemplate = nil
	end	
end

function m.FocusGained(m)
end

function m.FocusLost(m)
end


function m.Resize(m)
	local ow, oh = renderer:GetOutputSize()
	local x,y = 5 + 128*4 + 10 + (ow - MINWIDTH) \ 2, topLimit + (oh - MINHEIGHT) \ 2 --(oh - 32 * 4) / 2
	
	_rectFillp = { x = x + 32*4 + 10, y = y, w = 32 * 4, h = 32 * 4 }
	_rectEdit = { x = x, y = y, w = 32 * 4, h = 32 * 4 }
	_rectTemplate = { x = x - 16 * 32 - 10, y = y, w = 16 * 32, h = 16 * 32}
	
	local b
	b = m.buttons.flipX:SetPos(x, y + 32*4 + 5)
	m.buttons.shiftLeft:SetRight(1)
	m.buttons.invert:SetRight(1)
	
	b = m.buttons.flipY:SetDown(b,1)
	m.buttons.shiftRight:SetRight(1)
	
	b = m.buttons.turnLeft:SetDown(b,1)
	m.buttons.shiftUp:SetRight(1)
	
	b = m.buttons.turnRight:SetDown(b,1)
	m.buttons.shiftDown:SetRight(1)
		
	b = m.inputs.bin:SetDown(b)
	m.inputs.hex:SetRight(1)
	m.inputs.dez:SetRight(1)
	
	
	b = m.buttons.trans:SetDown(b)
	b.selected = _opt & b.index != 0
	
	b = m.buttons.sprites:SetDown()
	b.selected = _opt & b.index	!= 0
	
	b = m.buttons.pal2:SetDown()
	b.selected = _opt & b.index != 0
	
	b = m.inputs.fillp:SetDown(b)
	m.inputs.fillpHex:SetRight(1)
	m.inputs.fillpDez:SetRight(1)
	
	b = m.buttons.pal20:SetDown(b)	
	for i=0,15 do
		local b = m.buttons["pal2"..i]
		if i != 0 then 
			b:SetRight(1)
		end
		b:SetColor( activePico:PaletteGetRGB(i) )	
	end
	
	b = m.buttons.pal10:SetDown(b)
	for i=0,15 do
		local b = m.buttons["pal1"..i]
		if i != 0 then 
			b:SetRight(1)
		end
		b:SetColor( activePico:PaletteGetRGB(i) )	
	end
	
	b = m.inputs.col:SetDown(b)
	m.inputs.colDez:SetRight(1)
	
	b = m.inputs.colpat:SetDown(b)
	
	local pat = _GetPattern(_selTemplate)
	
	
	m.buttons:SetRadio(m.buttons["pal1"..(_opt & 0xf)])
	m.buttons:SetRadio(m.buttons["pal2"..((_opt >> 4) & 0xf)])
	
	if not inputs:HasFocus() then
		local str = "0b"
		for i=15,0,-1 do
			str ..= (pat & (1<<i) != 0) and "1" or "0"
		end		
		m.inputs.bin.text = str
		m.inputs.hex.text = string.format("0x%04x",pat)		
		
		m.inputs.col.text = string.format("0x%02x",_opt & 0xff)
		m.inputs.colDez.text = tostring(_opt & 0xff)
		
		m.inputs.colpat.text = string.format("0x%04x.%04x",_opt,pat)
		local o = 0
		if _opt & 0x100 != 0 then o |= 0x8000 end
		if _opt & 0x200 != 0 then o |= 0x4000 end
		if _opt & 0x400 != 0 then o |= 0x2000 end
		
		str ..= "."
		for i=15,13,-1 do
			str ..= (o & (1<<i) != 0) and "1" or "0"
		end
		m.inputs.fillp.text = str
		m.inputs.fillpHex.text = string.format("0x%04x.%01x",pat,o>>12)
		if pat >= 0x8000 then
			m.inputs.fillpDez.text = string.format("%.3f",( (-32768 + (pat & 0x7fff) ) + o/0x10000))
			m.inputs.dez.text = tostring(-32768 + (pat & 0x7fff))
		else
			m.inputs.fillpDez.text = string.format("%.3f",pat + o/0x10000)
			m.inputs.dez.text = tostring(pat)
		end
	end
	

	
	
	local data,pitch = _texPattern:Lock()	
	for y = 0, 3 do
		local adr = pitch * y
		for x = 0, 3 do
			i = (3 - x) + (3 - y)*4
			if pat & (1 << i) != 0 then 
				data:setu32(adr, 0xffffffff) 
			else
				data:setu32(adr, 0x00000000)
			end
			adr += 4
		end
	end
	_texPattern:Unlock()
	local col = activePico:PaletteGetRGB((_opt >> 4) & 0xf)
	_texPattern:SetBlendMode("BLEND")	
	_texPattern:SetColorMod(col.r, col.g, col.b)
	_texPattern:SetScaleMode("NEAREST")
	
	
	local data,pitch = _texTemplate:Lock()
	for py = 0, 127 do 
		local adr = pitch * py
		for px = 0, 127  do
			local tmp = px \ 8 + (py \ 8) * 16
			local i =  (3 - (px % 4)) + ( 3 - (py % 4)) * 4
			local pat = _GetPattern(tmp) \1
			--print(px,py, tmp, i, pat)
			if pat & (1 << i) != 0 then 
				data:setu32(adr, 0xffffffff) 
			else
				data:setu32(adr, 0x00000000)
			end
			adr += 4
		end
	end
	_texTemplate:Unlock()
	
	_texTemplate:SetBlendMode("BLEND")	
	_texTemplate:SetColorMod(col.r, col.g, col.b)
	_texTemplate:SetScaleMode("NEAREST")
			
end

function m.Draw(m)
	local ow, oh = renderer:GetOutputSize()
	local col = activePico:PaletteGetRGB(_opt & 0xf)

	DrawBorder(_rectTemplate.x, _rectTemplate.y, _rectTemplate.w, _rectTemplate.h, COLGREY)
	DrawFilledRect(_rectTemplate,col)
	renderer:Copy(_texTemplate,nil, _rectTemplate)
	for i = 0, 15 do 
		DrawFilledRect({_rectTemplate.x + i * 32, _rectTemplate.y, 1, _rectTemplate.h}, COLGREY)
		DrawFilledRect({_rectTemplate.x, _rectTemplate.y + i * 32, _rectTemplate.w, 1}, COLGREY)
	end
	DrawGridBorder( _rectTemplate.x, _rectTemplate.y,
		_selTemplate % 16,
		_selTemplate \ 16,
		_selTemplate % 16,
		_selTemplate \ 16,
		32,
		COLWHITE		
	)		
	
	

	DrawBorder(_rectEdit.x, _rectEdit.y, _rectEdit.w, _rectEdit.h, COLGREY)
	DrawFilledRect(_rectEdit, COLBLACK)

	local pat = _GetPattern(_selTemplate)
	for i = 0, 15 do
		local x,y = 3 - (i % 4), 3 - (i \ 4)
		if pat & (1 << i) != 0 then
			DrawFilledRect({_rectEdit.x + x * 32, _rectEdit.y + y * 32, 32, 32},Pico.RGB[7])
		end
	end
	for i = 0, 3 do
		DrawFilledRect({_rectEdit.x + i * 32, _rectEdit.y, 1, _rectEdit.h}, COLGREY)
		DrawFilledRect({_rectEdit.x, _rectEdit.y + i * 32, _rectEdit.w, 1}, COLGREY)
	end
	


	DrawBorder(_rectFillp.x, _rectFillp.y, _rectFillp.w, _rectFillp.h, COLGREY)
	renderer:SetClipRect(_rectFillp)
	DrawFilledRect(_rectFillp, col)
	
	_rectDest.y = _rectFillp.y
	while _rectDest.y <  _rectFillp.h + _rectFillp.y do
		_rectDest.x = _rectFillp.x
		while _rectDest.x <  _rectFillp.w + _rectFillp.x  do
			renderer:Copy(_texPattern, nil, _rectDest)
		
			_rectDest.x += _rectDest.w
		end
		
		_rectDest.y += _rectDest.h
	end
	
	renderer:SetClipRect(nil)
end
		
function m.MouseDown(m, mx, my, mb)
	if _lock then return end
	
	if mb == "LEFT" and SDL.Rect.ContainsPoint(_rectTemplate, {mx, my}) then
		local i = (mx - _rectTemplate.x) \ 32 + (my - _rectTemplate.y) \ 32 * 16 	
		if _selTemplate != i then
			if SDL.Keyboard.GetModState():hasflag("CTRL") > 0 then
				local a,b = _GetPattern(_selTemplate), _GetPattern(i)
				_SetPattern(_selTemplate,b)
				_SetPattern(i, a)
			end		
			_selTemplate = i
			m:Resize()
		end
	end
	
	if mb == "LEFT" and SDL.Rect.ContainsPoint(_rectEdit, {mx, my}) then
		local x = 3 - (mx - _rectEdit.x) \ 32
		local y = 3 - (my - _rectEdit.y) \ 32	
		if _DotGet(x,y) then
			_lock = "unset"
			_DotSet(x,y,false)
		else
			_lock = "set"
			_DotSet(x,y,true)
		end
		m:Resize()
	
	end
end

function m.MouseMove(m, mx, my)
	if SDL.Rect.ContainsPoint(_rectEdit, {mx, my}) then
		if _lock == "unset" or _lock == "set" then
			local x = 3 - (mx - _rectEdit.x) \ 32
			local y = 3 - (my - _rectEdit.y) \ 32
			if _lock == "unset" then
				_DotSet(x,y,false)
			else
				_DotSet(x,y,true)
			end			
			m:Resize()			
		end
	
	end
end

function m.MouseUp(m, mx, my, mb)
	if mb == "LEFT" and (_lock == "unset" or _lock == "set") then
		_lock = nil
	end
end

function m.Delete(m)
	_SetPattern(_selTemplate, 0)
	m:Resize()
end	

function m.Copy(m)
	local ret = string.format("0x%04x",_GetPattern(_selTemplate))
	
	InfoBoxSet("Copied "..ret.." pattern.")
	
	return ret
end

function m.Paste(m,str)
	local v = _Val(str)
	if v then 
		_SetPattern(_selTemplate, v)
		m:Resize()
	end	
	
end

return m