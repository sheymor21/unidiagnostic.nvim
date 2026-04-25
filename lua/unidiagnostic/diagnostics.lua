local config = require('unidiagnostic.config')

local M = {}

local severity_map = {
  [vim.diagnostic.severity.ERROR] = 'e',
  [vim.diagnostic.severity.WARN]  = 'w',
  [vim.diagnostic.severity.INFO]  = 'i',
  [vim.diagnostic.severity.HINT]  = 's',
}

local severity_order = {
  [vim.diagnostic.severity.ERROR] = 1,
  [vim.diagnostic.severity.WARN]  = 2,
  [vim.diagnostic.severity.INFO]  = 3,
  [vim.diagnostic.severity.HINT]  = 4,
}

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

local function shorten_path(filepath)
  if filepath == '[No Name]' then
    return filepath
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
--- Future hook: scanner module can be added here
function M.gather()
  local all = vim.diagnostic.get()

  -- TODO: Future scanner integration
  -- if config.get().scanner.enabled then
  --   local scanned = require('unidiagnostic.scanner').run()
  --   vim.list_extend(all, scanned)
  -- end

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
      display_path = shorten_path(filepath),
    })
  end

  -- Sort by severity if enabled
  if config.get().severity_sort then
    table.sort(items, function(a, b)
      local sa = severity_order[a.severity] or 99
      local sb = severity_order[b.severity] or 99
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

function M.get_severity_char(severity)
  return severity_map[severity] or '?'
end

return M
