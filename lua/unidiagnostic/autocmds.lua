local M = {}

--- Setup auto-refresh autocmds
---@param plugin table Reference to the main plugin module
function M.setup(plugin)
  local group = vim.api.nvim_create_augroup('Unidiagnostic', { clear = true })

  local function refresh_if_open()
    if plugin.is_open then
      vim.schedule(function()
        plugin.refresh()
      end)
    end
    if plugin.current_is_open then
      vim.schedule(function()
        plugin.refresh_current()
      end)
    end
  end

  -- Refresh when diagnostics change
  vim.api.nvim_create_autocmd('DiagnosticChanged', {
    group = group,
    callback = refresh_if_open,
  })

  -- Refresh on buffer write
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = group,
    callback = refresh_if_open,
  })
end

return M
