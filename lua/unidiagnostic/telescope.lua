local M = {}

--- Check if telescope is available
---@return boolean
function M.has_telescope()
  local ok, _ = pcall(require, 'telescope')
  return ok
end

--- Jump to a diagnostic item after closing the unidiagnostic float
---@param item table DiagnosticItem
local function jump_to_item(item)
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

--- Map diagnostic severity to highlight group
---@param severity number
---@return string
local function severity_to_hl(severity)
  if severity == vim.diagnostic.severity.ERROR then
    return 'DiagnosticError'
  elseif severity == vim.diagnostic.severity.WARN then
    return 'DiagnosticWarn'
  elseif severity == vim.diagnostic.severity.INFO then
    return 'DiagnosticInfo'
  elseif severity == vim.diagnostic.severity.HINT then
    return 'DiagnosticHint'
  end
  return 'Normal'
end

--- Create a telescope entry from a diagnostic item
---@param item table DiagnosticItem
---@param show_path boolean Whether to include the file path in the display
---@return table
local function make_entry(item, show_path)
  local diagnostics_mod = require('unidiagnostic.diagnostics')
  local sev_char = diagnostics_mod.get_severity_char(item.severity)

  local display_text
  if show_path then
    display_text = string.format('[%s] %s:%d:%d  %s', sev_char, item.display_path, item.lnum, item.col, item.message)
  else
    display_text = string.format('[%s] %d:%d  %s', sev_char, item.lnum, item.col, item.message)
  end

  local hl_group = severity_to_hl(item.severity)
  local highlights = {
    { { 0, 3 }, hl_group }, -- highlight the [e]/[w]/[i]/[s] part
  }

  return {
    value = item,
    display = function(_)
      return display_text, highlights
    end,
    ordinal = display_text,
    filename = item.filepath,
    lnum = item.lnum,
    col = item.col,
  }
end

--- Open telescope picker with a list of diagnostic items
---@param items table[] Diagnostic items to show
---@param prompt_title string Title for the telescope window
---@param show_path boolean|nil Whether to show the file path (default true)
function M.open_picker(items, prompt_title, show_path)
  if not M.has_telescope() then
    vim.notify('telescope.nvim is required for search functionality', vim.log.levels.WARN)
    return
  end

  show_path = show_path ~= false

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  local conf = require('telescope.config').values

  pickers.new({}, {
    prompt_title = prompt_title,
    finder = finders.new_table({
      results = items,
      entry_maker = function(item)
        return make_entry(item, show_path)
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        if selection and selection.value then
          jump_to_item(selection.value)
        end
      end)
      return true
    end,
  }):find()
end

return M
