local config = require('unidiagnostic.config')
local ui = require('unidiagnostic.ui')
local diagnostics = require('unidiagnostic.diagnostics')
local autocmds = require('unidiagnostic.autocmds')
local navigation = require('unidiagnostic.navigation')

local M = {}

M.is_open = false
M.bufnr = nil
M.winid = nil

function M.setup(opts)
  config.setup(opts)

  -- Create commands
  vim.api.nvim_create_user_command('UnidiagnosticToggle', function()
    M.toggle()
  end, { desc = 'Toggle unidiagnostic floating window' })

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
