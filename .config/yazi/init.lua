-- Start Neovim's Yazi dock with the parent pane hidden.
if os.getenv("NVIM_SERVER") then
	require("toggle-pane"):entry("min-parent")
end

-- -- Always show device selection
-- require("kdeconnect-send"):setup({
--     auto_select_single = false,
-- })

require("full-border"):setup()

require("starship"):setup({
    -- Hide flags (such as filter, find and search). This can be beneficial for starship themes
    -- which are intended to go across the entire width of the terminal.
    hide_flags = false,
    -- Whether to place flags after the starship prompt. False means the flags will be placed before the prompt.
    flags_after_prompt = true,
    -- Custom starship configuration file to use
    config_file = "~/.config/starship.toml", -- Default: nil
    -- Whether to enable support for starship's right prompt (i.e. `starship prompt --right`).
    show_right_prompt = true,
    -- Whether to hide the count widget, in case you want only your right prompt to show up. Only has
    -- an effect when `show_right_prompt = true`
    hide_count = true,
    -- Separator to place between the right prompt and the count widget. Use `count_separator = ""`
    -- to have no space between the widgets.
    count_separator = " ",
})
