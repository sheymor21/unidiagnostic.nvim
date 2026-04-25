local config = require('unidiagnostic.config')
local ui = require('unidiagnostic.ui')
local telescope = require('unidiagnostic.telescope')
local jump = require('unidiagnostic.jump')

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

  -- Telescope search diagnostics in file under cursor
  if keys.search then
    vim.keymap.set('n', keys.search, function()
      M.search_file_diagnostics(bufnr, plugin)
    end, opts)
  end

  -- Telescope search all diagnostics
  if keys.search_all then
    vim.keymap.set('n', keys.search_all, function()
      M.search_all_diagnostics(plugin)
    end, opts)
  end

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
  jump.jump_to_item(item)
end

--- Search diagnostics for the file under cursor using telescope
---@param bufnr number
---@param plugin table
function M.search_file_diagnostics(bufnr, plugin)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local lnum = cursor[1]

  -- Determine the target filepath: either from header line or from diagnostic line
  local filepath = ui.get_header_at_line(lnum)
  local item = ui.get_item_at_line(lnum)

  if not filepath and item then
    filepath = item.filepath
  end

  if not filepath then
    vim.notify('No file under cursor', vim.log.levels.WARN)
    return
  end

  -- Gather all diagnostics and filter by filepath
  local diagnostics_mod = require('unidiagnostic.diagnostics')
  local all_items = diagnostics_mod.gather()
  local file_items = {}
  for _, d in ipairs(all_items) do
    if d.filepath == filepath then
      table.insert(file_items, d)
    end
  end

  if #file_items == 0 then
    vim.notify('No diagnostics for file: ' .. filepath, vim.log.levels.INFO)
    return
  end

  plugin.close()
  telescope.open_picker(file_items, 'Diagnostics: ' .. vim.fn.fnamemodify(filepath, ':t'), false)
end

--- Search all diagnostics using telescope
---@param plugin table
function M.search_all_diagnostics(plugin)
  local diagnostics_mod = require('unidiagnostic.diagnostics')
  local all_items = diagnostics_mod.gather()

  if #all_items == 0 then
    vim.notify('No diagnostics found', vim.log.levels.INFO)
    return
  end

  plugin.close()
  telescope.open_picker(all_items, 'All Diagnostics')
end

return M
