modules = modules or {}

local m = {
	name = "Template", -- name
	sort = 200,  --- sort order - 0-100 is reserved, also init-order
}
table.insert(modules, m)

-- some important global variables
----------------------------------
-- activePico 		-- active pico-control of the current file
-- window 			-- main window handle
-- renderer 		-- renderer form main window
-- cursorArrow 		-- default cursor
-- cursorHand 		-- cursor pointing hand
-- topLimit 		-- y-coordinate below the modules and main buttons
-- COLBLACK 		-- predefined color
-- COLWHITE 		-- predefined color
-- COLDARKWHITE 	-- predefined color
-- COLDARKGREY 		-- predefined color
-- COLGREY 			-- predefined color
-- COLLIGHTGREY 	-- predefined color
-- COLRED 			-- predefined color

-- everything is optional!
function m.Init(m)
	-- called when the application starts
	
	-- for example, when you want to use buttons, you should add container here	
	--m.buttons = buttons:CreateContainer()
	--m.inputs = inputs:CreateContainer()	

	-- we need a new config 
	-- set default
	--if config.stupidTemplateOption == nil then config.stupidTemplateOption = true end
	
	-- we need a button to modify the option
	--local b
	--b = m.buttons:Add("stupidTemplateOption","ButtonName",100,nil, "TOOGLE")
	--b.OnClick = function(b) config.stupidTemplateOption = b.selected end


	return true
end

function m.Quit(m)
	-- called when the application end
	
	--m.buttons:DestroyContainer()
	--m.inputs:DestroyContainer()
end

function m.FocusGained(m)
	-- module got focus
	
	-- for example restore zoom level
	--MenuSetZoom(m._zoom or 32)
	
	-- you don't need to resize, because this is called after this.
end

function m.FocusLost(m)
	-- module lost focus
	
	-- for example save zoom level
	--m._zoom = MenuGetZoom(id)	
end


function m.Resize(m)
	-- window size has changed or important settings (like zoom)
	
	-- set the config-button we had created
	--m.buttons.stupidTemplateOption:SetPos(5,topLimit)
	-- and here is a good point to set the value of the button
	--m.buttons.stupidTemplateOption.selected = config.stupidTemplateOption
	
end

function m.ZoomChange(m)
	-- zoom factor has changed
end

function m.Copy(m)
	-- Copy to clipboard
	--return "toclipboard"
end

function m.Paste(m, str)
	-- str pasted from clipboard
end

function m.Delete(m)
	-- user pressed the delete key
end

function m.SelectAll(m)
	-- user pressed ctrl+a
end

function m.Draw(m)
	-- draw your module
end


function m.MouseDown(m, mx, my, mb, clicks)
	-- mouse button down on mx,my - button is "LEFT", "RIGHT"..., clicks how often (2= double click)
end

function m.MouseMove(m, mx, my, mb)
	-- mouse moveing - mb is a combination of mousebuttons, for example "LEFT RIGHT" when both buttons are pressed
end

function m.MouseUp(m, mx, my, mb)
	-- mousebutton is released
end

function m.MouseWheel(m, wx, wy, mx, my)
	-- mousewheel is moved by wx,wy - on mouseposition mx,my
end

function m.KeyDown(m, sym, scan, mod)
	-- Keyboard is pressed.
end

function m.KeyUp(m, sym, scan, mod)
	-- keyboard is released.
end

function m.Input(m, text)
	-- user entered a Char - shift-key, combination like ^+e = ê are handeld
	-- this should be you main source, when you want text from the user
end

function m.Undo(m)
	-- User perform an undo action. Called after undo is finished!
end

function m.Redo(m)
	-- User perform an redo action. Called after undo is finished!
	-- in most cases this can be definied as
	--m.Redo = m.Undo
end


return m