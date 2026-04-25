local config = require('unidiagnostic.config')
local util = require('unidiagnostic.util')

local M = {}

---@class DiagnosticItem
---@field bufnr number
---@field lnum number
---@field col number
---@field message string
---@field severity number
---@field source string|nil
---@field code string|nil
---@field filepath string  -- full path for internal use
---@field display_path string -- shortened path for display

local function shorten_path(filepath, single_parent_only)
  if filepath == '[No Name]' then
    return filepath
  end

  -- Always show only parent/filename format when requested
  if single_parent_only then
    local basename = vim.fn.fnamemodify(filepath, ':t')
    local parent = vim.fn.fnamemodify(filepath, ':h:t')
    if parent and parent ~= '.' and parent ~= '/' then
      return parent .. '/' .. basename
    end
    return basename
  end

  -- Try relative to cwd
  local rel = vim.fn.fnamemodify(filepath, ':.')
  if rel ~= filepath and not rel:match('^%.%.') then
    return rel
  end
  -- If outside cwd, show ~-relative or basename with parent
  local home = vim.fn.fnamemodify(filepath, ':~')
  if home ~= filepath and not home:match('^%.%.') then
    return home
  end
  -- Fallback: parent/basename
  local basename = vim.fn.fnamemodify(filepath, ':t')
  local parent = vim.fn.fnamemodify(filepath, ':h:t')
  if parent and parent ~= '.' and parent ~= '/' then
    return parent .. '/' .. basename
  end
  return basename
end

--- Gather all diagnostics from vim.diagnostic.get()
---@param current_buf_only boolean|nil If true, only get diagnostics for current buffer
function M.gather(current_buf_only)
  local all
  if current_buf_only then
    all = vim.diagnostic.get(0)
  else
    all = vim.diagnostic.get()
  end

  ---@type DiagnosticItem[]
  local items = {}
  for _, d in ipairs(all) do
    local filepath = vim.api.nvim_buf_get_name(d.bufnr)
    if filepath == '' then
      filepath = '[No Name]'
    end

    table.insert(items, {
      bufnr = d.bufnr,
      lnum = d.lnum + 1,    -- 0-indexed to 1-indexed
      col = d.col + 1,
      message = d.message or '',
      severity = d.severity or vim.diagnostic.severity.ERROR,
      source = d.source,
      code = d.code,
      filepath = filepath,
      display_path = shorten_path(filepath, current_buf_only),
    })
  end

  -- Sort by severity if enabled
  if config.get().severity_sort then
    table.sort(items, function(a, b)
      local sa = util.severity_order(a.severity)
      local sb = util.severity_order(b.severity)
      if sa ~= sb then
        return sa < sb
      end
      if a.filepath ~= b.filepath then
        return a.filepath < b.filepath
      end
      if a.lnum ~= b.lnum then
        return a.lnum < b.lnum
      end
      return a.col < b.col
    end)
  end

  return items
end

--- Gather diagnostics for current buffer only
function M.gather_current()
  return M.gather(true)
end

return M
