--[[
	music module

	basic music edit - should work like 

--]]

modules = modules or {}
local m = {
	name = "Music",
	sort = 50,
}

table.insert(modules, m)

local _nb = 0
local _nbEnd = 0
local _music
local _sfx= {}
local _cursorVoice
local _cursorNote,_cursorNoteEnd = 1, 1
local _cursorColumn = 1
local _rectVoice = {}
local _rectNotes = {}
local _mouseLock
local _sfxEntryWidth
local _sfxEntryHeight
local _sfxRect
local _musicEntryWidth
local _musicEntryHeight
local _musicRect


-- Read SFX from memory
local function _SFXRead(i, nb)
	_music.sfx[i] = math.clamp(0, 63, tonumber(nb) or _music.sfx[i])
	m.inputs["sfx"..i].text = tostring(_music.sfx[i])
	m.inputs["sfxName"..i].text = activePico:SaveDataGet("SFXname", _music.sfx[i]) or ""
	m.inputs["sfx"..i].visible = not _music.disabled[i]	
	m.inputs["sfxName"..i].visible = not _music.disabled[i]
	m.buttons["edit"..i].visible = not _music.disabled[i]
	_sfx[i] = activePico:SFXGet( _music.sfx[i] )
end

-- Write SFX to memory
local function _SFXWrite(i)
	_music.sfx[i] = math.clamp(0, 63, tonumber(m.inputs["sfx"..i].text) or 0)
	activePico:SaveDataSet("SFXname", _music.sfx[i],  m.inputs["sfxName"..i].text)
	activePico:SFXSet( _music.sfx[i], _sfx[i] )
	PicoRemoteWrite(Pico.SFX + _music.sfx[i] * 68, 68,activePico:SFXAdr(_music.sfx[i]))
	_SFXRead(i)
end

-- Read Music from memory
local function _MusicRead(nb)
	_nb = math.clamp(0, 63, nb or _nb)
	_nbEnd = _nb
	
	m.inputs.music.text = tostring(_nb)
	
	_music = activePico:MusicGet(_nb)
	for i = 1,4 do		
		_SFXRead(i, _music.sfx[i])
		m.buttons["enable"..i].selected = not _music.disabled[i]
	end	
	
	m.inputs.musicName.text = activePico:SaveDataGet("MusicName", _nb) or ""
	
	m.buttons.beginLoop.selected = _music.beginLoop
	m.buttons.endLoop.selected = _music.endLoop
	m.buttons.stop.selected = _music.stop
end

-- Write Music to memory
local function _MusicWrite()
	_music.beginLoop = m.buttons.beginLoop.selected
	_music.endLoop = m.buttons.endLoop.selected
	_music.stop = m.buttons.stop.selected
	for i = 1, 4 do
		_SFXWrite(i)
		_music.disabled[i] = not m.buttons["enable"..i].selected
	end
		
	activePico:MusicSet(_nb, _music)
	
	activePico:SaveDataSet("MusicName", _nb, m.inputs.musicName.text)
	
	-- Update remote
	PicoRemoteWrite(Pico.MUSIC + _nb * 4, 4, activePico:MusicAdr(_nb))
	for i=1, 4 do
		PicoRemoteWrite(Pico.SFX + _music.sfx[i] * 68, 68,activePico:SFXAdr(_music.sfx[i]))
	end
	
	_MusicRead()
end

-- Allow other modules to switch the current music
function m.API_SetMusic(m, nb)
	ModuleActivate(m)
	_MusicRead(nb)
end

