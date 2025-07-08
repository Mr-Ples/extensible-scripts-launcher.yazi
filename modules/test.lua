local function info(s, ...)
	ya.notify { title = "Script Runner", content = string.format(s, ...), timeout = 3, level = "info" }
end

local function another_test()
	info("Another test function executed!")
end

local function basic_context_test(context)
	info("Function called successfully")
	
	local current_file = context.current_file
	if not current_file or current_file == "" then
		fail("No file selected")
		return
	end
	
	info("Current file: " .. current_file)
	
	-- Access other context data
	local scripts = context.scripts or {}
	local cwd = context.cwd
	
	-- Add your script addition logic here
	-- You can use context.get_state() and context.set_state() for state management
end

local function show_file_count()
	local handle = io.popen("find . -maxdepth 1 -type f | wc -l")
	if handle then
		local count = handle:read("*all"):gsub("%s+", "")
		handle:close()
		info("Files in current directory: " .. count)
	else
		info("Could not count files")
	end
end

local function show_time()
	local time = os.date("%H:%M:%S")
	info("Current time: " .. time)
end

local function ask_for_input()	
	local script_path = os.getenv("HOME") .. "/scripts/new-script.sh"
	
	-- Use interactive mode to let user input arguments
	ya.manager_emit("shell", {
		script_path .. " ",
		orphan = true,
		confirm = true,
		block = false,
		interactive = true,
		cursor = string.len(script_path) + 1  -- Position cursor after the space
	})
	debug("adding ignore pattern")
end

-- Export ALL the functions in the return table
return {
	test_function = ask_for_input,
	another_test = another_test,
	show_file_count = show_file_count,
	show_time = show_time,
}