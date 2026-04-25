local util = require('unidiagnostic.util')

local M = {}

--- Jump to a diagnostic item after closing any float
---@param item table DiagnosticItem
function M.jump_to_item(item)
  if not vim.api.nvim_buf_is_valid(item.bufnr) then
    vim.notify('Buffer no longer valid', vim.log.levels.WARN)
    return
  end

  local target_win = nil
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == item.bufnr then
      target_win = win
      break
    end
  end

  if not target_win then
    target_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(target_win, item.bufnr)
  end

  vim.api.nvim_set_current_win(target_win)
  vim.api.nvim_win_set_cursor(target_win, { item.lnum, item.col - 1 })
  vim.diagnostic.open_float({ bufnr = item.bufnr, scope = 'cursor' })
end

return M
