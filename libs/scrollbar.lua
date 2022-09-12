local lib = {}
local _selected = nil
local _selectedArray = nil
local _offset = 0
local libMeta =  {}

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

-- create a container 
function libMeta.CreateContainer()
	local t = {}
	setmetatable(t, libMeta)
	return t
end

-- destroy a container
function libMeta.DestroyContainer(t)
	while t:Remove(next(t)) do		
	end
end

--  add new scrollbar
function libMeta.Add(array,id,w,h,dir,pos,page,max)
	local t = {
		rect = {x = 0, y = 0, w = w, h = h},
		rectPos = {x = 0, y = 0, w = w, h = h},
		rectPos2 = {x = 0, y = 0, w = w, h = h},
		dir = dir,
		page = page or 1,
		pos = pos or 0,
		pos2 = 0,
		pos3 = 0,
		max = max or 0,
		div = 1,
		visible = true,
		onChange = nil
	}
	setmetatable(t,libMeta)
	array[id] = t
	t:SetValues()
	return t
end

-- remove scrollbar
function libMeta.Remove(sb,e)
	if e and sb[e.id] then 
		sb[e.id] = nil
		return true
	end
	return false	
end

-- scrollbar in use?
function libMeta.HasFocus(sb)
	return _selected != nil and _selectedArray == sb
end

-- change scrollbar values (pos2&3 are marks on the bar)
function libMeta.SetValues(sb, pos, page, max, pos2, pos3)
	local oldPos = sb.pos
	
	sb.max  = math.max(1, (max or sb.max) \ 1)
	sb.page = math.clamp(0, (page or sb.page) \ 1, sb.max)
	sb.pos  = math.clamp(0, (pos or sb.pos) \ 1, sb.max - sb.page)
	sb.pos2  = math.clamp(0, (pos2 or sb.pos2) \ 1, sb.max)
	sb.pos3  = math.clamp(0, (pos3 or sb.pos3) \ 1, sb.max)
	
	if sb.pos2 > sb.pos3 then
		sb.pos2, sb.pos3 = sb.pos3, sb.pos2
	end
	

	if sb.dir then
		sb.div = sb.rect.w / sb.max
		sb.rectPos.w = sb.page * sb.div \ 1
		sb.rectPos.x = sb.pos * sb.div \ 1 + sb.rect.x		
		
		sb.rectPos2.x = sb.pos2 * sb.div \ 1 + sb.rect.x
		sb.rectPos2.w = sb.pos3 * sb.div \ 1 + sb.rect.x - sb.rectPos2.x + 1
		
	else
		sb.div = sb.rect.h / sb.max
		sb.rectPos.h = sb.page * sb.div \ 1
		sb.rectPos.y = sb.pos * sb.div \ 1 + sb.rect.y
		
		sb.rectPos2.y = sb.pos2 * sb.div \ 1 + sb.rect.y
		sb.rectPos2.h = sb.pos3 * sb.div \ 1 + sb.rect.y - sb.rectPos2.y + 1		
	end
	
	if oldPos != sb.pos and sb.onChange then
		sb:onChange(sb.pos, sb.page, sb.max)
	end
	
	return sb.pos, sb.page, sb.max, sb.pos2, sb.pos3
end

-- return values of the bar
function libMeta.GetValues(sb)
	return sb.pos, sb.page, sb.max, sb.pos2, sb.pos3
end

-- set position
function libMeta.SetPos(sb,x,y,w,h)	
	sb.rect.x = x or sb.rect.x
	sb.rect.y = y or sb.rect.y
	sb.rect.w = w or sb.rect.w
	sb.rect.h = h or sb.rect.h
	sb.rectPos.x = sb.rect.x
	sb.rectPos.y = sb.rect.y
	sb.rectPos.w = sb.rect.w
	sb.rectPos.h = sb.rect.h
	sb.rectPos2.x = sb.rect.x
	sb.rectPos2.y = sb.rect.y
	sb.rectPos2.w = sb.rect.w
	sb.rectPos2.h = sb.rect.h	
	-- update values
	sb:SetValues()
end

-- Draw scrollbar
function libMeta.Draw(array)
	for id,sb in pairs(array) do
		if sb.visible then 
			DrawFilledRect(sb.rect, COLDARKGREY)
			
			if sb.pos2 != sb.pos3 then
				DrawFilledRect(sb.rectPos2, Pico.RGB[2], 255, true)	
			end
			
			DrawFilledRect(sb.rectPos, COLLIGHTGREY, 255, true)	
		end
	end
	return array:HasFocus()
end

-- mouseclick
function libMeta.MouseDown(array,mx,my,mb)
	if mb == "LEFT" then
		for id,sb in pairs(array) do
			if sb.visible and SDL.Rect.ContainsPoint(sb.rect, {mx, my}) then
				_selected = sb
				_selectedArray = array
				if SDL.Rect.ContainsPoint(sb.rectPos, {mx, my}) then
					-- click in the "page"
					if sb.dir then
						_offset = mx - sb.pos * sb.div
					else 
						_offset = my - sb.pos * sb.div
					end
				else
					-- outside - move page-center to mouse
					if sb.dir then
						sb:SetValues( (mx - sb.rect.x) / sb.div - sb.page / 2 )
						_offset = mx - sb.pos * sb.div
					else
						sb:SetValues( (my - sb.rect.y) / sb.div - sb.page / 2 )
						_offset = my - sb.pos * sb.div				
					end
				end
				return true
			end
		end
	end
	return false
end

-- mousemove
function libMeta.MouseMove(array,mx,my,mb)
	if _selected and _selectedArray == array then
		-- change relativ to offset
		local pos 
		if _selected.dir then
			pos = (mx - _offset) / _selected.div			
		else
			pos = (my - _offset) / _selected.div
		end
		_selected:SetValues( pos )		
		
		return true
	end
	return false
end

-- mouse-finish
function libMeta.MouseUp(array,mx,my,mb)
	if mb=="LEFT" and _selected and _selectedArray == array then
		_selected = nil
		_selectedArray = nil
		return true
	end
	return false
end


return lib