local M = {}

local function fail(s, ...)
	ya.notify { title = "Script Runner", content = string.format(s, ...), timeout = 50, level = "error" }
end

local function info(s, ...)
	ya.notify { title = "Script Runner", content = string.format(s, ...), timeout = 3, level = "info" }
end

local function debug(s, ...)
	ya.notify { title = "Script Runner Debug", content = string.format(s, ...), timeout = 2, level = "warn" }
end

-- State management functions
local get_state = ya.sync(function(state, attr)
	return state[attr]
end)

local set_state = ya.sync(function(state, attr, value)
	state[attr] = value
end)

-- Get current hovered file in sync context
local get_current_file = ya.sync(function()
	local h = cx.active.current.hovered
	return h and tostring(h.url) or ""
end)

-- Get current working directory
local get_cwd = ya.sync(function()
	return tostring(cx.active.current.cwd)
end)

-- Map of function names to actual functions

local builtin_functions = { }

-- Auto-load all modules from the modules directory
local function load_all_builtin_modules()
	-- debug('load_all_builtin_modules')
	local modules = {}
	local modules_dir = os.getenv("HOME") .. "/.config/yazi/plugins/extensible-scripts-launcher.yazi/modules"
	-- debug(modules_dir)
	
	-- debug("Loading modules from: " .. modules_dir)
	-- find .config/yazi/plugins/extensible-scripts-launcher.yazi/modules/ -name '*.lua' -type f
		-- Try to read modules directory (this is a bit hacky but works)
		local handle = io.popen("find '" .. modules_dir .. "' -name '*.lua' -type f 2>/dev/null")
		if handle then
			for filename in handle:lines() do
				local module_name = filename:match("([^/]+)%.lua$")
				if module_name then
					-- debug("Attempting to load module file: " .. filename)
					local success, result = pcall(dofile, filename)
					if success and type(result) == "table" then
						-- info("Successfully loaded module: " .. module_name)
						for name, func in pairs(result) do
							if type(func) == "function" then
								modules[name] = func
								-- debug("Registered function: " .. name)
							end
						end
					else
						fail("Failed to load module " .. module_name .. ": " .. tostring(result))
					end
				end
			end
			handle:close()
		else
			debug("Could not access modules directory: " .. modules_dir)
		end
	
	-- -- Add the original builtin functions as fallback
	-- modules.show_current_file = show_current_file
	-- modules.list_directory = list_directory
	
	return modules
end

-- Execute a script or built-in function
local function execute_script(script)
	if script.func then
		-- Execute built-in function
		local func = builtin_functions[script.func]
		if func then
			-- Create a context object with all available data
			local context = {
				current_file = get_current_file(),
				cwd = get_cwd(),
				scripts = get_state("scripts"),
				-- Add more context as needed
				get_state = get_state,
				set_state = set_state,
			}
			
			-- All built-in functions receive context as first parameter
			func(context)
		else
			fail("Built-in function not found: " .. script.func)
		end
	elseif script.cmd then
		-- Execute external script
		local current_file = get_current_file()
		local cmd = script.cmd
		
		-- If the script expects a file argument and we have one, append it
		if current_file and current_file ~= "" then
			cmd = cmd .. " '" .. current_file .. "'"
		end
		
		info("Executing: " .. script.name)
		ya.manager_emit("shell", { cmd, confrim=false, orphan=true, block = false })
	else
		fail("Script has no command or function defined")
	end
end