-- initalize
function m.Init(m)
	-- new configuration
	config.pasteSFXfromTop = config.pasteSFXfromTop != nil and config.pasteSFXfromTop or true
	config.showSFXnames = config.showSFXnames != nil and config.showSFXnames or true
	config.showSFXmusic = config.showSFXmusic != nil and config.showSFXmusic or true
	configComment.pasteSFXfromTop = "For Music - paste new SFX from top or beginn of the list"
	configComment.showSFXnames = "Show on sound-tiles names"
	configComment.showSFXmusic = "Show on sound-tiles the id of the music, where it is used"

	-- custom menu
	m.menuBar = SDL.Menu.Create()	
	
	MenuAddFile(m.menuBar)
		
	local men = MenuAddEdit(m.menuBar)
	men:Add()
	MenuAdd(men, "pasteSFXfromTop", "Paste SFX from top",
		function(e)
			config.pasteSFXfromTop = not config.pasteSFXfromTop
			men:SetCheck("pasteSFXfromTop", config.pasteSFXfromTop)
		end
	)
	MenuAddPico8(m.menuBar)
	MenuAddSettings(m.menuBar)
	MenuAddDebug(m.menuBar)
	m.MenuUpdate = function(m, men)
		men:SetCheck("pasteSFXfromTop", config.pasteSFXfromTop)
	end

	-- we need some buttons
	m.buttons = buttons:CreateContainer()
	m.inputs = inputs:CreateContainer()
	
	-- and a special texture	
	m.texMusicBack = renderer:LoadTexture("musicback.png")
	
	
	-- some buttons
	local b, inp
	function Update(but)
		_cursorVoice = nil
		_MusicWrite()
	end
	
	for i=1,4 do
		b = m.buttons:Add("enable"..i,"\017",nil,nil,"TOOGLE")		
		b.OnClick = function (but)
			_cursorVoice = but.selected and i or nil
			_MusicWrite()
		end
		
		b = m.buttons:Add("edit"..i,"*")
		b.OnClick = function(but)
			moduleSFX:API_SetSFX( _music.sfx[i] )
		end
		
		inp = m.inputs:Add("sfx"..i,"","00")
		inp.min = 0
		inp.max = 63
		inp.OnGainedFocus = function(inp)
				_cursorVoice = i
		end
		inp.OnTextChange = function(inp, text)
			_cursorVoice = i
			_SFXRead(i, text)
			_MusicWrite()
		end
		
		inp = m.inputs:Add("sfxName"..i,"","01234567")
		inp.textLimit = 8
		inp.OnGainedFocus = function(inp)
			_cursorVoice = i
		end
		inp.OnTextChange = function(inp,but)
			_cursorVoice = i
			_SFXWrite(i)
			_MusicRead()			
		end
		
		_rectVoice[i] = {x = 0, y = 0, w = 0, h = 0}
		_rectNotes[i] = {x = 0, y = 0, w = 0, h = 0}
		
	end
	
	inp = m.inputs:Add("musicName","Name:","01234567")
	inp.textLimit = 8
	inp.OnGainedFocus = function(inp)
		_cursorVoice = nil
	end
	inp.OnTextChange = Update
	
	inp = m.inputs:Add("music","","00")
	inp.min = 0
	inp.max = 63
	inp.OnTextChange = function (inp, text)
		_cursorVoice = nil
		_MusicRead( tonumber(text) or 0 )
	end
	inp.OnGainedFocus = function(inp)
		_cursorVoice = i
	end
	
	b = m.buttons:Add("musicLeft","-")
	b.OnClick = function(b)
		_cursorVoice = nil
		if _nb > 0 then
			_MusicRead(_nb - 1)
		end
	end
	
	b = m.buttons:Add("musicRight","+")
	b.OnClick = function(b)
		_cursorVoice = nil
		if _nb < 63 then
			_MusicRead(_nb + 1)
		end
	end
		
	b = m.buttons:Add("beginLoop","\023", nil, nil, "TOOGLE")
	b.OnClick = Update
	
	b = m.buttons:Add("endLoop","\022", nil, nil, "TOOGLE")
	b.OnClick = Update
	
	b = m.buttons:Add("stop", "\017", nil, nil, "TOOGLE")
	b.OnClick = Update
	
	b = m.buttons:Add("showSFXnames","Name",100,nil, "TOOGLE")
	b.OnClick = function(b) config.showSFXnames = b.selected end
	
	b = m.buttons:Add("showSFXmusic","Music",100,nil, "TOOGLE")
	b.OnClick = function(b) config.showSFXmusic = b.selected end
	
	b = m.buttons:AddHex("musicPos","Pos:",0,100,nil,Pico.MUSICPOS)
	b.hexFilter = 0xff08
	return true
end

-- free resources
function m.Quit(m)
	if m.texMusicBack then
		m.texMusicBack:Destroy()
		m.texMusicBack = nil
	end
	m.buttons:DestroyContainer()
	m.inputs:DestroyContainer()
	m.menuBar:Destroy()
end

--  resize
function m.Resize(m)
	local ow, oh = renderer:GetOutputSize()
	
	_sfxEntryWidth = 64
	_sfxEntryHeight = 64
	_sfxRect = { x = 5 + (ow - MINWIDTH) \ 2, y = topLimit, w = 8 * _sfxEntryWidth + 7 + 2, h = 8 * _sfxEntryHeight + 7 + 2}
	_sfxRect.y += (oh - _sfxRect.y - _sfxRect.h) \ 2

	_musicEntryWidth = 32
	_musicEntryHeight = 24
	_musicRect = { x = _sfxRect.x + _sfxRect.w + 15, y = topLimit + (oh-MINHEIGHT)\2, w = 16 * _musicEntryWidth + 15 + 2, h = 4 * _musicEntryHeight + 3 + 2 }
			
	-- reload music
	_music = nil
	_MusicRead()
	
	-- reposition buttons
	m.buttons.showSFXnames:SetPos(_sfxRect.x, _sfxRect.y + _sfxRect.h + 10)
	m.buttons.showSFXmusic:SetRight()
	m.buttons.showSFXnames.selected = config.showSFXnames
	m.buttons.showSFXmusic.selected = config.showSFXmusic
	
	
	local w = m.buttons.enable1.rectBack.w + 1 + m.inputs.sfxName1.rectBack.w + 10
	local x = _musicRect.x + (_musicRect.w - w * 4 +10) \ 2
		
	b = m.buttons.musicLeft:SetPos(x, _musicRect.y + _musicRect.h + 10)
	m.inputs.music:SetRight(1)
	m.buttons.musicRight:SetRight(1)
	
	m.buttons.beginLoop:SetRight(15)
	m.buttons.endLoop:SetRight()
	m.buttons.stop:SetRight()
	
	m.inputs.musicName:SetRight(15)
	
	local ww,hh = SizeText("+")
	
	local y = m.buttons.musicLeft.rectBack.y + m.buttons.musicLeft.rectBack.h + 10
		
	for i=1, 4 do
		m.buttons["enable"..i]:SetPos(x + (i - 1) * w, y)
		b = m.inputs["sfx"..i]:SetRight(1)		
		m.inputs["sfxName"..i]:SetDown(1)
		m.buttons["edit"..i]:SetRight(b,1)
		
		_rectVoice[i].x = m.buttons["enable"..i].rectBack.x - 2
		_rectVoice[i].y = m.buttons["enable"..i].rectBack.y - 2
		_rectVoice[i].w = m.inputs["sfxName"..i].rectBack.x + m.inputs["sfxName"..i].rectBack.w + 2 - _rectVoice[i].x
		_rectVoice[i].h = m.inputs["sfxName"..i].rectBack.y + m.inputs["sfxName"..i].rectBack.h + 2 - _rectVoice[i].y
		
		
		_rectNotes[i].y = m.inputs["sfxName"..i].rectBack.y + m.inputs["sfxName"..i].rectBack.h + 5
		_rectNotes[i].w = (6 + 4) * ww + 3 + 10
		_rectNotes[i].h = 32 * hh + 10
		_rectNotes[i].x = _rectVoice[i].x + (_rectVoice[i].w - _rectNotes[i].w) \ 2
	end
	
	m.buttons.musicPos:SetPos(ow - m.buttons.musicPos.rectBack.w - 5,topLimit)
	
	-- Update pico remote (when musicPos changed, a resize is performed!)
	PicoRemoteSFX(-1)
	PicoRemoteMusic(-1)
	PicoRemoteWrite(Pico.MUSIC,Pico.MUSICLEN,activePico:MusicAdr()) -- complete music/sfx - data
	PicoRemoteWrite(Pico.SFX,Pico.SFXLEN,activePico:SFXAdr())
