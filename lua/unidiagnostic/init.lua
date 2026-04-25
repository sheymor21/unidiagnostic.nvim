local config = require('unidiagnostic.config')
local ui = require('unidiagnostic.ui')
local diagnostics = require('unidiagnostic.diagnostics')
local autocmds = require('unidiagnostic.autocmds')
local navigation = require('unidiagnostic.navigation')

local M = {}

-- State for all buffers view (:UnidiagnosticToggle)
M.is_open = false
M.bufnr = nil
M.winid = nil

-- Separate state for current file view (:UnidiagnosticCurrent)
M.current_is_open = false
M.current_bufnr = nil
M.current_winid = nil

function M.setup(opts)
  config.setup(opts)

  -- Create commands
  vim.api.nvim_create_user_command('UnidiagnosticToggle', function()
    M.toggle()
  end, { desc = 'Toggle unidiagnostic floating window' })

  vim.api.nvim_create_user_command('UnidiagnosticCurrent', function()
    M.toggle_current()
  end, { desc = 'Toggle diagnostics window for current file only' })

  vim.api.nvim_create_user_command('UnidiagnosticRefresh', function()
    M.refresh()
  end, { desc = 'Refresh unidiagnostic window' })

  -- Setup auto-refresh
  if config.get().auto_refresh then
    autocmds.setup(M)
  end
end

function M.toggle()
  if M.is_open then
    M.close()
  else
    M.open()
  end
end

function M.open()
  if M.is_open then
    return
  end

  local items = diagnostics.gather()
  if #items == 0 then
    vim.notify('No diagnostics found', vim.log.levels.INFO)
    return
  end

  M.bufnr, M.winid = ui.create(items, config.get())
  M.is_open = true

  -- Setup navigation keymaps in the float buffer
  navigation.setup(M.bufnr, M)
end

function M.toggle_current()
  if M.current_is_open then
    M.close_current()
    return
  end

  local items = diagnostics.gather_current()
  if #items == 0 then
    vim.notify('No diagnostics in current file', vim.log.levels.INFO)
    return
  end

  M.current_bufnr, M.current_winid = ui.create_current(items, config.get())
  M.current_is_open = true

  -- Setup navigation keymaps in the float buffer
  -- Pass a wrapper that redirects close/refresh to current file methods
  local current_wrapper = {
    close = function() M.close_current() end,
    refresh = function() M.refresh_current() end,
  }
  navigation.setup(M.current_bufnr, current_wrapper)
end

function M.close_current()
  if not M.current_is_open then
    return
  end

  ui.close(M.current_winid)
  M.current_is_open = false
  M.current_winid = nil
  M.current_bufnr = nil
end

function M.refresh_current()
  if not M.current_is_open then
    return
  end

  local items = diagnostics.gather_current()
  if #items == 0 then
    M.close_current()
    vim.notify('No diagnostics in current file', vim.log.levels.INFO)
    return
  end

  ui.update_current(M.current_bufnr, items)
end

function M.close()
  if not M.is_open then
    return
  end

  ui.close(M.winid)
  M.is_open = false
  M.winid = nil
  M.bufnr = nil
end

function M.refresh()
  if not M.is_open then
    return
  end

  local items = diagnostics.gather()
  if #items == 0 then
    M.close()
    vim.notify('No diagnostics found', vim.log.levels.INFO)
    return
  end

  ui.update(M.bufnr, items, config.get())
end

return M