-- Show script selection using fzf
local function show_script_picker()
	local scripts = get_state("scripts")
	-- debug("show_script_picker called, scripts length: " .. (scripts and #scripts or "nil"))
	
	if not scripts or #scripts == 0 then
		fail("No scripts configured")
		return
	end
	
	-- Group scripts by category
	local categories = {}
	local uncategorized = {}
	
	for i, script in ipairs(scripts) do
		if script.category then
			if not categories[script.category] then
				categories[script.category] = {}
			end
			table.insert(categories[script.category], {script = script, index = i})
		else
			table.insert(uncategorized, {script = script, index = i})
		end
	end
	
	-- Build fzf input with sections
	local fzf_lines = {}
	
	-- Add categorized scripts
	for category, scripts_in_category in pairs(categories) do
		-- Add section header
		table.insert(fzf_lines, "── " .. category .. " ──")
		
		for _, script_data in ipairs(scripts_in_category) do
			local script = script_data.script
			local line = string.format("%d: %s - %s", script_data.index, script.name, script.desc or "No description")
			table.insert(fzf_lines, line)
		end
		
		-- Add spacing between sections
		table.insert(fzf_lines, "")
	end
	
	-- Add uncategorized scripts
	if #uncategorized > 0 then
		table.insert(fzf_lines, "── Other ──")
		for _, script_data in ipairs(uncategorized) do
			local script = script_data.script
			local line = string.format("%d: %s - %s", script_data.index, script.name, script.desc or "No description")
			table.insert(fzf_lines, line)
		end
	end
	
	local _permit = ya.hide()
	local child, err = Command("fzf")
		:arg({
			"--height=80%",
			"--layout=reverse",
			"--border",
			"--prompt=🚀 Select script: ",
			"--header=Found " .. #scripts .. " scripts",
			"--preview-window=right:40%",
			"--preview=echo {}",
			"--bind=ctrl-/:toggle-preview"
		})
		:stdin(Command.PIPED)
		:stdout(Command.PIPED)
		:stderr(Command.INHERIT)
		:spawn()
	
	if not child then
		fail("Failed to spawn fzf")
		return
	end
	
	-- Send all script options to fzf
	child:write_all(table.concat(fzf_lines, "\n"))
	child:flush()
	
	local output, err = child:wait_with_output()
	if not output then
		fail("Cannot read fzf output")
		return
	end
	
	if not output.status.success and output.status.code ~= 130 then
		fail("fzf exited with error code: " .. tostring(output.status.code))
		return
	end
	
	-- Parse fzf output to get selected script index
	local selected_line = output.stdout:match("([^\n]*)")
	if not selected_line or selected_line == "" then
		return
	end
	
	-- Skip if user selected a header or empty line
	if selected_line:match("^──") or selected_line:match("^%s*$") then
		return
	end
	
	local script_index = selected_line:match("^(%d+):")
	if not script_index then
		fail("Could not parse script selection")
		return
	end
	
	script_index = tonumber(script_index)
	local selected_script = scripts[script_index]
	if not selected_script then
		fail("Invalid script index: " .. script_index)
		return
	end
	
	-- Execute the selected script
	execute_script(selected_script)
end

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

-- Initialization function called lazily from entry
local function init()
	local options = get_state("options")
	if not options then
		fail("No configuration provided")
		return
	end
	
	-- Load additional builtin functions from modules
	local additional_functions = load_all_builtin_modules()
	for name, func in pairs(additional_functions) do
		builtin_functions[name] = func
	end
	
	-- Set default values and store scripts
	local scripts = options.scripts or {}
	
	-- Load auto-generated scripts and merge them
	local auto_scripts = load_auto_scripts()
	for _, auto_script in ipairs(auto_scripts) do
		table.insert(scripts, auto_script)
	end
	
	set_state("scripts", scripts)
	set_state("init", true)
	
	-- debug("Initialized with " .. #scripts .. " scripts")
end

-- Return the plugin interface
return {
	setup = function(state, options)
		state.options = options
		-- debug("Setup called with options")
	end,
	
	entry = function(self, job)
		init()
		
		local init_error = get_state("init_error")
		if init_error then
			fail(init_error)
			return
		end
		
		-- Check for add-script argument
		if job.args[1] == "add-script" then
			local additional_functions = load_all_builtin_modules()
			if additional_functions.create_script_from_file then
				additional_functions.create_script_from_file()
			else
				fail("create_script_from_file function not available")
			end
			return
		end
		
		-- debug("Entry called, showing script picker")
		show_script_picker()
	end,
}