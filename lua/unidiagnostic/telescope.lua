local util = require('unidiagnostic.util')
local jump = require('unidiagnostic.jump')

local M = {}

--- Check if telescope is available
---@return boolean
function M.has_telescope()
  local ok, _ = pcall(require, 'telescope')
  return ok
end

--- Create a telescope entry from a diagnostic item
---@param item table DiagnosticItem
---@param show_path boolean Whether to include the file path in the display
---@return table
local function make_entry(item, show_path)
  local sev_char = util.get_severity_char(item.severity)

  local display_text
  if show_path then
    display_text = string.format('[%s] %s:%d:%d  %s', sev_char, item.display_path, item.lnum, item.col, item.message)
  else
    display_text = string.format('[%s] %d:%d  %s', sev_char, item.lnum, item.col, item.message)
  end

  local hl_group = util.severity_to_hl(item.severity)
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
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        if selection and selection.value then
          jump.jump_to_item(selection.value)
        end
      end)
      return true
    end,
  }):find()
end

return M
