vim.keymap.set('n', '<localleader>do', function()
  local line = vim.api.nvim_get_current_line()
  local doi = line:match('[dD][oO][iI]%s*=%s*[{"]%s*(.-)%s*[}"]')

  if not doi or doi == '' then
    vim.notify('Place the cursor on a DOI field', vim.log.levels.WARN)
    return
  end

  vim.ui.open('https://doi.org/' .. doi)
end, { buffer = true, desc = 'Open DOI in browser' })
