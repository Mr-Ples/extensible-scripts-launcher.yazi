# WARNING

This plugin was almost completely vibe coded, i didn't read this readme either. but it works for me.

# Extensible Scripts Plugin for Yazi

![Watch Demo Video](https://github.com/Mr-Ples/extensible-scripts-launcher-launcher.yazi/blob/main/showcase.gif)

A powerful script runner plugin for Yazi that provides a unified interface to execute external scripts, built-in functions, and custom modules through an fzf-powered selection menu.

## Features

- **External Script Execution**: Run any shell script or command with automatic file argument passing
- **Built-in Functions**: Execute Lua functions directly within the plugin with rich context data
- **Modular System**: Load custom functions from separate Lua modules in the `modules/` directory  
- **Category Organization**: Group scripts and functions by category for better organization
- **fzf Integration**: Beautiful fuzzy search interface with categorized sections
- **File Context**: Automatically passes the currently hovered file as an argument to scripts
- **Extensible**: Easy to add new scripts, functions, and modules

## Installation

1. Install the plugin using Yazi's package manager:
   ```bash
   ya pkg add Mr-Ples/extensible-scripts-launcher
   ```

2. Create a `modules` directory in the plugin folder and copy the module files:
   ```bash
   # Navigate to the plugin directory (adjust path if different)
   cd ~/.config/yazi/plugins/extensible-scripts-launcher.yazi
   
   # Create modules directory
   mkdir -p modules
   
   # Copy module files from the repository
   # You'll need to manually copy scriptutils.lua and test.lua from this repo
   # to the modules/ directory
   ```

3. The plugin should now be ready to use.

## Usage

### Basic Usage

Add a keymap to trigger the script runner:

```toml
[[manager.prepend_keymap]]
on = ["<C-`>"]
run = ["plugin extensible-scripts-launcher"]
desc = "Extensible scripts"
```

### Configuration

Configure the plugin in your `init.lua`:

```lua
require("extensible-scripts-launcher"):setup({
    scripts = {
        -- External shell scripts
        { 
            name = "Upload File", 
            cmd = "/home/user/scripts/upload_file.sh", 
            desc = "Upload selected file", 
            category = "Utilities" 
        },
        
        -- Built-in Lua functions
        { 
            name = "Show Time", 
            func = "show_time", 
            desc = "Display current time", 
            category = "Info" 
        },
        
        -- Recommended built-in for adding scripts
        { 
            name = "Add selected script", 
            func = "add_current_file_as_script", 
            desc = "Adds selected file to scripts", 
            category = "Scripts" 
        },
        
        -- Scripts without categories (will appear under "Other")
        { 
            name = "Convert Video", 
            cmd = "/home/user/scripts/vid_to_gif.sh", 
            desc = "Convert video to GIF" 
        },
    }
})
```

## Script Configuration Options

Each script entry supports these properties:

- **`name`** (required): Display name in the selection menu
- **`desc`** (optional): Description shown in the menu
- **`category`** (optional): Groups scripts under section headers
- **`cmd`** (for external scripts): Path to executable script/command
- **`func`** (for built-in functions): Name of Lua function to execute

## Built-in Functions

The plugin includes some default built-in functions:

- `show_current_file`: Display information about the currently hovered file
- `list_directory`: Show contents of the current directory
- `show_time`: Display current time
- `test_function`: Simple test function
- `add_current_file_as_script`: Adds the currently selected file as an auto-generated script

### Context Object for Built-in Functions

All built-in functions receive a `context` object as their first parameter, which contains:

- **`current_file`**: Path to the currently hovered file
- **`cwd`**: Current working directory
- **`scripts`**: Array of all configured scripts
- **`get_state(attr)`**: Function to get plugin state
- **`set_state(attr, value)`**: Function to set plugin state

This allows built-in functions to access and modify the plugin's state and interact with the current file context.

## Creating Custom Modules

You can extend functionality by creating Lua modules in the `modules/` directory:

```lua
-- ~/.config/yazi/plugins/extensible-scripts-launcher.yazi/modules/my_module.lua
local function my_custom_function(context)
    -- Access the context object
    local current_file = context.current_file
    local cwd = context.cwd
    
    ya.notify { 
        title = "Custom Function", 
        content = "Current file: " .. current_file, 
        timeout = 3, 
        level = "info" 
    }
end

local function another_function(context)
    -- Your custom logic here
    -- Can access context.scripts, context.get_state(), etc.
end

-- Export functions to make them available
return {
    my_custom_function = my_custom_function,
    another_function = another_function,
}
```

Then reference them in your configuration:

```lua
{ 
    name = "My Custom Function", 
    func = "my_custom_function", 
    desc = "Execute my custom function", 
    category = "Custom" 
}
```

## How It Works

1. **Script Discovery**: The plugin loads all configured scripts and scans the `modules/` directory for additional functions
2. **Categorization**: Scripts are grouped by their `category` property, with uncategorized items under "Other"
3. **fzf Interface**: A searchable menu displays all available scripts with section headers
4. **Execution**: Selected scripts are executed with appropriate context:
   - **External scripts**: Current file path appended as argument
   - **Built-in functions**: Context object passed as first parameter

## File Context

### For External Scripts
When executing external scripts, the plugin automatically:
- Gets the currently hovered file path
- Appends it as an argument to the command
- Executes the command asynchronously (non-blocking)

### For Built-in Functions
Built-in functions receive a rich context object containing:
- Current file path and working directory
- Access to all configured scripts
- State management functions for persistent data

This allows both external scripts and built-in functions to operate on the selected file and access plugin state without additional configuration.

## Requirements

- **fzf**: Required for the script selection interface
- **Lua modules**: Must return a table of functions to be auto-loaded

## Example Use Cases

- **File Operations**: Upload, convert, compress files
- **System Control**: WiFi, Bluetooth, VPN management  
- **Development Tools**: Git operations, build scripts
- **Media Processing**: Video/image conversion, screenshots
- **Utility Functions**: Time display, file info, directory listing
- **Script Management**: Add executable files as scripts dynamically

The plugin provides a flexible framework for integrating any external tool or custom function into your Yazi workflow. 