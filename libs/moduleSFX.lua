--[[
	
	sound-module
	
	basic sound editing


--]]
modules = modules or {}

local m = {
	name = "Sound",
	sort = 40,
}
table.insert(modules, m)


local _VOLUMECOLORINDEX = {[0]=1,13,2,6,12,14,15,7}
local _sfx = {}
local _sfxNb = 0
local _cursorNote = 1
local _cursorNoteEnd = 1
local _cursorColumn = 1
local _notesRect
local _graphDotWidth
local _graphDotHeight
local _graphDotCenter
local _graphRect
local _volumeRect
local _sfxRect
local _sfxEntryWidth
local _sfxEntryHeight
local _mouseLock
local _mouseLockMoved

-- Read SFX from memory and write it to buttons/inputs
local _oldsfxNb = 0
local function _SFXRead(nb)
	_sfxNb =math.clamp(0,63, nb or _sfxNb)
	_sfxNbEnd = _sfxNb
	
	if _sfxNb != _oldsfxNb then
		PicoRemoteSFX(-1)
		_oldsfxNb = _sfxNb
	end
	
	_sfx = activePico:SFXGet(_sfxNb)
	
	m.inputs.sfx.text = string.format("%2i", _sfxNb)
	m.inputs.speed.text = string.format("%3i", _sfx.speed)
	m.inputs.loopStart.text = string.format("%2i", _sfx.loopStart)
	m.inputs.loopEnd.text = string.format("%2i", _sfx.loopEnd)
	m.inputs.name.text = activePico:SaveDataGet("SFXname",_sfxNb) or ""
	m.buttons:SetRadio(m.buttons["noiz" .. _sfx.noiz])
	m.buttons:SetRadio(m.buttons["buzz" .. _sfx.buzz])
	m.buttons:SetRadio(m.buttons["detune" .. _sfx.detune])
	m.buttons:SetRadio(m.buttons["reverb" .. _sfx.reverb])
	m.buttons:SetRadio(m.buttons["dampen" .. _sfx.dampen])		
end

-- read buttons/inputs and write it to memory / transfer memory to pico remote
local function _SFXWrite()
	_sfxNb = math.clamp(0, 63, tonumber(m.inputs.sfx.text) or _sfxNb)

	
	activePico:SaveDataSet("SFXname",_sfxNb,m.inputs.name.text)
	_sfx.speed = math.clamp(0, 255, tonumber(m.inputs.speed.text) or 0)
	_sfx.loopStart = math.clamp(0, 255, tonumber(m.inputs.loopStart.text) or 0)
	_sfx.loopEnd = math.clamp(0, 255, tonumber(m.inputs.loopEnd.text) or 0)
	activePico:SaveDataSet("SFXname",_sfxNb, m.inputs.name.text	)
		
	_sfx.noiz = m.buttons:GetRadio("noiz").index
	_sfx.buzz = m.buttons:GetRadio("buzz").index
	_sfx.detune = m.buttons:GetRadio("detune").index
	_sfx.reverb = m.buttons:GetRadio("reverb").index
	_sfx.dampen = m.buttons:GetRadio("dampen").index
	
	activePico:SFXSet(_sfxNb, _sfx)
	PicoRemoteWrite(Pico.SFX + _sfxNb * 68, 68, activePico:SFXAdr(_sfxNb) )
	_SFXRead(nb) -- update math.clamp - values
end

-- Allow other modules to switch the current sfx (used in moduleMusic)
function m.API_SetSFX(m, nb)
	ModuleActivate(m)
	_SFXRead(nb)
end

