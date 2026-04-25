local M = {}

-- Store mapping from line number to diagnostic item for jump-to
M.line_to_item = {}

--- Create the floating window with diagnostics
---@param items table[] Diagnostic items
---@param opts table Config options
---@return number bufnr, number winid
function M.create(items, opts)
  local bufnr = vim.api.nvim_create_buf(false, true)
  local winid = M._open_float(bufnr, opts)

  M._render(bufnr, items)

  return bufnr, winid
end

--- Update the content of an existing window
---@param bufnr number
---@param items table[] Diagnostic items
---@param opts table Config options
function M.update(bufnr, items, opts)
  M._render(bufnr, items)
end

--- Close the floating window
---@param winid number|nil
function M.close(winid)
  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_close(winid, true)
  end
end

--- Render diagnostics into the buffer
---@param bufnr number
---@param items table[] Diagnostic items
function M._render(bufnr, items)
  local lines = {}
  local highlights = {}
  M.line_to_item = {}

  -- Group by filepath
  local grouped = {}
  for _, item in ipairs(items) do
    if not grouped[item.filepath] then
      grouped[item.filepath] = {}
    end
    table.insert(grouped[item.filepath], item)
  end

  -- Sort filepaths for consistent ordering
  local filepaths = vim.tbl_keys(grouped)
  table.sort(filepaths)

  local diagnostics_mod = require('unidiagnostic.diagnostics')

  for _, filepath in ipairs(filepaths) do
    -- Add filepath header
    table.insert(lines, filepath)
    table.insert(highlights, { line = #lines - 1, col = 0, end_col = #filepath, hl = 'Directory' })
    M.line_to_item[#lines] = nil  -- header line, not clickable

    for _, item in ipairs(grouped[filepath]) do
      local sev_char = diagnostics_mod.get_severity_char(item.severity)
      local line_text = string.format('  [%s]  %d:%d  %s', sev_char, item.lnum, item.col, item.message)
      table.insert(lines, line_text)

      -- Severity highlight for the [E] part
      local sev_hl = M._severity_to_hl(item.severity)
      table.insert(highlights, { line = #lines - 1, col = 2, end_col = 5, hl = sev_hl })

      M.line_to_item[#lines] = item
    end

    -- Empty line between groups
    table.insert(lines, '')
    M.line_to_item[#lines] = nil
  end

  -- Remove trailing empty line
  if lines[#lines] == '' then
    table.remove(lines)
    M.line_to_item[#lines + 1] = nil
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Apply highlights
  local ns = vim.api.nvim_create_namespace('unidiagnostic')
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(bufnr, ns, hl.hl, hl.line, hl.col, hl.end_col)
  end

  -- Set buffer options
  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
  vim.api.nvim_set_option_value('filetype', 'unidiagnostic', { buf = bufnr })
end

--- Open a floating window with the given buffer
---@param bufnr number
---@param opts table Config options
---@return number winid
function M._open_float(bufnr, opts)
  local width = opts.width
  local height = opts.height
  local position = opts.position

  -- Calculate position
  local row, col
  local screen_w = vim.o.columns
  local screen_h = vim.o.lines - vim.o.cmdheight

  if position == 'center' then
    row = math.floor((screen_h - height) / 2)
    col = math.floor((screen_w - width) / 2)
  elseif position == 'top-left' then
    row = 1
    col = 1
  elseif position == 'top-right' then
    row = 1
    col = screen_w - width - 1
  elseif position == 'bottom-left' then
    row = screen_h - height - 1
    col = 1
  elseif position == 'bottom-right' then
    row = screen_h - height - 1
    col = screen_w - width - 1
  else
    -- Default to center
    row = math.floor((screen_h - height) / 2)
    col = math.floor((screen_w - width) / 2)
  end

  local win_opts = {
    relative = 'editor',
    row = row,
    col = col,
    width = width,
    height = height,
    style = 'minimal',
    border = opts.border,
    title = ' Diagnostics ',
    title_pos = 'center',
  }

  local winid = vim.api.nvim_open_win(bufnr, true, win_opts)

  -- Window options
  vim.api.nvim_set_option_value('wrap', false, { win = winid })
  vim.api.nvim_set_option_value('cursorline', true, { win = winid })
  vim.api.nvim_set_option_value('number', false, { win = winid })
  vim.api.nvim_set_option_value('relativenumber', false, { win = winid })

  return winid
end

function M._severity_to_hl(severity)
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

--- Get the diagnostic item for a given line number
---@param lnum number 1-indexed line number
---@return table|nil
function M.get_item_at_line(lnum)
  return M.line_to_item[lnum]
end

return M
