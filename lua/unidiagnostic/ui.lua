local M = {}

-- Store mapping from line number to diagnostic item for jump-to
M.line_to_item = {}

-- Track which file groups are collapsed
-- Key: filepath (full path), Value: true if collapsed
M.collapsed = {}

-- Track which lines are file headers (for fold detection)
-- Key: line number (1-indexed), Value: filepath
M.line_to_header = {}

-- Track which lines are severity-count lines (cursor should skip them)
-- Key: line number (1-indexed), Value: true
M.count_lines = {}

-- Buffer-local autocmd id for CursorMoved (cleared on close)
M._cursor_autocmd_id = nil

-- Last cursor line number to detect movement direction
M._last_cursor_lnum = nil

--- Create the floating window with diagnostics
---@param items table[] Diagnostic items
---@param opts table Config options
---@return number bufnr, number winid
function M.create(items, opts)
  local bufnr = vim.api.nvim_create_buf(false, true)
  local winid = M._open_float(bufnr, opts)

  -- Initialize fold state: collapse all groups if fold_by_default is true
  M.collapsed = {}
  if opts.fold_by_default then
    for _, item in ipairs(items) do
      M.collapsed[item.filepath] = true
    end
  end

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
  if M._cursor_autocmd_id then
    pcall(vim.api.nvim_del_autocmd, M._cursor_autocmd_id)
    M._cursor_autocmd_id = nil
  end
  M._last_cursor_lnum = nil
  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_close(winid, true)
  end
end

--- Toggle fold state for a file group
---@param filepath string Full filepath
function M.toggle_fold(filepath)
  if M.collapsed[filepath] then
    M.collapsed[filepath] = nil
  else
    M.collapsed[filepath] = true
  end
end

--- Check if a line is a file header
---@param lnum number 1-indexed line number
---@return string|nil filepath if header, nil otherwise
function M.get_header_at_line(lnum)
  return M.line_to_header[lnum]
end

--- Render diagnostics into the buffer
---@param bufnr number
---@param items table[] Diagnostic items
function M._render(bufnr, items)
  local lines = {}
  local highlights = {}
  M.line_to_item = {}
  M.line_to_header = {}
  M.count_lines = {}

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
    local is_collapsed = M.collapsed[filepath]
    local items_in_group = grouped[filepath]
    local display_path = items_in_group[1].display_path
    local fold_icon = is_collapsed and '▸' or '▾'

    -- Count severity breakdown
    local sev_counts = {}
    for _, item in ipairs(items_in_group) do
      local char = diagnostics_mod.get_severity_char(item.severity)
      sev_counts[char] = (sev_counts[char] or 0) + 1
    end
    -- Build count string in priority order: e, w, i, s
    -- Format: (2) e, (3) w, (4) i, (5) s
    local count_parts = {}
    for _, sev_char in ipairs({ 'e', 'w', 'i', 's' }) do
      if sev_counts[sev_char] then
        table.insert(count_parts, '(' .. sev_counts[sev_char] .. ') ' .. sev_char)
      end
    end
    local counts_text = table.concat(count_parts, ', ')

    -- Counts line (above the filename, with colored severity counts)
    table.insert(lines, counts_text)
    local counts_line_idx = #lines - 1
    -- Highlight entire (N) x segment for each severity
    local cursor = 0
    for _, sev_char in ipairs({ 'e', 'w', 'i', 's' }) do
      if sev_counts[sev_char] then
        local count_str = '(' .. sev_counts[sev_char] .. ') ' .. sev_char
        local sev = nil
        if sev_char == 'e' then sev = vim.diagnostic.severity.ERROR
        elseif sev_char == 'w' then sev = vim.diagnostic.severity.WARN
        elseif sev_char == 'i' then sev = vim.diagnostic.severity.INFO
        elseif sev_char == 's' then sev = vim.diagnostic.severity.HINT
        end
        table.insert(highlights, {
          line = counts_line_idx,
          col = cursor,
          end_col = cursor + #count_str,
          hl = M._severity_to_hl(sev),
        })
        cursor = cursor + #count_str + 2  -- +2 for ", " separator
      end
    end
    M.line_to_item[#lines] = nil
    M.line_to_header[#lines] = nil
    M.count_lines[#lines] = true

    -- Filename line with fold icon
    local header_text = fold_icon .. ' ' .. display_path
    table.insert(lines, header_text)
    table.insert(highlights, { line = #lines - 1, col = 0, end_col = 2, hl = 'FoldColumn' })
    table.insert(highlights, { line = #lines - 1, col = 3, end_col = 3 + #display_path, hl = 'Directory' })
    M.line_to_item[#lines] = nil  -- header line, not clickable
    M.line_to_header[#lines] = filepath

    if not is_collapsed then
      for _, item in ipairs(items_in_group) do
        local sev_char = diagnostics_mod.get_severity_char(item.severity)
        local line_text = string.format('  [%s]  %d:%d  %s', sev_char, item.lnum, item.col, item.message)
        table.insert(lines, line_text)

        -- Severity highlight for the [e] part
        local sev_hl = M._severity_to_hl(item.severity)
        table.insert(highlights, { line = #lines - 1, col = 2, end_col = 5, hl = sev_hl })

        M.line_to_item[#lines] = item
      end
    end

  end

  vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })

  -- Apply highlights
  local ns = vim.api.nvim_create_namespace('unidiagnostic')
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(bufnr, ns, hl.hl, hl.line, hl.col, hl.end_col)
  end

  -- Set buffer options
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
  if opts.winhighlight then
    vim.api.nvim_set_option_value('winhighlight', opts.winhighlight, { win = winid })
  end

  -- Skip count lines when cursor lands on them
  M._last_cursor_lnum = nil
  M._cursor_autocmd_id = vim.api.nvim_create_autocmd('CursorMoved', {
    buffer = bufnr,
    callback = function()
      local cursor = vim.api.nvim_win_get_cursor(winid)
      local lnum = cursor[1]
      local prev = M._last_cursor_lnum or lnum
      M._last_cursor_lnum = lnum

      if M.count_lines[lnum] then
        if prev < lnum then
          -- moved down onto count line: push down to filename line below
          vim.api.nvim_win_set_cursor(winid, { lnum + 1, 0 })
        else
          -- moved up onto count line: push up, or down if at top
          local target = math.max(1, lnum - 1)
          if target == lnum then
            target = lnum + 1
          end
          vim.api.nvim_win_set_cursor(winid, { target, 0 })
        end
      end
    end,
  })

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