-- initalize module
function m.Init(m)
	m.buttons = buttons:CreateContainer()
	m.inputs = inputs:CreateContainer()	
	
	local w2,h2 = SizeText("+",2)
	local w1,h1 = SizeText("-")
	
	-- sfx-settings button - update
	local update = function(b) _SFXWrite() end	
    -- note settings - update
	local updateNote = function(but)
		if SDL.Keyboard.GetModState():hasflag("SHIFT") > 0 then
			-- shift - update selected notes or all
			local s,e = _cursorNote, _cursorNoteEnd
			if _cursorNote == _cursorNoteEnd then
				s,e = 1,32
			end
			if s > e then s,e = e,s end
			for i = s, e do
				if _sfx.notes[i].volume != 0 then 
					if but.radio == "wave" then
						_sfx.notes[i].wave = but.index
					elseif but.radio == "volume" then
						_sfx.notes[i].volume = but.index
					elseif but.radio == "effect" then
						_sfx.notes[i].effect = but.index
					end
				end
			end
			_SFXWrite()
		end	
	end
	
	
	local labelW = 6 * w1 + 10
	local filterW = labelW + 3 * (w1+10) + 3
	local buttonsW = (w1 + 10) * 8 + 7
	
	local inp, b
	
	inp = m.inputs:Add("speed"," Speed","000",filterW)
	inp.OnTextChange = update
	inp.min = 0
	inp.max = 255
	
	inp = m.inputs:Add("loopStart","  Loop","000",filterW)
	inp.OnTextChange = update
	inp.min = 0
	inp.max = 255
	
	inp = m.inputs:Add("loopEnd","   End","000",filterW)
	inp.OnTextChange = update
	inp.min = 0
	inp.max = 255
	
	inp = m.inputs:Add("name","Name:","-",  (w2 * 6 + 3) * 4 + w2 * 3 + 10 )
	inp.OnTextChange = update
	inp.textLimit = 8
	
	m.buttons:AddLabel("lOctave", "Octave", buttonsW,-10)	
	m.buttons:AddLabel("lWave", "Instrument", buttonsW,-10)	
	m.buttons:AddLabel("lVolume", "Volume", buttonsW,-10)	
	m.buttons:AddLabel("lEffect", "Effect", buttonsW,-10)	
	m.buttons:AddLabel("lNoiz", "Noiz", labelW,-10)
	m.buttons:AddLabel("lBuzz", "Buzz", labelW,-10)
	m.buttons:AddLabel("lDetune","Detune",labelW,-10)
	m.buttons:AddLabel("lReverb","Reverb",labelW,-10)
	m.buttons:AddLabel("lDampen","Dampen",labelW,-10)
	
	inp = m.inputs:Add("sfx","","00")
	inp.min = 0
	inp.max = 63
	inp.OnTextChange = function(inp, text)
		_SFXRead(tonumber(text) or 0)
	end
	
	b = m.buttons:Add("sfxLeft","-")
	b.OnClick = function(b)
		if _sfxNb > 0 then
			_sfxNb -= 1
			_SFXRead()
		end
	end
	
	b = m.buttons:Add("sfxRight","+")
	b.OnClick = function(b)
		if _sfxNb < 63 then
			_sfxNb += 1
			_SFXRead()
		end
	end
	
	b = m.buttons:Add("octhidden","0",nil,nil,"octave") -- spacer
	b.visible = false
	for i=0,5 do
		b = m.buttons:Add("oct"..i,i,nil,nil,"octave")
		b.index = i
	end
	
	local effname = {[0]="none", "slide", "vibrato", "drop", "fade in", "fade out", "arpeggio fast", "arpeggio slow"}
	local wavename = {[0]="triangle", "tilted saw", "saw", "square", "pulse", "organ", "noise", "phaser"}
	local wavMax = 0	
	for nb,t in pairs(wavename) do wavMax = math.max(wavMax,#t) end
	local effMax = 0
	for nb,t in pairs(effname) do effMax = math.max(effMax,#t) end
	
	local spacer = string.rep(" ",math.max(wavMax,effMax))
		
	for i=0,7 do
		b = m.buttons:Add("wave"..(i+8),i,nil,nil,"wave")
		b.index = i+8
		b.OnClick = updateNote
		
		b = m.buttons:Add("wave"..i, string.sub(i..":"..wavename[i]..spacer,1,wavMax+2),buttonsW ,nil,"wave", Pico.RGB[8+i],COLBLACK,nil,Pico.RGB[8+i])
		b.index = i
		b.OnClick = updateNote
		
		b = m.buttons:Add("vol"..i,i,nil,nil,"volume", Pico.RGB[ _VOLUMECOLORINDEX[i] ],Pico.RGB[10],nil,Pico.RGB[ _VOLUMECOLORINDEX[i] ])
		b.index = i
		b.OnClick = updateNote
		
		b = m.buttons:Add("eff"..i, string.sub(i..":"..effname[i]..spacer,1,effMax+2),buttonsW,nil,"effect")
		b.index = i	
		b.OnClick = updateNote
	end
		
	for i=0,2 do
		if i < 2 then
			b = m.buttons:Add("noiz"..i,i,nil,nil,"noiz")
			b.index = i			
			b.OnClick = update			
			
			b = m.buttons:Add("buzz"..i,i,nil,nil,"buzz")			
			b.index = i
			b.OnClick = update		
		end
		b = m.buttons:Add("detune"..i,i,nil,nil,"detune")
		b.index = i
		b.OnClick = update		
		
		b = m.buttons:Add("reverb"..i,i,nil,nil,"reverb")
		b.index = i
		b.OnClick = update		
		
		b = m.buttons:Add("dampen"..i,i,nil,nil,"dampen")
		b.index = i
		b.OnClick = update		
	end
	
	
	m.buttons:SetRadio(m.buttons.oct2)
	m.buttons:SetRadio(m.buttons.wave0)
	m.buttons:SetRadio(m.buttons.vol5)
	m.buttons:SetRadio(m.buttons.eff0)

	if config.showSFXnames == nil then config.showSFXnames = true end
	if config.showSFXmusic == nil then config.showSFXmusic = true end
	
	b = m.buttons:Add("showSFXnames","Name",100,nil, "TOOGLE")
	b.OnClick = function(b) config.showSFXnames = b.selected end
	
	b = m.buttons:Add("showSFXmusic","Music",100,nil, "TOOGLE")
	b.OnClick = function(b) config.showSFXmusic = b.selected end

	b = m.buttons:AddHex("SFXPos","Pos:",0,100,nil,Pico.SFXPOS)
	b.hexFilter = 0xff08
	return true
end

-- resize all elemets and position it / transfer memory to pico remote
function m.Resize(m)
	local ow, oh = renderer:GetOutputSize()
	local w2,h2 = SizeText("+",2)	
	
	local l
	
	_sfxEntryWidth = 64
	_sfxEntryHeight = 64
	_sfxRect = { x = 5 + (ow - MINWIDTH) \ 2, y = topLimit, w = 8 * _sfxEntryWidth + 7 + 2, h = 8 * _sfxEntryHeight + 7 + 2}
	_sfxRect.y += (oh - _sfxRect.y - _sfxRect.h) \ 2
	
	m.buttons.showSFXnames:SetPos(_sfxRect.x, _sfxRect.y + _sfxRect.h + 10)
	m.buttons.showSFXmusic:SetRight()	
	m.buttons.showSFXnames.selected = config.showSFXnames
	m.buttons.showSFXmusic.selected = config.showSFXmusic
	
	l = m.buttons.sfxLeft:SetPos( _sfxRect.x + _sfxRect.w + 15, topLimit + (oh-MINHEIGHT) \ 2)
	m.inputs.sfx:SetRight(1)
	m.buttons.sfxRight:SetRight(1)
	
	--
	
	l = m.inputs.speed:SetDown(l)
	l = m.inputs.loopStart:SetDown(5)
	l = m.inputs.loopEnd:SetDown(1)
		
	l = m.buttons.lNoiz:SetDown(l)
	m.buttons.noiz0:SetRight(1)
	m.buttons.noiz1:SetRight(1)
	
	l = m.buttons.lBuzz:SetDown(l)
	m.buttons.buzz0:SetRight(1)
	m.buttons.buzz1:SetRight(1)
	
	l = m.buttons.lDetune:SetDown(l)
	m.buttons.detune0:SetRight(1)
	m.buttons.detune1:SetRight(1)
	m.buttons.detune2:SetRight(1)
	
	l = m.buttons.lReverb:SetDown(l)
	m.buttons.reverb0:SetRight(1)
	m.buttons.reverb1:SetRight(1)
	m.buttons.reverb2:SetRight(1)
	
	l = m.buttons.lDampen:SetDown(l)
	m.buttons.dampen0:SetRight(1)
	m.buttons.dampen1:SetRight(1)
	m.buttons.dampen2:SetRight(1)
	
	--
		
	m.buttons.lOctave:SetPos(m.inputs.speed.rectBack.x + m.inputs.speed.rectBack.w + 10, topLimit + (oh-MINHEIGHT)\2)
	l = m.buttons["octhidden"]:SetDown(1)
	for i=0,5 do
		m.buttons["oct"..i]:SetRight(1)
	end
	
	--
	
	m.buttons.lWave:SetDown(l)
	for i=0,7 do		
		m.buttons["wave"..i]:SetDown(1)
	end
	l = m.buttons["wave8"]:SetDown(1)
	for i=1,7 do
		m.buttons["wave"..(i+8)]:SetRight(1)
	end
	
	--
	
	m.buttons.lVolume:SetDown(l)
	l = m.buttons["vol0"]:SetDown(1)
	for i=1,7 do 
		m.buttons["vol"..i]:SetRight(1)
	end
	
	--
	
	m.buttons.lEffect:SetDown(l)
	for i=0,7 do
		m.buttons["eff"..i]:SetDown(1)		
	end
	
	--
	
		
	m.inputs.name:SetPos(m.buttons["vol7"].rectBack.x + m.buttons["vol7"].rectBack.w + 10, topLimit + (oh-MINHEIGHT)\2)

	_notesRect = {x = m.inputs.name.rectBack.x, y = m.inputs.name.rectBack.y + m.inputs.name.rectBack.h, w = (w2 * 6 + 3) * 4 + w2 * 3 + 10, h = h2 * 8 + 10}
		
	_graphDotHeight = 5
	_graphRect = {x = _notesRect.x, y = _notesRect.y + _notesRect.h + 15, w = _notesRect.w \ 32 * 32 + 10, h = 64 * _graphDotHeight + 10}
	_graphRect.x += (_notesRect.w - _graphRect.w) \ 2 -- center graph under note
	_graphDotWidth = (_graphRect.w - 10)\32
	_graphDotCenter = (_graphDotWidth - _graphDotHeight)\2 -- width is smaller - need this to center it the dot/bar
	
	_volumeRect = {x = _graphRect.x, y = _graphRect.y + _graphRect.h + 5, w = _graphRect.w, h = 8 * _graphDotHeight + 10}
	
	
	m.buttons.SFXPos:SetPos(ow - m.buttons.SFXPos.rectBack.w - 5,topLimit)
	
	_SFXRead()
	PicoRemoteSFX(-1)
	PicoRemoteMusic(-1)
	PicoRemoteWrite(Pico.MUSIC,Pico.MUSICLEN, activePico:MusicAdr()) -- complete music/sfx - data
	PicoRemoteWrite(Pico.SFX,Pico.SFXLEN,activePico:SFXAdr())
end

-- take over control
function m.FocusGained(m)
	m:Resize()
	_mouseLock = nil
end

-- and lost it
function m.FocusLost(m)
	PicoRemoteSFX(-1)
	PicoRemoteMusic(-1)
	_SFXWrite()
end

-- return background and cursor rect of a note/column
local function _GetNoteRects(note,col)
	local w2,h2 = SizeText("+",2)
	-- complete background rect
	local t = {}
	t.w = w2 * 6 + 3
	t.h = h2
	t.x = _notesRect.x + ((note - 1) \ 8) * (t.w + w2) + 5
	t.y = _notesRect.y + ((note -1) % 8) * t.h + 5

	-- cursor background rect
	local t2 = { x = t.x, y = t.y, w = t.w, h = h2}

	if col == 1 then
		t2.x = t.x
		t2.w = w2 * 2
	elseif col == 2 then
		t2.x = t.x + w2 * 2
		t2.w = w2
	elseif col == 3 then
		t2.x = t.x +  w2 * 3 + 1
		t2.w = w2
	elseif col == 4 then
		t2.x = t.x +  w2 * 4 + 2
		t2.w = w2
	elseif col == 5 then
		t2.x = t.x +  w2 * 5 + 3
		t2.w = w2
	end
	return t,t2
end

-- return note and column of a position
local function _GetNoteNbColumn(x,y)
	local w2,h2 = SizeText("+",2)
	local w = w2 * 6 + 3 + w2
	local tx,ty = (x - 5 - _notesRect.x) \ w, (y - 5 - _notesRect.y) \ h2
	
	-- inside notes block?
	if tx >= 0 and tx <= 3 and ty >= 0 and ty <= 7 then
		local note = ty + tx * 8 +1
		local xx = x - tx * w - 5 - _notesRect.x
		if     xx < w2 * 2 then
			return note, 1
		elseif xx < w2 * 3 + 1 then
			return note, 2
		elseif xx < w2 * 4 + 2 then
			return note, 3
		elseif xx < w2 * 5 + 3 then
			return note, 4
		elseif xx < w2 * 6 + 4 then 
			return note, 5
		end
	end
	
	return nil,nil
end

-- draw everything
function m.Draw(m, mx, my)
	local w2,h2 = SizeText("+",2)
	local w1,h1 = SizeText("+")

	-- which sfx is played and which note
	local mus,pat,s1,s2,s3,s4,t1,t2,t3,t4 = PicoRemoteStatus()	
	local played = { [s1]=t1, [s2]=t2, [s3]=t3, [s4]=t4 }

	-- build a list with all used sfx	
	local sfxUsedIn = {}
	for i = 0, 63 do
		sfxUsedIn[i] = {}
	end
	for i=0,63 do
		local t = activePico:MusicGet(i)
		for a = 1, 4 do
			if not t.disabled[a] then 
				table.insert(sfxUsedIn[t.sfx[a]], i) 
			end
		end
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
			col = (math.clamp(i,_sfxNb,_sfxNbEnd) != i) and COLBLACK or Pico.RGB[2]
		elseif #sfxUsedIn[i] > 0 then
			col = (math.clamp(i,_sfxNb,_sfxNbEnd) != i) and COLDARKGREY or Pico.RGB[2]
		else
			col = (math.clamp(i,_sfxNb,_sfxNbEnd) != i) and COLGREY or Pico.RGB[4]
		end			
		DrawFilledRect(rect, col ,nil, true)
		
		-- draw is playing bar
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
	
	-- notes --

	local y,x = _notesRect.y, _notesRect.x
	local xx,yy,w
		
	-- background
	DrawFilledRect(_notesRect, COLBLACK)
	
	-- draw cursor / Selection (when no input has it)
	if not m.inputs:HasFocus() and _sfxNbEnd == _sfxNb then
		if _cursorNote != _cursorNoteEnd then
			-- draw a selection
			local s,e = _cursorNote, _cursorNoteEnd
			if s > e then s,e = e,s end
			for i = s, e do
				local t1 = _GetNoteRects(i)
				DrawFilledRect(t1, Pico.RGB[2])
			end
			-- draw cursor
			local t1,t2 = _GetNoteRects(_cursorNote, _cursorColumn)			
			DrawFilledRect(t2, Pico.RGB[8])
		else
			-- draw background of the current note and cursor
			local t1,t2 = _GetNoteRects(_cursorNote, _cursorColumn)
			DrawFilledRect(t1, Pico.RGB[1])
			DrawFilledRect(t2, Pico.RGB[8])
		end		
	end
	
	-- highlight current played note
	if played[ _sfxNb ] and played[ _sfxNb ] < 32 then		
		local t1,t2 = _GetNoteRects(played[ _sfxNb ] + 1)
		DrawFilledRect(t1, Pico.RGB[5])
	end
	
	-- draw loop start
	if _sfx.loopStart != _sfx.loopEnd and _sfx.loopStart < 33 then
		local rect = _GetNoteRects(_sfx.loopStart+1)
		rect.y -= 1
		rect.h = 2
		DrawFilledRect(rect, Pico.RGB[13])
	end

	-- draw loop end
	if _sfx.loopStart < _sfx.loopEnd and _sfx.loopEnd < 33 then
		local rect = _GetNoteRects(_sfx.loopEnd)
		rect.y += rect.h - 1
		rect.h = 2
		DrawFilledRect(rect, Pico.RGB[13])
	end
		
	-- draw all notes
	for nb,note in pairs(_sfx.notes) do
		local t1 = _GetNoteRects(nb)
		local xx,y = t1.x, t1.y
			
		if note.volume > 0 then 			
			xx = DrawText(xx,y,Pico.NOTENAME[ (note.pitch % #Pico.NOTENAME) +1],Pico.RGB[7], 2)		
			xx = DrawText(xx,y, note.pitch \ #Pico.NOTENAME,Pico.RGB[6], 2)
			xx = DrawText(xx+1,y, note.wave % 8, Pico.RGB[ (note.wave > 7) and 11 or 14 ] , 2)
			xx = DrawText(xx+1,y, note.volume, Pico.RGB[12], 2)
			xx = DrawText(xx+1,y, note.effect > 0 and note.effect or ".", Pico.RGB[13], 2)
		else
			if note.alwaysVisible then
				xx = DrawText(xx,y,Pico.NOTENAME[ (note.pitch % #Pico.NOTENAME) +1],Pico.RGB[1], 2)		
				xx = DrawText(xx,y, note.pitch \ #Pico.NOTENAME,Pico.RGB[1], 2)
				xx = DrawText(xx+1,y, note.volume > 0 and (note.wave % 8) or ".", Pico.RGB[ (note.wave > 7) and 2 or 1 ] , 2)
				xx = DrawText(xx+1,y, note.volume > 0 and note.volume or ".", Pico.RGB[1], 2)
				xx = DrawText(xx+1,y, note.effect > 0 and note.effect or ".", Pico.RGB[1], 2)
			else			
				xx = DrawText(xx,y,"...",Pico.RGB[1],2)
				xx = DrawText(xx+1,y,".",Pico.RGB[1],2)
				xx = DrawText(xx+1,y,".",Pico.RGB[1],2)
				xx = DrawText(xx+1,y,".",Pico.RGB[1],2)
			end
		end
			
	end
	
	-- draw graph --
	
	local offx,offy = _graphRect.x + 5,  _graphRect.y + 5		
	-- background
	DrawFilledRect(_graphRect, COLBLACK)
	
	-- draw start loop
	if _sfx.loopStart != _sfx.loopEnd and _sfx.loopStart < 33 then
		local xx,yy = (_sfx.loopStart ) * _graphDotWidth + offx - _graphDotCenter\2, offy
		DrawFilledRect({xx, yy, _graphDotCenter, _graphDotHeight * 64}, Pico.RGB[13])
	end

	-- draw end loop
	if _sfx.loopStart < _sfx.loopEnd and _sfx.loopEnd < 33 then
		local xx,yy = (_sfx.loopEnd ) * _graphDotWidth + offx - _graphDotCenter\2, offy
		DrawFilledRect({xx, yy, _graphDotCenter, _graphDotHeight * 64}, Pico.RGB[13])
	end

	-- draw bars
	for nb,note in pairs(_sfx.notes) do
		if note.volume > 0 then
			local xx,yy = (nb - 1) * _graphDotWidth + offx , (63 - note.pitch) * _graphDotHeight + offy
			-- draw head
			DrawFilledRect({xx + _graphDotCenter, yy, _graphDotWidth - _graphDotCenter * 2, _graphDotHeight}, Pico.RGB[ note.wave >7 and 3 or (note.wave + 8) ])
			-- draw tail
			DrawFilledRect({xx + _graphDotCenter, yy + _graphDotHeight, _graphDotWidth - _graphDotCenter * 2, note.pitch * _graphDotHeight}, 
				Pico.RGB[ (played[ _sfxNb ] == nb - 1) and 5 or (math.clamp(nb,_cursorNote,_cursorNoteEnd)==nb and 2 or 1)])
		end
	end
	
	-- volume --
	
	local offx,offy = _volumeRect.x + 5,  _volumeRect.y + 5
	DrawFilledRect(_volumeRect, COLBLACK)
	
	for nb, note in pairs(_sfx.notes) do
		local xx,yy = (nb - 1) * _graphDotWidth + offx , (7 - note.volume) * _graphDotHeight + offy
		DrawFilledRect({xx + _graphDotCenter, yy, _graphDotWidth - _graphDotCenter * 2, _graphDotHeight}, Pico.RGB[ _VOLUMECOLORINDEX[note.volume] ])
	end
	

end

-- convert sym to number
local _NUMKEY = { ["1"]=1, ["2"]=2, ["3"]=3, ["4"]=4, ["5"]=5, ["6"]=6, ["7"]=7, ["8"]=8, ["9"]=9, ["0"]=0,
				 KP_1=1, KP_2=2, KP_3=3, KP_4=4, KP_5=5, KP_6=6, KP_7=7, KP_8=8, KP_9=9, KP_0=0}

-- change pitch in selection or all
local function _transposing(scan)
	local f = string.find("ZSXDCVGBHNJMQ2W3ER5T6Y7UI9O0P",scan) 
	if f then
		local s,e = _cursorNote, _cursorNoteEnd
		if s > e then s,e = e,s end
		if s == e then s,e = 1,32 end
		for i = s, e do
			_sfx.notes[i].pitch = math.clamp (_sfx.notes[i].pitch + f - 13,0,63)
		end
		_SFXWrite()
		InfoBoxSet(string.format("Transposing %d.", f-13))
	end
end

-- keyboard-action
function m.KeyDown(m, sym, scan, mod)
	if mod:hasflag("CTRL ALT GUI") > 0 or _mouseLock then return nil end
	
	local oldNote = _cursorNote
	
	if mod:hasflag("SHIFT") > 0 then
		-- select, only change note, not noteEnd
		if scan == "UP" then
			_cursorNote -= 1
		elseif scan == "DOWN" then
			_cursorNote += 1
		elseif scan == "LEFT" then
			_cursorNote -= 8
		elseif scan == "RIGHT" then
			_cursorNote += 8
		end
	else
		-- move - change both
		if scan == "UP" then
			_cursorNote -= 1
			_cursorNoteEnd = _cursorNote
		elseif scan == "DOWN" then
			_cursorNote += 1
			_cursorNoteEnd = _cursorNote
		elseif scan == "LEFT" then
			_cursorColumn -= 1
			_cursorNoteEnd = _cursorNote
		elseif scan == "RIGHT" then
			_cursorColumn += 1
			_cursorNoteEnd = _cursorNote
		end
	end

	if scan == "ESCAPE" then
		if _sfxNbEnd != _sfxNb then
			-- remove sfx-selection
			_sfxNbEnd = _sfxNb
		else
			-- remove note selection
			_cursorNoteEnd = _cursorNote
		end
	
	elseif scan == "SPACE" then
		local mus,pat,s1,s2,s3,s4,t1,t2,t3,t4 = PicoRemoteStatus()
		
		if mus or s1 != -1 then
			-- stop playing
			PicoRemoteSFX( -1 )		
			PicoRemoteMusic( -1 )
		else
			if _cursorNote == _cursorNoteEnd then
				-- play complete sfx
				PicoRemoteSFX( _sfxNb )
			else
				-- play only selection
				PicoRemoteSFX( _sfxNb, _cursorNote - 1, _cursorNoteEnd - 1 )
			end
		end
	
	elseif scan == "KP_MINUS" or sym == "MINUS" then
		-- previous sfx
		if _sfxNb > 0 then
			_sfxNb -= 1
			_SFXRead()
		end
	elseif scan == "KP_PLUS" or sym == "PLUS" then
		-- next sfx
		if _sfxNb < 63 then
			_sfxNb += 1
			_SFXRead()
		end
	end
	
	
	if _sfxNbEnd == _sfxNb then
		-- no selection in the sfx
	
		local f = _NUMKEY[sym]
		local f2 = string.find("ZSXDCVGBHNJMQ2W3ER5T6Y7UI",scan) 
		local sfxNotes = _sfx.notes
		local note = sfxNotes[ _cursorNote ]
		--print (_cursorNote == _cursorNoteEnd,_cursorNote, _cursorNoteEnd,mod:hasflag("SHIFT"))
		if _cursorNote == _cursorNoteEnd then
				
			if mod:hasflag("SHIFT")>0 then 			
				if _cursorColumn == 3 and f and f <= 7 then	
					-- alternate instrument / wave
					f += 8
					note.wave = f
					_SFXWrite()
					_cursorNote += 1
					_cursorNoteEnd = _cursorNote
				else 
					_transposing(scan)
				end
							
			elseif _cursorColumn == 1 and f2  then
				-- enter note
				local o
				if note.volume == 0 then
					note.volume = m.buttons:GetRadio("volume").index
					note.wave = m.buttons:GetRadio("wave").index
					note.effect = m.buttons:GetRadio("effect").index
					o = m.buttons:GetRadio("octave").index
				else
					o = note.pitch \ 12
				end	
				
				note.pitch = math.clamp(0, 63, f2 - 13 + o * 12)			
				_SFXWrite()
				PicoRemoteSFX( _sfxNb, _cursorNote - 1, _cursorNote - 1)
				
				_cursorNote += 1
				_cursorNoteEnd = _cursorNote

			elseif f then
				
				if _cursorColumn == 2 and f <= 5 then 
					-- octave		
					note.pitch = math.clamp(0,63, (note.pitch % 12) + f * 12)
					_SFXWrite()
					_cursorNote += 1
					_cursorNoteEnd = _cursorNote
				
				elseif _cursorColumn == 3 and f <= 7 then	
					-- wave / instrument
					note.wave = f
					_SFXWrite()
					_cursorNote += 1
					_cursorNoteEnd = _cursorNote
			
				elseif _cursorColumn == 4 and f <= 7 then
					-- volume
					note.volume = f
					_SFXWrite()
					_cursorNote += 1
					_cursorNoteEnd = _cursorNote
			
				elseif _cursorColumn == 5 and f <= 7 then
					-- effect
					note.effect = f
					_SFXWrite()
					_cursorNote += 1
					_cursorNoteEnd = _cursorNote				
				end
		
			elseif sym == "BACKSPACE" then
				if _cursorNote > 1 then
					-- remove on entry
					table.remove(_sfx.notes, _cursorNote -1)
					table.insert(_sfx.notes,{pitch = 0, wave = 0, volume = 0, effect = 0}) -- fill the gap
					_SFXWrite()
					_cursorNote -= 1
					_cursorNoteEnd = _cursorNote
				end
				
			elseif sym == "DELETE" and _sfxNb == _sfxNbEnd then
				-- remove entry
				table.remove(_sfx.notes, _cursorNote)
				table.insert(_sfx.notes,{pitch = 0, wave = 0, volume = 0, effect = 0}) -- fill the gap
				_SFXWrite()
			
			elseif sym == "RETURN" or sym == "KP_ENTER" then
				-- insert an entry
				table.insert(_sfx.notes, _cursorNote, {pitch = 0, wave = 0, volume = 0, effect = 0})
				table.remove(_sfx.notes) -- remove the last overlapping
				_SFXWrite()
				_cursorNote += 1
				_cursorNoteEnd = _cursorNote
			
			end
		else
		
			if mod:hasflag("SHIFT")>0 then 
				-- transposing scan
				_transposing(scan)
				
			elseif scan == "BACKSPACE" or (scan == "DELETE" and _sfxNb == _sfxNbEnd) then
				-- remove selection
				local start,size = math.min(_cursorNote, _cursorNoteEnd), math.abs(_cursorNote - _cursorNoteEnd)
				for i=0, size do
					table.remove(_sfx.notes, start)
					table.insert(_sfx.notes, {pitch = 0, wave = 0, volume = 0, effect = 0})
				end
				_cursorNote = start
				_cursorNoteEnd = start
				_SFXWrite()
			end
		end
	else
		-- more than one SFX is selected
		if scan == "DELETE" then
			local s,e = _sfxNb, _sfxNbEnd
			if s>e then s,e = e,s end
						
			for i = s, e do
				activePico:MemorySet( activePico:SFXAdr(i), 0, 68)
				PicoRemoteWrite(Pico.SFX + i * 68, 68, activePico:SFXAdr(i))
			end	
			
			_SFXRead(s)
			_sfxNbEnd = e		
		end
		
	end
	
	-- column - overlapping	-> note column switch
	while _cursorColumn < 1 do
		_cursorNote -= 8
		_cursorNoteEnd = _cursorNote
		_cursorColumn += 5
	end
	while _cursorColumn > 5 do
		_cursorNote += 8
		_cursorNoteEnd = _cursorNote
		_cursorColumn -= 5
	end
	-- limit cursor
	_cursorNote = math.rotate(_cursorNote, 1, 32)
	_cursorNoteEnd = math.rotate(_cursorNoteEnd, 1, 32)
	
	-- on cursor move reset selected sfx
	if oldNote != _cursorNote then	
		_sfxNbEnd = _sfxNb
	end			
end

-- return click on x,y in graph a note and pitch
function _GetGraphNotePitch(mx,my)	
	local nb = (mx - _graphRect.x - 5) \ _graphDotWidth + 1
	local pitch = 63 - (my - _graphRect.y - 5) \ _graphDotHeight 	
	if nb >= 1 and nb <= 32 and pitch >= 0 and pitch <= 63 then
		return nb,pitch
	end
	return nil,nil
end

-- return click on x,y in volume note and volume
function _GetGraphNoteVolume(mx,my)
	local nb = (mx - _volumeRect.x - 5) \ _graphDotWidth + 1
	local volume = 7 - (my - _volumeRect.y - 5) \ _graphDotHeight 	
	if nb >= 1 and nb <= 32 and volume >= 0 and volume <= 7 then
		return nb,volume
	end
	return nil,nil
end

-- button pressed
function m.MouseDown(m, mx, my, mb, mbclicks)

	if _mouseLock != nil then return end
	
	if mb == "LEFT" then
		-- select a sfx
		local x = (mx - _sfxRect.x - 1) \ (_sfxEntryWidth + 1)
		local y = (my - _sfxRect.y - 1) \ (_sfxEntryHeight + 1)
		if x >= 0 and x <= 7 and y >= 0 and y <= 7 then
			if  SDL.Keyboard.GetModState():hasflag("CTRL") == 0 then
				if  SDL.Keyboard.GetModState():hasflag("SHIFT") == 0 then
					-- normal - select
					_SFXRead(x + y * 8)
					_mouseLock = "selectSFX"
					return true
				else
					-- shift - select endpoint
					_sfxNbEnd = x + y * 8					
					return true
				end
			else
				-- ctrl-click exchange 
				local start,size = math.min(_sfxNb, _sfxNbEnd), math.abs(_sfxNb - _sfxNbEnd) + 1
				
				for s = 0, size -1 do 
					local s1,s2 = x + y * 8 + s, _sfxNb + s
					if s1 != s2 then					
						if  SDL.Keyboard.GetModState():hasflag("SHIFT") == 0 then
							-- music pattern correction
							for i = 0, 63 do
								local mu = activePico:MusicGet(i)
								for a = 1, 4 do
									if mu.sfx[a] == s1 then
										mu.sfx[a] = s2
									elseif mu.sfx[a] == s2 then
										mu.sfx[a] = s1
									end
								end
								activePico:MusicSet(i, mu)
							end
						end
						-- swap sfx
						local h1 = activePico:PeekHex(activePico:SFXAdr(s1), 68)
						local h2 = activePico:PeekHex(activePico:SFXAdr(s2), 68)
						activePico:PokeHex(activePico:SFXAdr(s1), h2)
						activePico:PokeHex(activePico:SFXAdr(s2), h1)
						PicoRemoteWrite(Pico.SFX + s1 * 68, 68,activePico:SFXAdr(s1))
						PicoRemoteWrite(Pico.SFX + s2 * 68, 68,activePico:SFXAdr(s2))
						-- swap name
						local n1 = activePico:SaveDataGet("SFXname", s1)
						local n2 = activePico:SaveDataGet("SFXname", s2)
						activePico:SaveDataSet("SFXname", s1, n2)
						activePico:SaveDataSet("SFXname", s2, n1)
					end
				end
				PicoRemoteWrite(Pico.MUSIC, Pico.MUSICLEN, activePico:MusicAdr())
				_SFXRead(x + y * 8)
				_sfxNbEnd = _sfxNb + size - 1
			
			end
		end
	end
	
	-- Select a note
	local note,col = _GetNoteNbColumn(mx,my)	
	if note != nil and col != nil then
		_sfxNbEnd = _sfxNb
		if mb == "LEFT" then
			if  SDL.Keyboard.GetModState():hasflag("SHIFT") == 0 then
				-- select note and start selecting
				_cursorNote = note
				_cursorNoteEnd = note
				_cursorColumn = col
				_mouseLock = "selectNotes"
			else
				-- shift-click - place only start
				_cursorNote = note
				_cursorColumn = col
			end
			return true
			
		elseif mb == "RIGHT" then
			-- grab octave/wave/volume/effect from a note
			if col == 2 then
				m.buttons:SetRadio(m.buttons["oct".. _sfx.notes[note].pitch \ 12])
			elseif col == 3 then
				m.buttons:SetRadio(m.buttons["wave".. _sfx.notes[note].wave ])
			elseif col == 4 then
				m.buttons:SetRadio(m.buttons["vol".. _sfx.notes[note].volume ])			
			elseif col == 5 then
				m.buttons:SetRadio(m.buttons["eff".. _sfx.notes[note].effect ])			
			end
			return true					
		end
	
	end
	
	-- click on graph
	local note, pitch = _GetGraphNotePitch(mx,my)
	if note and pitch then
		_sfxNbEnd = _sfxNb
		if mb == "LEFT" then			
			if _sfx.notes[note].pitch != pitch then
				-- change pitch und use selected volume/wave/effect
				_sfx.notes[note].pitch = pitch 
				_sfx.notes[note].volume = _sfx.notes[note].volume > 0 and _sfx.notes[note].volume or m.buttons:GetRadio("volume").index
				_sfx.notes[note].effect = m.buttons:GetRadio("effect").index
				_sfx.notes[note].wave = m.buttons:GetRadio("wave").index
				_cursorNote = note
				_cursorNoteEnd = note
				_SFXWrite()
			end
			_mouseLock = "graph"
			return true
			
		elseif mb == "RIGHT" then
			-- select graph or grab settings
			_cursorNote = note
			_cursorNoteEnd = note
			_cursorColumn = 1
			_mouseLock = "selectGraph"	
			_mouseLockMoved = false
			return true
			
		end
	end
	
	local note, volume = _GetGraphNoteVolume(mx,my)
	if note and volume then
		_sfxNbEnd = _sfxNb
		if mb == "LEFT" then
			if _sfx.notes[note].volume != volume then
				-- change volume
				_sfx.notes[note].volume = volume
				_cursorNote = note
				_cursorNoteEnd = note
				_SFXWrite()			
			end
			_mouseLock = "graphVolume"
			return true
			
		end
	end

end

-- mouse move
function m.MouseMove(m, mx, my, mb)
	
	if _mouseLock == "selectSFX" then
		local x = (mx - _sfxRect.x - 1) \ (_sfxEntryWidth + 1)
		local y = (my - _sfxRect.y - 1) \ (_sfxEntryHeight + 1)
		if x >= 0 and x <= 7 and y >= 0 and y <= 7 then
			_sfxNbEnd = y * 8 + x
		
		end
	end
	
	if _mouseLock == "selectNotes" then
		-- set selection start
		local note,col = _GetNoteNbColumn(mx,my)	
		if note != nil and col != nil then
			_cursorNote = note
			_cursorColumn = col
		end
	
	end

	if _mouseLock == "graph" then
		local note, pitch = _GetGraphNotePitch(mx,my)
		if note and pitch then
			if _sfx.notes[note].pitch != pitch then
				-- drawing in graph
				_sfx.notes[note].pitch = pitch 
				_sfx.notes[note].volume = _sfx.notes[note].volume > 0 and _sfx.notes[note].volume or m.buttons:GetRadio("volume").index
				_sfx.notes[note].effect = m.buttons:GetRadio("effect").index
				_sfx.notes[note].wave = m.buttons:GetRadio("wave").index
				_SFXWrite()
				_cursorNote = note
				_cursorNoteEnd = note
			end			
		end
	end
	
	if _mouseLock == "selectGraph" then
		local note, pitch = _GetGraphNotePitch(mx,my)
		if note and pitch then
			if _cursorNote != note then 	
				-- set selection start and remember, that mouse has moved
				_cursorNote = note
				_mouseLockMoved = true
			end
		end
	end
	
	if _mouseLock == "graphVolume" then
		local note, volume = _GetGraphNoteVolume(mx,my)
		if note and volume then
			if _sfx.notes[note].volume != volume then
				-- set volume
				_sfx.notes[note].volume = volume
				_cursorNote = note
				_cursorNoteEnd = note
				_SFXWrite()			
			end
		end
	end

end

-- release a button
function m.MouseUp(m, mx,my,mb, mbclicks)
	if _mouseLock == "selectSFX" and mb == "LEFT" then
		_mouseLock = nil
	end
	if _mouseLock == "selectNotes" and mb == "LEFT" then
		_mouseLock = nil
	end
	if _mouseLock == "graph" and mb == "LEFT" then
		_mouseLock = nil
	end
	if _mouseLock == "selectGraph" and mb == "RIGHT" then
		if not _mouseLockMoved then
			-- when not moved, grob settings
			m.buttons:SetRadio(m.buttons["oct".._sfx.notes[_cursorNote].pitch\12])
			m.buttons:SetRadio(m.buttons["vol".._sfx.notes[_cursorNote].volume])
			m.buttons:SetRadio(m.buttons["eff".._sfx.notes[_cursorNote].effect])
			m.buttons:SetRadio(m.buttons["wave".._sfx.notes[_cursorNote].wave])	
		end
		_mouseLock = nil
	end
	if _mouseLock == "graphVolume" and mb == "LEFT" then
		_mouseLock = nil
	end
end

-- Clipboard action
function m.Copy(m)
	if _sfxNb != _sfxNbEnd or _cursorNote == _cursorNoteEnd then
		-- copy sfx
		local start,size = math.min(_sfxNb, _sfxNbEnd), math.abs(_sfxNb - _sfxNbEnd) + 1
		local str = string.format("[sfx]%02x00", size)
		for i=0, size-1 do
			str ..= string.format("%02x%s", i, activePico:PeekHex(activePico:SFXAdr(start + i) , 68) )
		end
		str ..="[/sfx]"
		InfoBoxSet(string.format("Copied %d sfx.", size))
		return str
	else
		-- copy notes
		local start,size = math.min(_cursorNote, _cursorNoteEnd), math.abs(_cursorNote - _cursorNoteEnd) + 1
		InfoBoxSet(string.format("Copied %d note(s).", size))
		return "[note]" .. string.format("%02x",size).. activePico:PeekHex(activePico:SFXAdr(_sfxNb) + (start - 1) * 2, size * 2).."[/note]"
	end
	return nil
end

-- Paste action
function m.Paste(m,str)
	if str:sub(1,5)=="[sfx]" and str:sub(-6,-1)=="[/sfx]" then
		
		local countSFX = tonumber("0x".. str:sub(6,7)) or 0
					
		local write = _sfxNb
		for i = 0, countSFX - 1 do
			local pos = 10 + (68+1)*2 * i
			if write < 64 then
				activePico:PokeHex(activePico:SFXAdr(write), str:sub(pos+2,pos+2+68*2-1))
				PicoRemoteWrite(Pico.SFX + write * 68, 68, activePico:SFXAdr(write))
				activePico:SaveDataSet("SFXname", write, "")
				write += 1
			end
		end				
		
	
		InfoBoxSet(string.format("Pasted %d sfx pattern.", write - _sfxNb)) -- +1 is already in write
		_SFXRead()
		_sfxNbEnd = write-1
		return true
		
		

	elseif str:sub(1,6)=="[note]" and str:sub(-7,-1)=="[/note]" then
		-- delete selection
		if _cursorNote != _cursorNoteEnd then
			local start,size = math.min(_cursorNote, _cursorNoteEnd), math.abs(_cursorNote - _cursorNoteEnd)
			for i=0,size do
				table.remove(_sfx.notes, start)
				table.insert(_sfx.notes,{pitch = 0, wave = 0, volume = 0, effect = 0})
			end
			_cursorNote = start
			_cursorNoteEnd = start			
			-- writeSFX is below!
		end
		
		local size = math.min(tonumber("0x".. str:sub(7,8)) or 0, 32 - _cursorNote + 1)
		local hex = str:sub(9,-8)
		local sfxadr = activePico:SFXAdr(_sfxNb) + (_cursorNote - 1) * 2
		
		
		-- create space
		for i=1,size do
			table.insert(_sfx.notes,_cursorNote,{pitch = 0, wave = 0, volume = 0, effect = 0})
			table.remove(_sfx.notes, start)
		end
		_SFXWrite()
		
		activePico:PokeHex(sfxadr, hex, size * 2)
		_SFXRead() -- update
		_SFXWrite()
		
		_cursorNoteEnd = _cursorNote + size - 1
		return 
		
	end
end

-- select all notes
function m.SelectAll(m)
	_cursorNote = 1
	_cursorNoteEnd = 32
end


return m