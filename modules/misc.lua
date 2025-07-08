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
local function lazygit(context)
	local repos_path = "/media/repos"
	local plugin_name = 'lazygit'
    local cwd = context.cwd
	
	-- First, get the list of repositories
	local repos_cmd = string.format("find %s -maxdepth 2 -name '.git' -type d | sed 's|/.git||' | sed 's|%s/||'", repos_path, repos_path)
	
	local child, err =
		Command("sh"):arg({"-c", repos_cmd}):stdout(Command.PIPED):stderr(Command.INHERIT):spawn()
	
	if not child then
		return fail("Failed to scan repositories in %s", repos_path)
	end
	
	local repos_output, err = child:wait_with_output()
	if not repos_output or not repos_output.status.success then
		return fail("Failed to list repositories in %s", repos_path)
	end
	
	local repos_list = repos_output.stdout
	if repos_list == "" then
		return fail("No git repositories found in %s", repos_path)
	end
	
	-- Now run fzf with the repository list
	local fzf_child, err =
		Command("fzf"):arg({
            "--height=80%",
            "--layout=reverse",
            "--border",
            "--prompt=🔍 Pick Repo: ",
            "--header=Type to search repos",
            "--preview-window=right:40%",
            "--preview=echo 'Repository: {}' && find " .. repos_path .. "/{} -name '*.md' -o -name 'README*' | head -5 | xargs -I {} sh -c 'echo \"--- {} ---\" && head -10 \"{}\"'",
          }):stdin(Command.PIPED):stdout(Command.PIPED):stderr(Command.INHERIT):spawn()

	if not fzf_child then
		return fail("Spawn `fzf` failed with error code %s. Do you have it installed?", err)
	end
	
	-- Write the repos list to fzf's stdin
	fzf_child:write_all(repos_list)
	fzf_child:flush()

	local output, err = fzf_child:wait_with_output()
	if not output then
		return fail("Cannot read `fzf` output, error code %s", err)
	elseif not output.status.success and output.status.code ~= 130 then
		return fail("`fzf` exited with error code %s", output.status.code)
	end

	local selected_repo = output.stdout:gsub("\n$", "")

	if selected_repo ~= "" then
		local selected_path = repos_path .. "/" .. selected_repo
		ya.manager_emit("cd", { selected_path })
		-- Hide yazi and run command as orphan process
		ya.manager_emit("plugin", { plugin_name })
		info("Launched lazygit for repository: %s", selected_repo)
	end
end

local function create_new_script(context)
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
end

local function create_new_pyenv(context)
	local script_path = os.getenv("HOME") .. "/scripts/new-pyenv.sh"
	
	-- Use interactive mode to let user input arguments
	ya.manager_emit("shell", {
		script_path .. " ",
		orphan = true,
		confirm = true,
		block = false,
		interactive = true,
		cursor = string.len(script_path) + 1  -- Position cursor after the space
	})
end

return {
	lazygit = lazygit,
	create_new_script = create_new_script,
	create_new_pyenv = create_new_pyenv
}