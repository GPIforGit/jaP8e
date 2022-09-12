local lib = {}
local libMeta = {}
local _display = nil

local _shouldClose = false

libMeta.__index = libMeta
setmetatable(lib, libMeta)

-- initalize
function libMeta.Init(l)
	-- nothing to do
end

-- quit
function libMeta.Quit(l)
	l:DestroyContainer()
end

-- destroy container
function libMeta.DestroyContainer(t)
	while t:Remove(next(t)) do		
	end
end

-- create a new popup
function libMeta.Add(p,id,w,h)
	p[id] = {
		id = id,
		rect = {x = 0, y = 0, w = w, h = h},
		offx = 0,
		offy = 0,
		buttons = buttons:CreateContainer(),
		inputs = inputs:CreateContainer(),
		scrollbar = scrollbar:CreateContainer(),
		hexFilter = 0xffff
	}
	setmetatable(p[id],libMeta)
	return p[id]
end

-- resize
function libMeta.Resize(p,w,h)
	p.rect.w = w or p.rect.w
	p.rect.h = h or p.rect.h
		
	if p.rect.w == 0 or p.rect.h == 0 then
		local ww, hh = 0,0
		for nb,ele in pairs(p.buttons) do
			if ele.visible then
				ww = math.max(ww, ele.rectBack.x - p.offx + ele.rectBack.w)
				hh = math.max(hh, ele.rectBack.y - p.offy + ele.rectBack.h)
			end
		end
		for nb,ele in pairs(p.inputs) do
			if ele.visible then
				ww = math.max(ww, ele.rectBack.x - p.offx + ele.rectBack.w)
				hh = math.max(hh, ele.rectBack.y - p.offy + ele.rectBack.h)
			end
		end
		for nb,ele in pairs(p.scrollbar) do
			if ele.visible then
				ww = math.max(ww, ele.rectBack.x - p.offx + ele.rectBack.w)
				hh = math.max(hh, ele.rectBack.y - p.offy + ele.rectBack.h)
			end
		end
		
		if p.rect.w == 0 then p.rect.w = ww end
		if p.rect.h == 0 then p.rect.h = hh end
	end
		
end

-- remove a popup
function libMeta.Remove(p,e)
	if e and p[e.id] then
		e.buttons:DestroyContainer()
		e.inputs:DestroyContainer()
		e.scrollbar:DestroyContainer()
		p[e.id] = nil
		return true
	end
	return false	
end

-- a popup is open and has focus
function libMeta.HasFocus(p)
	if _shouldClose then _shouldClose = false _display = nil return false end
	return _display != nil
end

-- open a pop-up
function libMeta.Open(p, x, y)
	_display = p
	local ow, oh = renderer:GetOutputSize()
	
	x = math.clamp(0, x, math.max(0, ow - p.rect.w - 3))
	y = math.clamp(0, y - p.rect.h, math.max(0, oh - p.rect.h - 3))
	
	
	
	for nb,but in pairs(p.buttons) do
		but:SetPos( but.rectBack.x - p.offx + x, but.rectBack.y - p.offy + y)		
	end
	for nb,inp in pairs(p.inputs) do
		inp:SetPos( inp.rectBack.x - p.offx + x, inp.rectBack.y - p.offy + y)		
	end
	for nb,sb in pairs(p.scrollbar) do
		sb:SetPos( sb.rectBack.x - p.offx + x, sb.rectBack.y - p.offy + y)		
	end
	p.offx = x
	p.offy = y
	p.rect.x = x
	p.rect.y = y
	
	_shouldClose = false
	
end

-- close a pop-up
function libMeta.Close(p)
	if p == _display or p == popup then
		_shouldClose = true
	end
end

function libMeta.ForceClose()
	_display = nil
end

-- mouse-click
function libMeta.MouseDown(p, mx, my, mb)	
	if _display == nil then return false end
	if _shouldClose then _shouldClose = false _display = nil return false end
	
	if SDL.Rect.ContainsPoint(_display.rect,{mx,my}) then
		if not _display.scrollbar:MouseDown(mx, my, mb) then
			if not _display.inputs:MouseDown(mx, my, mb) then
				_display.buttons:MouseDown(mx, my, mb)
			end
		end
	else 
		_display = nil
	end
	return true
end

-- mouse move
function libMeta.MouseMove(p, mx, my, mb)
	if _shouldClose then _shouldClose = false _display = nil return false end
	if _display == nil then return false end
	_display.scrollbar:MouseMove(mx,my,mb)
	_display.buttons:MouseMove(mx,my,mb)
	_display.inputs:MouseMove(mx,my,mb)
	return true
end

-- mouse up
function libMeta.MouseUp(p,mx, my, mb)
	if _shouldClose then _shouldClose = false _display = nil return false end
	if _display == nil then return false end
	_display.scrollbar:MouseUp(mx,my,mb)
	_display.buttons:MouseUp(mx,my,mb)
	_display.inputs:MouseUp(mx,my,mb)
	--_display = nil
	return true
end

-- mouseWheel
function libMeta.MouseWheel(p,x,y,mx,my)
	if _shouldClose then _shouldClose = false _display = nil return false end
	if _display == nil then return false end
	return _display.inputs:MouseWheel(x,y,mx,my)
end

-- draw control
function libMeta.Draw(p,mx, my)
	if _shouldClose then _shouldClose = false _display = nil return false end
	if _display == nil then return false end
	-- background
	DrawBorder(_display.rect.x, _display.rect.y, _display.rect.w, _display.rect.h, COLGREY)
	DrawFilledRect(_display.rect,COLDARKGREY,0xff,true)
	-- content
	_display.scrollbar:Draw(mx,my)
	_display.buttons:Draw(mx,my)
	_display.inputs:Draw(mx,my)
	return true
end

-- key down -> to inputs
function libMeta.KeyDown(p, sym, scan, mod)
	if _shouldClose then _shouldClose = false _display = nil return false end
	if _display == nil then return false end
	_display.inputs:KeyDown(sym, scan, mod)
	if sym == "ESCAPE" then
		_display = nil
	end
	return true
end

-- key up -> to inputs
function libMeta.KeyUp(p, sym, scan, mod)
	if _shouldClose then _shouldClose = false _display = nil return false end
	if _display == nil then return false end
	return true
end

-- input -> to inputs
function libMeta.Input(p, sym)
	if _shouldClose then _shouldClose = false _display = nil return false end
	if _display == nil then return false end
	_display.inputs:Input(sym)
	return true
end


function libMeta.Paste(p, str)
	if _shouldClose then _shouldClose = false _display = nil return false end
	if _display == nil then return false end
	return _display.inputs:Paste(str)
end

function libMeta.Copy(p, str)
	if _shouldClose then _shouldClose = false _display = nil return false end
	if _display == nil then return false end
	return _display.inputs:Copy()
end

return lib