local M = {}

--- Setup auto-refresh autocmds
---@param plugin table Reference to the main plugin module
function M.setup(plugin)
  local group = vim.api.nvim_create_augroup('Unidiagnostic', { clear = true })

  -- Refresh when diagnostics change
  vim.api.nvim_create_autocmd('DiagnosticChanged', {
    group = group,
    callback = function()
      if plugin.is_open then
        vim.schedule(function()
          plugin.refresh()
        end)
      end
    end,
  })

  -- Refresh on buffer write
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = group,
    callback = function()
      if plugin.is_open then
        vim.schedule(function()
          plugin.refresh()
        end)
      end
    end,
  })
end

return M
