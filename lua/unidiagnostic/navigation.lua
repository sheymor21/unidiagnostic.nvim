local config = require('unidiagnostic.config')
local ui = require('unidiagnostic.ui')

local M = {}

--- Setup navigation keymaps in the diagnostic float buffer
---@param bufnr number
---@param plugin table Reference to the main plugin module (for close/open)
function M.setup(bufnr, plugin)
  local keys = config.get().keys
  local opts = { buffer = bufnr, silent = true, noremap = true }

  -- Close
  vim.keymap.set('n', keys.close, function()
    plugin.close()
  end, opts)

  -- Open / Jump to diagnostic
  vim.keymap.set('n', keys.open, function()
    M.jump_to_diagnostic(bufnr, plugin)
  end, opts)

  -- Fold / Unfold file group
  vim.keymap.set('n', keys.fold, function()
    M.toggle_fold_at_cursor(bufnr, plugin)
  end, opts)

  -- Optional: also close with Esc
  vim.keymap.set('n', '<Esc>', function()
    plugin.close()
  end, opts)
end

--- Toggle fold state for the file group at cursor position
---@param bufnr number
---@param plugin table
function M.toggle_fold_at_cursor(bufnr, plugin)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local lnum = cursor[1]

  local filepath = ui.get_header_at_line(lnum)
  if not filepath then
    return
  end

  ui.toggle_fold(filepath)

  -- Re-render to show/hide diagnostics
  plugin.refresh()
end

--- Jump to the diagnostic under the cursor
---@param bufnr number
---@param plugin table
function M.jump_to_diagnostic(bufnr, plugin)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local lnum = cursor[1]

  local item = ui.get_item_at_line(lnum)
  if not item then
    return
  end

  -- Close the float first
  plugin.close()

  -- Jump to the buffer
  local target_buf = item.bufnr
  if not vim.api.nvim_buf_is_valid(target_buf) then
    vim.notify('Buffer no longer valid', vim.log.levels.WARN)
    return
  end

  -- Find or create a window for this buffer
  local target_win = nil
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == target_buf then
      target_win = win
      break
    end
  end

  if not target_win then
    -- Switch current window to the target buffer
    target_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(target_win, target_buf)
  end

  -- Set cursor position (0-indexed for nvim_win_set_cursor)
  vim.api.nvim_set_current_win(target_win)
  vim.api.nvim_win_set_cursor(target_win, { item.lnum, item.col - 1 })

  -- Open the diagnostic float at the location if possible
  vim.diagnostic.open_float({ bufnr = target_buf, scope = 'cursor' })
end

return M
