-- Start Neovim's Yazi dock with the parent pane hidden.
if os.getenv("NVIM_SERVER") then
	require("toggle-pane"):entry("min-parent")
end
