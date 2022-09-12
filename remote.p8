pico-8 cartridge // http://www.pico-8.com
version 36
__lua__

extcmd("set_title","remote - don't close!")

function send(str)
 str..="\n"
 poke(0x4300,ord(str,1,#str))
	serial(0x805,0x4300,#str)
end

function status()
	ret = "!".. tostr(stat(57))
	for i=46,54 do
		ret ..=", "..tostr(stat(i))
	end				
	ret ..="\n"
	--print("send ".. #ret)	
	if ret != oldret then
		send(ret)
		oldret=ret

 end
 return ret
end


send"start\n"

str = ""
adr = 0
hb=0
info = ""
while true do
	poke(0x4300,0)
	serial(0x804,0x4300,1)
	c=peek(0x4300)
	if c>0  then
		if c == 10 then
			if str == "." then
				send(".\n")
		  ret = status()				
				cls()
				print("heartbeat:".. hb)
				print(tostr(stat(57)).." "..stat(54))
			 print(stat(46).." "..stat(47).." "..stat(48).." "..stat(49))
			 print(stat(50).." "..stat(51).." "..stat(52).." "..stat(53))
			 print(tostr(adr,1))
			 print(info)
				hb+=1
				flip()
				
			elseif sub(str,1,1) =="s" then
				v = split(sub(str,2)	)
				if v[1] == nil then
					sfx(-1)
					print("stop sfx")
				elseif v[2]==nil then
				 sfx(v[1])
				 info = "play sfx "..v[1]..",0"
				else
					sfx(v[1],0,v[2] or 0, v[3] or 32)
					info = str.."\nplay sfx "..v[1]..",0,"..v[2]..","..v[3]
				end
				status()
				
			elseif sub(str,1,1) =="m" then
				nb = tonum(sub(str,2))				
				if nb == nil then
					music(-1)
				else
					music(nb)
				end
				status()
				
			elseif sub(str,1,1) =="@" then
				adr = tonum(sub(str,2)) or 0
				
			elseif sub(str,1,1) =="!" then
				hex =split(sub(str,2),2)
				--print(tostr(adr,3))
				for x in all(hex) do
				 poke(adr, tonum("0x"..x) or 0)
				 --print(adr.."="..x.." = "..(tonum("0x"..x) or 0))
				 adr += 1
				end
				--print(tostr(adr,3))
				
			end
			
			str = ""
			
		else
			str..=chr(peek(0x4300))
	
		end		 
	else
			status()
			extcmd("set_title","disconnected")

			cls()
			print("not connected")
			
			flip()
			shutdown()
			
	end
	


end 
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010f0000217401d7400170033700337001b7001970018700197001b700257002b7003070034700367001770013700127001170018056127000070000700007000070000700007000070000700007000070000700