end

-- got focus
function m.FocusGained(m)	
	m:Resize()	
	_mouseLock = nil
end

-- lost focus
function m.FocusLost(m)
	PicoRemoteMusic(-1)
	PicoRemoteSFX(-1)	
end

-- drawing
function m.Draw(m, mx, my)
	local w1,h1 = SizeText("+")
	
	-- is music/SFX playing?
	local mus,pat,s1,s2,s3,s4,t1,t2,t3,t4 = PicoRemoteStatus()	
	local played = { [s1]=t1, [s2]=t2, [s3]=t3, [s4]=t4 }
	
	if mus and pat != _nb then
		_MusicRead(pat)
		_cursorVoice = nil
	end
	
	-- reset used sfx-list
	local sfxUsedIn = {}
	local sfxMarked = {}
	for i = 0, 63 do
		sfxUsedIn[i] = {}
	end

	-- music
	DrawFilledRect( _musicRect,COLBLACK )

	local offx, offy = _musicRect.x + 1, _musicRect.y + 1
	for i = 0,63 do
		--mark sfx used in music
		local t = activePico:MusicGet(i)
		for a = 1, 4 do
			if not t.disabled[a] then 
				table.insert(sfxUsedIn[t.sfx[a]], i) 
				if not _cursorVoice and math.clamp(_nb, i, _nbEnd) == i then
					sfxMarked[ t.sfx[a] ] = true
				end
			end
		end
		
		-- Set tooltip with music name
		local xx,yy = (i % 16) * (_musicEntryWidth + 1) + offx, (i \ 16) * (_musicEntryHeight + 1) + offy
		if mx >= xx and my >= yy and mx <= xx + _musicEntryWidth and my <= yy + _musicEntryHeight then
			local mName = activePico:SaveDataGet("MusicName", i) or ""
			if mName != "" then
				TooltipText(mName,{x = xx, y = yy, w = _musicEntryWidth, h = _musicEntryHeight})
			end
			
		end
		
		-- select colors
		local col,tcol
		if t.disabled[1] and t.disabled[2] and t.disabled[3] and t.disabled[4] then
			col = (_nb == i) and Pico.RGB[9] or ((not _cursorVoice and math.clamp(i, _nb, _nbEnd) == i) and Pico.RGB[4] or Pico.RGB[1])
			tcol = Pico.RGB[0]			
		else
			col = (_nb == i) and Pico.RGB[8] or ((not _cursorVoice and math.clamp(i, _nb, _nbEnd) == i) and Pico.RGB[2] or Pico.RGB[13])
			tcol = Pico.RGB[6]		
		end
				
		-- draw music background (with "rounded" corners)
		m.texMusicBack:SetColorMod( col.r,col.g,col.b)
		m.texMusicBack:SetScaleMode("NEAREST")
		m.texMusicBack:SetBlendMode("BLEND")		
		local val = (t.beginLoop and 1 or 0) | (t.endLoop and 2 or 0) | (t.stop and 4 or 0)
		renderer:Copy(m.texMusicBack, {val * 8,0,8,8}, {xx,yy,_musicEntryWidth,_musicEntryHeight - 5})
		
		-- draw the 4 voices
		local w,h = (_musicEntryWidth-3 - 4) \ 4,3
		for i=1,4 do
			if not t.disabled[i] then
				local c = activePico:SFXDominate(t.sfx[i]) + 8
				if c > 15 then c = 3 end
				DrawFilledRect( {xx + (w + 1) * (i-1)+2, yy + _musicEntryHeight - 4, w, h}, Pico.RGB[ c ] )
			end
		end
		
		-- draw nb in music
		DrawText(xx + (_musicEntryWidth - w1 * 2) \ 2, yy + (_musicEntryHeight - h1 - 5) \ 2,string.format("%02i",i), tcol)
	
	end
	
	-- SFX --	
	DrawFilledRect(_sfxRect,COLBLACK)

	local offx,offy = _sfxRect.x + 1, _sfxRect.y + 1
	for i=0, 63	do
		-- calculate position
		local xx,yy = (i % 8) * (_sfxEntryWidth + 1) + offx, (i \ 8) * (_sfxEntryHeight + 1) + offy
		local rect =  {x = xx,y = yy, w = _sfxEntryWidth, h = _sfxEntryHeight}
				
		-- get the texture
		local tex= TexturesGetSFX(i)
		
		-- Background (and which color)
		local col
		
		if activePico:SFXEmpty(i) then 
			col = (i != _music.sfx[_cursorVoice] and not sfxMarked[i]) and COLBLACK or Pico.RGB[2]
		elseif #sfxUsedIn[i] > 0 then
			col = (i != _music.sfx[_cursorVoice] and not sfxMarked[i]) and COLDARKGREY or Pico.RGB[2]
		else
			col = (i != _music.sfx[_cursorVoice] and not sfxMarked[i]) and COLGREY or Pico.RGB[4]
		end			
		DrawFilledRect(rect, col ,nil, true)
		
		-- draw playing bar
		if played[ i ] and played[ i ] < 32 then
			DrawFilledRect({ x = rect.x + rect.w * played[i] \ 32, y = rect.y, w = rect.w \ 32 + 1, h = rect.h}, Pico.RGB[5])		
		end
		
		-- draw the sfx-texture
		tex:SetBlendMode("BLEND")
		tex:SetScaleMode("NEAREST")
		renderer:Copy( tex, nil, rect)
		
		-- draw name of the sfx		
		renderer:SetClipRect(rect)
		if config.showSFXnames then
			local str = activePico:SaveDataGet("SFXname",i) or ""
			if str == "" then str = string.format("%02d",i) end
			DrawText(rect.x+1,rect.y+1,str,Pico.RGB[6])
		end
		if config.showSFXmusic then
			for nb,muNb in pairs(sfxUsedIn[i]) do
				DrawText(rect.x + 1 + w1 * 3 * ((nb-1) % 3), rect.y + h1 * ((nb-1)\3+1) + 1 , muNb, Pico.RGB[5])
			end
		end
		renderer:SetClipRect(nil)		
		
	end
	
	-- details all voices
	for i = 1, 4 do
		DrawFilledRect( _rectVoice[i], i == _cursorVoice and Pico.RGB[13] or COLBLACK )
		--background
		if not _music.disabled[i] then
			DrawFilledRect( _rectNotes[i], COLBLACK )
		
			if _cursorVoice == i and not m.inputs:HasFocus() then
				
				local s,e = _cursorNote,_cursorNoteEnd
				if s > e then s,e = e,s end
			
				-- selection background
				local rect =  { 
					x = _rectNotes[i].x + 5 + w1 * 4,
					y = _rectNotes[i].y + 5 + h1 * (s - 1),
					w = w1 * 6 + 3,
					h = h1 * (e - s + 1),
				}							
				DrawFilledRect( rect, (s == e) and Pico.RGB[1] or Pico.RGB[2] )
				
				-- cursor
				rect.y = _rectNotes[i].y + 5 + h1 * (_cursorNote - 1)
				if _cursorColumn == 1 then
					rect.w = w1 * 2
				elseif _cursorColumn == 2 then
					rect.x += w1 * 2
					rect.w = w1
				elseif _cursorColumn == 3 then
					rect.x += w1 * 3 + 1
					rect.w = w1
				elseif _cursorColumn == 4 then
					rect.x += w1 * 4 + 2
					rect.w = w1
				elseif _cursorColumn == 5 then
					rect.x += w1 * 5 + 3
					rect.w = w1
				end
				rect.h = h1
				DrawFilledRect( rect,  Pico.RGB[8] )
				
			end
			
			-- draw playing bar
			if played[ _music.sfx[i] ] and played[ _music.sfx[i] ] < 32 then
				local rect =  { 
					x = _rectNotes[i].x + 5 + w1 * 4,
					y = _rectNotes[i].y + 5 + h1 * played[ _music.sfx[i] ],
					w = w1 * 6 + 3,
					h = h1,
				}	
				DrawFilledRect( rect, Pico.RGB[5])
			end
			
			-- draw loop bar
			if _sfx[i].loopStart != _sfx[i].loopEnd and _sfx[i].loopStart < 33 then
				local rect =  { 
					x = _rectNotes[i].x + 5,
					y = _rectNotes[i].y + 5 + h1 * _sfx[i].loopStart - 2,
					w = w1 * 10 + 3,
					h = 2,
				}
				DrawFilledRect(rect, Pico.RGB[13])
			end
						
			if _sfx[i].loopStart < _sfx[i].loopEnd and _sfx[i].loopEnd < 33 then
				local rect =  { 
					x = _rectNotes[i].x + 5,
					y = _rectNotes[i].y + 5 + h1 * _sfx[i].loopEnd - 2,
					w = w1 * 10 + 3,
					h = 2,
				}
				DrawFilledRect(rect, Pico.RGB[13])
			end
			
			
			-- draw notes
			for n = 0, 31 do
				local note = _sfx[i].notes[n + 1]
			
				local xx,y = _rectNotes[i].x + 5, _rectNotes[i].y + 5 + h1 * n
				
				xx = DrawText(xx,y,string.format("%2i: ",n), Pico.RGB[5])
												
				if note.volume > 0 then 			
					xx = DrawText(xx,y, Pico.NOTENAME[ (note.pitch % #Pico.NOTENAME) +1],Pico.RGB[7])		
					xx = DrawText(xx,y, note.pitch \ #Pico.NOTENAME,Pico.RGB[6])
					xx = DrawText(xx+1,y, note.wave % 8, Pico.RGB[ (note.wave > 7) and 11 or 14 ])
					xx = DrawText(xx+1,y, note.volume, Pico.RGB[12])
					xx = DrawText(xx+1,y, note.effect > 0 and note.effect or ".", Pico.RGB[13])
				else
					if note.alwaysVisible then
						xx = DrawText(xx,y,Pico.NOTENAME[ (note.pitch % #Pico.NOTENAME) +1],Pico.RGB[1])		
						xx = DrawText(xx,y, note.pitch \ #Pico.NOTENAME,Pico.RGB[1])
						xx = DrawText(xx+1,y, note.volume > 0 and (note.wave % 8) or ".", Pico.RGB[ (note.wave > 7) and 2 or 1 ])
						xx = DrawText(xx+1,y, note.volume > 0 and note.volume or ".", Pico.RGB[1])
						xx = DrawText(xx+1,y, note.effect > 0 and note.effect or ".", Pico.RGB[1])
					else			
						xx = DrawText(xx,y,"...",Pico.RGB[1])
						xx = DrawText(xx+1,y,".",Pico.RGB[1])
						xx = DrawText(xx+1,y,".",Pico.RGB[1])
						xx = DrawText(xx+1,y,".",Pico.RGB[1])
					end
				end
			end
		end
	end
end

-- mouse click
function m.MouseDown(m, mx, my, mb)
	if _mouseLock then return false end

	local w1,h1 = SizeText("+")
	
	if mb == "LEFT" then
		-- click in SFX
		if _cursorVoice then
			local xx = (mx - _sfxRect.x - 1) \ (_sfxEntryWidth + 1)
			local yy = (my - _sfxRect.y - 1) \ (_sfxEntryHeight + 1)
			if xx >= 0 and xx < 8 and yy >= 0 and yy < 8 then
				_SFXRead(_cursorVoice, xx + yy  *8)
				_MusicWrite()
				return true
			end		
		end
		
		-- click in Music
		local xx = (mx - _musicRect.x - 1) \ (_musicEntryWidth + 1)
		local yy = (my - _musicRect.y - 1) \ (_musicEntryHeight + 1)
		if xx >= 0 and xx < 16 and yy >= 0 and yy < 4 then
			_cursorVoice = nil
			if SDL.Keyboard.GetModState():hasflag("SHIFT") == 0 then
				_MusicRead( xx + yy * 16 )
				_mouseLock = "selectMusic"
			else
				_nbEnd = math.clamp(xx + yy * 16, 0 ,63)
			end
			return true
		end
		
		-- click in details
		for i=1, 4 do 
			if not _music.disabled[i] then
				-- click in header of voice
				if SDL.Rect.ContainsPoint(_rectVoice[i], {mx, my}) then
					_cursorVoice = i
					return true
				end
				
				-- click in notes
				if SDL.Rect.ContainsPoint(_rectNotes[i], {mx, my}) then
					_cursorVoice = i
					
					local xx = mx - _rectNotes[i].x - 5 - w1 * 4
					local yy = (my - _rectNotes[i].y - 5) \ h1 + 1
					if SDL.Keyboard.GetModState():hasflag("SHIFT") == 0 then
						_cursorNote = math.clamp(yy,1,32)
						_cursorNoteEnd = _cursorNote
						
						if xx <= w1 * 2 then
							_cursorColumn = 1
						elseif xx <= w1 * 3 then
							_cursorColumn = 2
						elseif xx <= w1 * 4 + 1 then
							_cursorColumn = 3
						elseif xx <= w1 * 5 + 1 then
							_cursorColumn = 4
						else
							_cursorColumn = 5
						end
						_mouseLock = "selectNotes"
					else
						_cursorNoteEnd = math.clamp(yy,1,32)
					end
					
					return true
				end
			end
		end
	end
	
	_cursorVoice = nil
	return false
end

-- move
function m.MouseMove(m,mx,my,mb)
	local w1,h1 = SizeText("+")
	
	if _mouseLock == "selectNotes" and _cursorVoice and SDL.Rect.ContainsPoint(_rectNotes[_cursorVoice], {mx, my})  then
		local yy = (my - _rectNotes[_cursorVoice].y - 5) \ h1 + 1
		_cursorNote = math.clamp(yy,1,32)
		return true
	end
	
	if _mouseLock == "selectMusic" then
		local xx = (mx - _musicRect.x - 1) \ (_musicEntryWidth + 1)
		local yy = (my - _musicRect.y - 1) \ (_musicEntryHeight + 1)
		if xx >= 0 and xx < 16 and yy >= 0 and yy < 4 then
			_nbEnd = math.clamp(0,63, xx + yy * 16 )
			return true
		end
	end
	
	return false
end

-- mouse release
function m.MouseUp(m,mx,my,mb)
	if mb == "LEFT" and _mouseLock == "selectNotes" then
		_mouseLock = nil
	end
	if mb == "LEFT" and _mouseLock == "selectMusic" then
		_mouseLock = nil
	end
end

-- transposing 
local function _transposing(scan)
	if not _cursorVoice then return end
	local f = string.find("ZSXDCVGBHNJMQ2W3ER5T6Y7UI9O0P",scan,1,true) 
	if f then
		local sfxNotes = _sfx[_cursorVoice].notes
		local s,e = _cursorNote, _cursorNoteEnd
		if s > e then s,e = e,s end
		if s == e then s,e = 1,32 end
		for i = s, e do
			sfxNotes[i].pitch = math.clamp (sfxNotes[i].pitch + f - 13,0,63)
		end
		_SFXWrite(_cursorVoice)
		InfoBoxSet(string.format("Transposing %d.", f-13))	
	end
end

-- key down
local _numkey = { ["1"]=1, ["2"]=2, ["3"]=3, ["4"]=4, ["5"]=5, ["6"]=6, ["7"]=7, ["8"]=8, ["9"]=9, ["0"]=0,
				 KP_1=1, KP_2=2, KP_3=3, KP_4=4, KP_5=5, KP_6=6, KP_7=7, KP_8=8, KP_9=9, KP_0=0}

function m.KeyDown(m, sym, scan, mod)
	if mod:hasflag("CTRL ALT GUI") > 0 or m.lock then return nil end
	
	if mod:hasflag("SHIFT") > 0 then
		-- move cursor and select
		if scan == "UP" then
			_cursorNote -= 1
		elseif scan == "DOWN" then
			_cursorNote += 1		
		end
		
	else
		-- move cursor
		if scan == "UP" then
			_cursorNote -= 1
			_cursorNoteEnd = _cursorNote
		elseif scan == "DOWN" then
			_cursorNote += 1
			_cursorNoteEnd = _cursorNote
		elseif scan == "LEFT" then
			_cursorColumn -= 1
		elseif scan == "RIGHT" then
			_cursorColumn += 1
		end
	end
	
	if scan == "ESCAPE" then
		-- escape exit voice edit
		_cursorVoice = nil
		
	elseif scan == "SPACE" then
		-- playing music
		local mus,pat,s1,s2,s3,s4,t1,t2,t3,t4 = PicoRemoteStatus()
		if mus or s1 != -1 then 
			-- stop playing
			PicoRemoteMusic( -1 )			
			PicoRemoteSFX( -1 )
		elseif _cursorVoice then
			-- cursor in Voice -> playback SFX 
			if _cursorNote == _cursorNoteEnd then
				PicoRemoteSFX( _music.sfx[_cursorVoice] )
			else
				PicoRemoteSFX( _music.sfx[_cursorVoice], _cursorNote - 1, _cursorNoteEnd - 1 )
			end
		else
			-- playback music
			PicoRemoteMusic( _nb )
		end
	
	elseif scan == "KP_MINUS" or sym == "MINUS" then
		if _cursorVoice then
			-- change sfx in voice-modus
			if _music.sfx[_cursorVoice] > 0 then
				 _music.sfx[_cursorVoice] -= 1
				 _SFXRead(_cursorVoice)
				 _MusicWrite()
			end
		else			
			-- change current music
			if _nb > 0 then
				_nb -= 1
				_MusicRead()
			end
		end
		
	elseif scan == "KP_PLUS" or sym == "PLUS" then
		if _cursorVoice then
			-- change sfx in voice-modus
			if _music.sfx[_cursorVoice] < 31 then
				 _music.sfx[_cursorVoice] += 1
				 _SFXRead(_cursorVoice)
				 _MusicWrite()
			end
		else
			-- change current music
			if _nb < 63 then
				_nb += 1
				_MusicRead()
			end
		end
	end
	
	if _cursorVoice then
		-- editing voice / SFX
		local f = _numkey[sym] -- translate key in number 
		local f2 = string.find("ZSXDCVGBHNJMQ2W3ER5T6Y7UI", scan, 1, true) 
		local sfxNotes = _sfx[_cursorVoice].notes
		local note = sfxNotes[ _cursorNote ]
				
		if _cursorNote == _cursorNoteEnd then		
			if mod:hasflag("SHIFT")>0 then 
				-- SHIFT pressed
				if _cursorColumn == 3 and f and f <= 7 then
					-- set special waveform wenn cursor in wave-column
					f += 8
					note.wave = f
					_SFXWrite(_cursorVoice)
					_cursorNote += 1
					_cursorNoteEnd = _cursorNote
				else 
					-- otherwise transpose
					_transposing(scan)
				end
				
			elseif _cursorColumn == 1 and f2 then
				-- note field
				local o = note.pitch \ 12
				if note.volume == 0 then
					note.volume = 5
				end		
				note.pitch = math.clamp(0, 63, f2 - 13 + o * 12)			
				_SFXWrite(_cursorVoice)
				_cursorNote += 1
				_cursorNoteEnd = _cursorNote
				
			elseif f then 
				-- number is entered
				
				if _cursorColumn == 2 and f <= 5 then 
					-- octave		
					note.pitch = math.clamp(0,63, (note.pitch % 12) + f * 12)
					_SFXWrite(_cursorVoice)
					_cursorNote += 1
					_cursorNoteEnd = _cursorNote
					
				elseif _cursorColumn == 3 and f <= 7 then		
					-- wave form
					note.wave = f
					_SFXWrite(_cursorVoice)
					_cursorNote += 1
					_cursorNoteEnd = _cursorNote
					
				elseif _cursorColumn == 4 and f <= 7 then
					-- volume
					note.volume = f
					_SFXWrite(_cursorVoice)
					_cursorNote += 1
					_cursorNoteEnd = _cursorNote
					
				elseif _cursorColumn == 5 and f <= 7 then
					-- effect
					note.effect = f
					_SFXWrite(_cursorVoice)
					_cursorNote += 1
					_cursorNoteEnd = _cursorNote				
				end
			
			elseif sym == "BACKSPACE" then
				if _cursorNote > 1 then
					-- remove note before cursor
					table.remove(sfxNotes, _cursorNote -1)
					table.insert(sfxNotes,{pitch = 0, wave = 0, volume = 0, effect = 0})
					_SFXWrite(_cursorVoice)
					_cursorNote -= 1
					_cursorNoteEnd = _cursorNote
				end
				
			elseif sym == "DELETE" then
				-- remove note under cursor
				table.remove(sfxNotes, _cursorNote)
				table.insert(sfxNotes,{pitch = 0, wave = 0, volume = 0, effect = 0})
				_SFXWrite(_cursorVoice)
			
			elseif sym == "RETURN" or sym == "KP_ENTER" then
				-- add note on cursor
				table.insert(sfxNotes, _cursorNote, {pitch = 0, wave = 0, volume = 0, effect = 0})
				table.remove(sfxNotes)
				_SFXWrite(_cursorVoice)
				_cursorNote += 1
				_cursorNoteEnd = _cursorNote
			
			end
		else
		
			if mod:hasflag("SHIFT")>0 then 
				-- check transposing
				_transposing(scan)
			end
			
			if scan == "BACKSPACE" or scan == "DELETE" then
				-- remove selection
				local start,size = math.min(_cursorNote, _cursorNoteEnd), math.abs(_cursorNote - _cursorNoteEnd)
				for i=0,size do
					table.remove(sfxNotes, start)
					table.insert(sfxNotes, {pitch = 0, wave = 0, volume = 0, effect = 0})
				end
				_cursorNote = start
				_cursorNoteEnd = start
				_SFXWrite(_cursorVoice)
			end
		end
		
	else
		if scan == "DELETE" then
			-- remove music
			local start, size = math.min(_nb, _nbEnd), math.abs(_nb - _nbEnd) + 1
			for i = start, start + size - 1 do
				local adr = activePico:MusicAdr(i)
				-- reset voices
				activePico:Poke(adr + 0, 64)
				activePico:Poke(adr + 1, 64)
				activePico:Poke(adr + 2, 64)
				activePico:Poke(adr + 3, 64)
				-- transfer to remote
				PicoRemoteWrite(Pico.MUSIC + i * 4, 4, adr)
			end
			_MusicRead(start)
		end
	end
	
	-- make sure, that the cursor is in allowed range
	_cursorNote = math.rotate(_cursorNote,1,32)
	_cursorNoteEnd = math.rotate(_cursorNoteEnd,1,32)
	_cursorColumn = math.rotate(_cursorColumn,1,5)
end

-- copy data to clipboards
function m.Copy(m)
	if _cursorVoice then		
		if _cursorNote != _cursorNoteEnd then
			-- copy notes
			local start,size = math.min(_cursorNote, _cursorNoteEnd), math.abs(_cursorNote - _cursorNoteEnd) + 1
			InfoBoxSet(string.format("Copied %d note(s).", size))
			return "[note]" .. string.format("%02x",size).. activePico:PeekHex(activePico:SFXAdr(_music.sfx[_cursorVoice]) + (start - 1) * 2, size * 2).."[/note]"
		else
			-- copy single sfx
			InfoBoxSet(string.format("Copied sfx %d.", _music.sfx[_cursorVoice]))
			return "[sfx]010000".. activePico:PeekHex(activePico:SFXAdr(_music.sfx[_cursorVoice]), 68).."[/sfx]"
		end
	else
		-- copy complete music + sfx
		local pattern = {}
		
		local mstart,msize = math.min(_nb, _nbEnd), math.abs(_nb - _nbEnd) + 1
		local strMusic = ""
		for nb = mstart, mstart + msize - 1 do
			mu = activePico:MusicGet(nb)

			-- add pattern list
			for i=1, 4 do
				if not mu.disabled[i] then 
					pattern[ mu.sfx[i] +1] = mu.sfx[i]
				end
			end		
			
			-- add music 
			strMusic ..= string.format(
				"%02x%02x%02x%02x%1x",
				mu.sfx[1] | (mu.disabled[1] and 64 or 0),
				mu.sfx[2] | (mu.disabled[2] and 64 or 0),
				mu.sfx[3] | (mu.disabled[3] and 64 or 0),
				mu.sfx[4] | (mu.disabled[4] and 64 or 0),
				(mu.beginLoop and 1 or 0) | (mu.endLoop and 2 or 0) | (mu.stop and 4 or 0)
			)
		end
		
		-- transfer every pattern
		local strPat = ""
		local countPat = 0
		for _,nb in pairs(pattern) do
			countPat += 1
			strPat ..= string.format("%02x",nb) .. activePico:PeekHex(activePico:SFXAdr(nb), 68)
		end
		
		-- inform the user
		InfoBoxSet(string.format("Copied %d music pattern and %d sfx pattern.", msize, countPat))
		
		-- combose complete string
		return "[sfx]" .. string.format("%02x%02x", countPat, msize) .. strPat .. strMusic .. "[/sfx]"
	end
	return nil
end

-- paste sfx/notes from clipboard
function m.Paste(m, str)
	if str:sub(1, 5) == "[sfx]" and str:sub(-6) == "[/sfx]" then
		-- paste music/sfx
		local countSFX = tonumber("0x".. str:sub(6,7)) or 0
		local countMusic = tonumber("0x"..str:sub(8,9)) or 0 
		local trans = {}

		-- search pattern if they already exist and if not, copy to memory
		for i = 0, countSFX - 1 do
			local pos = 10 + (68+1)*2 * i
			local sfxNb = tonumber("0x"..str:sub(pos,pos+1)) or 0
			local sfxHex = str:sub(pos+2,pos+2+68*2-1)
			
			-- search if sfx allready exist
			local searchNb
			for nb = 0, 63 do
				if activePico:MemoryCompareHex( activePico:SFXAdr(nb), sfxHex) then
					searchNb = nb
				end
			end
			
			-- no, search free position
			if not searchNb then
				local a1,a2,a3 = 0, 63, 1
				if config.pasteSFXfromTop then
					a1,a2,a3 = 63, 0, -1
				end
			
				-- scan all sfx
				for nb = a1, a2, a3 do
					local sfx = activePico:SFXGet(nb)
					local empty = true
					for i=1, 32 do
						if sfx.notes[i].volume != 0 then
							-- not empty
							empty = false
							break
						end
					end
					
					if empty then
						-- empty found function
						searchNb = nb
						break
					end
				end
				
				-- if found copy data to sfx-position
				if searchNb then
					activePico:PokeHex( activePico:SFXAdr(searchNb), sfxHex)
					PicoRemoteWrite(Pico.SFX + searchNb * 68, 68, activePico:SFXAdr(searchNb))
					-- empty name, since it has changed
					activePico:SaveDataSet("SFXname", searchNb, "")
				end
			end
			
			-- store translation-table for music-voices
			trans[sfxNb] = searchNb			
		end
	
		-- write music data
		local write = _nb -1
		for i = 0, countMusic - 1 do
			if write < 63 then
				write += 1
				local pos = 10 + (68+1)*2 * countSFX + i*9
				local musicHex = str:sub(pos, pos+8)
				local hi = tonumber( musicHex:sub(-1) ) or 0
				local adr = activePico:MusicAdr( write )
				local a
				-- write voices (with start/stop/loop/unknown flag)
				a = tonumber("0x" .. musicHex:sub(1,2)) or 64
				activePico:Poke(adr + 0, (trans[a & 63] or 0) | (a & 64) | ((hi & 1 != 0) and 128 or 0) )
				a = tonumber("0x" .. musicHex:sub(3,4)) or 64
				activePico:Poke(adr + 1, (trans[a & 63] or 0) | (a & 64) | ((hi & 2 != 0) and 128 or 0) )
				a = tonumber("0x" .. musicHex:sub(5,6)) or 64
				activePico:Poke(adr + 2, (trans[a & 63] or 0) | (a & 64) | ((hi & 4 != 0) and 128 or 0) )
				a = tonumber("0x" .. musicHex:sub(7,8)) or 64
				activePico:Poke(adr + 3, (trans[a & 63] or 0) | (a & 64) | ((hi & 8 != 0) and 128 or 0) )
				-- reset music name
				activePico:SaveDataSet("MusicName", write, "")
				-- update pico-remote
				PicoRemoteWrite(Pico.MUSIC + write * 4, 4, adr)				
			end			
		end
		-- reread
		_MusicRead()
		_nbEnd = write
		-- inform user
		InfoBoxSet(string.format("Pasted %d music pattern and %d sfx pattern.", _nbEnd - _nb + 1, countSFX))
		return true
	
	elseif str:sub(1,6)=="[note]" and str:sub(-7,-1)=="[/note]" and _cursorVoice then
		-- copy notes to voice
		local notes = _sfx[_cursorVoice].notes
		local sfxNb = _music.sfx[_cursorVoice]
	
		-- delete selection
		if _cursorNote != _cursorNoteEnd then
			local start,size = math.min(_cursorNote, _cursorNoteEnd), math.abs(_cursorNote - _cursorNoteEnd)
			for i=0,size do
				table.remove(notes, start)
				table.insert(notes,{pitch = 0, wave = 0, volume = 0, effect = 0})
			end
			_cursorNote = start
			_cursorNoteEnd = start			
			-- writeSFX is below!
		end
		
		local size = math.min(tonumber("0x".. str:sub(7,8)) or 0, 32 - _cursorNote + 1)
		local hex = str:sub(9,-8)
		local sfxadr = activePico:SFXAdr(sfxNb) + (_cursorNote - 1) * 2
		
		
		-- create space
		for i=1,size do
			table.insert(notes, _cursorNote,{pitch = 0, wave = 0, volume = 0, effect = 0})
			table.remove(notes, start)
		end
		_SFXWrite(_cursorVoice)
		
		activePico:PokeHex(sfxadr, hex, size * 2)
		_SFXRead(_cursorVoice) -- Update
		_SFXWrite(_cursorVoice)
		
		_cursorNoteEnd = _cursorNote + size - 1
		return true

	end
	
	InfoBoxSet("Nothing to paste.")
end

-- select all notes / music
function m.SelectAll()
	if _cursorVoice then
		_cursorNote = 1
		_cursorNoteEnd = 32
	else
		_MusicRead(0)
		_nbEnd=63
	end
end

return m
