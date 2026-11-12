-- pi configuration, explicitly initialized from init.lua.
local M = {}

function M.setup()
  -- Optional local development fork; reproduction details: INTEGRATIONS.md.
  local pi = require('custom.runtime').setup_pi()
  if pi then
    vim.keymap.set("x", "<leader>ps", pi.append_selection,
      { desc = "Add selection to Pi draft (no submit)" })
    vim.keymap.set("x", "<leader>pa", pi.append_selection_prompt,
      { desc = "Add selection with message to Pi draft (no submit)" })
    vim.keymap.set("n", "<leader>pf", pi.append_file,
      { desc = "Add file reference to Pi draft" })
    vim.keymap.set("n", "<leader>pb", pi.append_buffer,
      { desc = "Add buffer to Pi draft (no submit)" })

    vim.keymap.set("n", "<leader>pi", "<cmd>PiPing<CR>",
      { desc = "Ping Pi session" })

    vim.keymap.set("n", "<leader>pp", ":PiSend<CR>",
     { desc = "Send prompt to Pi & submit" })

    vim.keymap.set("n", "<leader>pF", ":PiSendFile<CR>",
     { desc = "Send file to Pi & submit" })
    vim.keymap.set("v", "<leader>pS", ":PiSendSelection<CR>",
     { desc = "Send selection to Pi & submit" })
    vim.keymap.set("n", "<leader>pB", ":PiSendBuffer<CR>",
     { desc = "Send buffer to Pi & submit" })
  end
end

return M
