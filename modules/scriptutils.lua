-- Script utilities for extensible-scripts-launcher.yazi

local function fail(s, ...)
	ya.notify { title = "Script Runner", content = string.format(s, ...), timeout = 50, level = "error" }
end

local function info(s, ...)
	ya.notify { title = "Script Runner", content = string.format(s, ...), timeout = 3, level = "info" }
end

-- -- Get current state
-- local get_state = ya.sync(function(state, attr)
-- 	return state[attr]
-- end)

-- -- Set state
-- local set_state = ya.sync(function(state, attr, value)
-- 	state[attr] = value
-- end)

-- Load auto-generated scripts from file
local function load_auto_scripts()
	local config_file = os.getenv("HOME") .. "/.config/yazi/plugins/extensible-scripts-launcher.yazi/auto-scripts.lua"
	local file = io.open(config_file, "r")
	if not file then
		return {} -- No auto-scripts file exists yet
	end
	file:close()
	
	-- Load the file as Lua code
	local success, auto_scripts = pcall(dofile, config_file)
	if success and type(auto_scripts) == "table" then
		return auto_scripts
	else
		fail("Failed to load auto-scripts.lua: " .. tostring(auto_scripts))
		return {}
	end
end

-- Save auto-generated scripts to file
local function save_scripts_to_file(scripts)
	local config_file = os.getenv("HOME") .. "/.config/yazi/plugins/extensible-scripts-launcher.yazi/auto-scripts.lua"
	local file = io.open(config_file, "w")
	if not file then
		fail("Could not write to config file: " .. config_file)
		return false
	end
	
	file:write("-- Auto-generated scripts\n")
	file:write("return {\n")
	for _, script in ipairs(scripts) do
		if script.category == "Auto-added" then
			file:write("  {\n")
			file:write(string.format("    name = %q,\n", script.name))
			file:write(string.format("    desc = %q,\n", script.desc))
			file:write(string.format("    cmd = %q,\n", script.cmd))
			file:write(string.format("    category = %q,\n", script.category))
			file:write("  },\n")
		end
	end
	file:write("}\n")
	file:close()
	return true
end

-- Helper function to add a script by file path
local function add_script_by_path(file_path, context)
	if not file_path or file_path == "" then
		fail("No file path provided")
		return false
	end
	
	-- Check if file exists
	local file = io.open(file_path, "r")
	if not file then
		fail("File does not exist: " .. file_path)
		return false
	end
	file:close()
	-- Check if file is executable or a script
	local file_ext = file_path:match("%.([^%.]+)$")
	info(tostring(file_ext))
	if not file_ext or (file_ext ~= "sh" and file_ext ~= "py" and file_ext ~= "lua") then
		fail("File is not a recognized script type (.sh, .py, .lua): " .. file_path)
		return false
		-- local handle = io.popen("test -x '" .. file_path .. "' && echo 'executable'")
		-- if handle then
		-- 	local result = handle:read("*all"):gsub("%s+", "")
		-- 	handle:close()
		-- 	if result ~= "executable" then
		-- 		fail("File is not executable or a recognized script type (.sh, .py, .lua): " .. file_path)
		-- 		return false
		-- 	end
		-- else
		-- 	fail("Could not check if file is executable: " .. file_path)
		-- 	return false
		-- end
	end
	
	-- Get current scripts to check for duplicates
	local scripts = context.scripts or {}
	
	-- Check if this script already exists
	for _, script in ipairs(scripts) do
		if script.cmd == file_path then
			fail("Script already exists: " .. script.name)
			return false
		end
	end
	
	local script_name = file_path:match("([^/]+)$") -- Get filename
	
	-- Create new script entry
	local new_script = {
		name = script_name,
		desc = "Auto-added: " .. script_name,
		cmd = file_path,
		category = "Auto-added"
	}
	
	-- Add to scripts list
	table.insert(scripts, new_script)
	context.set_state("scripts", scripts)
	
	-- Save to persistent file
	if save_scripts_to_file(scripts) then
		info("Added script '" .. script_name .. "' (saved to auto-scripts.lua)")
	else
		info("Added script '" .. script_name .. "' (session only)")
	end
	
	return true
end

-- Built-in function that adds the currently selected file as a script
local function add_current_file_as_script(context)
	local current_file = context.current_file
	if not current_file or current_file == "" then
		fail("No file selected")
		return
	end
	
	info("Adding current file as script: " .. current_file:match("([^/]+)$"))
	return add_script_by_path(current_file, context)
end

return {
	load_auto_scripts = load_auto_scripts,
	save_scripts_to_file = save_scripts_to_file,
	add_current_file_as_script = add_current_file_as_script,
}