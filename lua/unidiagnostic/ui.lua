local util = require('unidiagnostic.util')

local M = {}

-- Track which file groups are collapsed
-- Key: filepath (full path), Value: true if collapsed
M.collapsed = {}

--- Shift all keys in a line-indexed table by an offset
---@param map table<number, any>
---@param offset number
---@return table<number, any>
local function shift_line_map(map, offset)
  local shifted = {}
  for lnum, val in pairs(map) do
    shifted[lnum + offset] = val
  end
  return shifted
end

--- Apply rendered content to a buffer
---@param bufnr number
---@param lines string[]
---@param highlights table[]
---@param line_to_item table<number, table>
---@param line_to_header table<number, string>
---@param virt_lines_map table<number, table>|nil
local function apply_buffer_content(bufnr, lines, highlights, line_to_item, line_to_header, virt_lines_map)
  vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })

  local ns = vim.api.nvim_create_namespace('unidiagnostic')
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(bufnr, ns, hl.hl, hl.line, hl.col, hl.end_col)
  end

  if virt_lines_map then
    for line_idx, virt_line in pairs(virt_lines_map) do
      vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, 0, {
        virt_lines = { virt_line },
        virt_lines_above = true,
      })
    end
  end

  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
  vim.api.nvim_set_option_value('filetype', 'unidiagnostic', { buf = bufnr })

  vim.b[bufnr].unidiagnostic_line_data = {
    line_to_item = line_to_item,
    line_to_header = line_to_header,
  }
end

--- Create the floating window with diagnostics (current file, inline counts)
---@param items table[] Diagnostic items
---@param opts table Config options
---@return number bufnr, number winid
function M.create_current(items, opts)
  local bufnr = vim.api.nvim_create_buf(false, true)
  local winid = M._open_float(bufnr, opts)

  M._render_current(bufnr, items)
  M._set_cursor_to_first_item(winid, bufnr)

  return bufnr, winid
end

--- Create the floating window with diagnostics (all buffers, virtual lines above)
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
  M._set_cursor_to_first_actionable(winid, bufnr)

  return bufnr, winid
end

--- Update the content of an existing window (current file, inline counts)
---@param bufnr number
---@param items table[] Diagnostic items
function M.update_current(bufnr, items)
  M._render_current(bufnr, items)
end

--- Update the content of an existing window (all buffers, virtual lines)
---@param bufnr number
---@param items table[] Diagnostic items
function M.update(bufnr, items)
  M._render(bufnr, items)
end

--- Close the floating window
---@param winid number|nil
function M.close(winid)
  if winid and vim.api.nvim_win_is_valid(winid) then
    local bufnr = vim.api.nvim_win_get_buf(winid)
    vim.b[bufnr].unidiagnostic_line_data = nil
    vim.api.nvim_win_close(winid, true)
  end
end

--- Toggle fold state for a file group
---@param filepath string Full filepath
function M.toggle_fold(filepath)
  M.collapsed[filepath] = not M.collapsed[filepath] or nil
end

--- Check if a line is a file header
---@param lnum number 1-indexed line number
---@param bufnr number|nil buffer number (defaults to current)
---@return string|nil filepath if header, nil otherwise
function M.get_header_at_line(lnum, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local data = vim.b[bufnr].unidiagnostic_line_data or {}
  return data.line_to_header and data.line_to_header[lnum] or nil
end

--- Get the diagnostic item for a given line number
---@param lnum number 1-indexed line number
---@param bufnr number|nil buffer number (defaults to current)
---@return table|nil
function M.get_item_at_line(lnum, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local data = vim.b[bufnr].unidiagnostic_line_data or {}
  return data.line_to_item and data.line_to_item[lnum] or nil
end

--- Set cursor to the first diagnostic line
---@param winid number
---@param bufnr number
function M._set_cursor_to_first_item(winid, bufnr)
  vim.schedule(function()
    if not vim.api.nvim_win_is_valid(winid) then
      return
    end
    local data = vim.b[bufnr].unidiagnostic_line_data or {}
    if data.line_to_item then
      for lnum, _ in pairs(data.line_to_item) do
        vim.api.nvim_win_set_cursor(winid, { lnum, 0 })
        break
      end
    end
  end)
end

--- Set cursor to the first actionable line (header or diagnostic)
---@param winid number
---@param bufnr number
function M._set_cursor_to_first_actionable(winid, bufnr)
  vim.schedule(function()
    if not vim.api.nvim_win_is_valid(winid) then
      return
    end

    local data = vim.b[bufnr].unidiagnostic_line_data or {}
    local actionable_lines = {}

    if data.line_to_header then
      for lnum, _ in pairs(data.line_to_header) do
        actionable_lines[lnum] = true
      end
    end
    if data.line_to_item then
      for lnum, _ in pairs(data.line_to_item) do
        actionable_lines[lnum] = true
      end
    end

    local target_lnum = nil
    for lnum, _ in pairs(actionable_lines) do
      if not target_lnum or lnum < target_lnum then
        target_lnum = lnum
      end
    end

    if target_lnum then
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      while target_lnum <= #lines and (not lines[target_lnum] or lines[target_lnum] == '') do
        local next_lnum = nil
        for lnum, _ in pairs(actionable_lines) do
          if lnum > target_lnum and (not next_lnum or lnum < next_lnum) then
            next_lnum = lnum
          end
        end
        target_lnum = next_lnum
        if not target_lnum then
          break
        end
      end
    end

    if target_lnum then
      vim.api.nvim_win_set_cursor(winid, { target_lnum, 0 })
    end
  end)
end

--- Render diagnostics into the buffer for current file (inline counts beside filename)
---@param bufnr number
---@param items table[] Diagnostic items
function M._render_current(bufnr, items)
  local lines = {}
  local highlights = {}
  local line_to_item = {}
  local line_to_header = {}

  -- Group by filepath (will be only one group for current file)
  local grouped = {}
  for _, item in ipairs(items) do
    grouped[item.filepath] = grouped[item.filepath] or {}
    table.insert(grouped[item.filepath], item)
  end

  for filepath, items_in_group in pairs(grouped) do
    local display_path = items_in_group[1].display_path

    -- Count severity breakdown
    local sev_counts = {}
    for _, item in ipairs(items_in_group) do
      local char = util.get_severity_char(item.severity)
      sev_counts[char] = (sev_counts[char] or 0) + 1
    end

    -- Build counts inline (beside filename)
    local count_parts = {}
    local first = true
    for _, sev_char in ipairs(util.severity_chars) do
      if sev_counts[sev_char] then
        if not first then
          table.insert(count_parts, ', ')
        end
        first = false
        table.insert(count_parts, '(' .. sev_counts[sev_char] .. ') ' .. sev_char)
      end
    end

    local counts_text = table.concat(count_parts, '')
    local header_text = counts_text .. ' ▾ ' .. display_path
    table.insert(lines, header_text)
    local header_line_idx = #lines - 1

    -- Calculate highlight positions
    local col_pos = 0
    for _, sev_char in ipairs(util.severity_chars) do
      if sev_counts[sev_char] then
        if col_pos > 0 then
          col_pos = col_pos + 2 -- ', '
        end
        local count_str = '(' .. sev_counts[sev_char] .. ') ' .. sev_char
        local sev = util.char_to_severity(sev_char)
        table.insert(highlights, { line = header_line_idx, col = col_pos, end_col = col_pos + #count_str, hl = util.severity_to_hl(sev) })
        col_pos = col_pos + #count_str
      end
    end

    -- Fold icon and filename highlights
    table.insert(highlights, { line = header_line_idx, col = col_pos + 1, end_col = col_pos + 3, hl = 'FoldColumn' })
    table.insert(highlights, { line = header_line_idx, col = col_pos + 4, end_col = col_pos + 4 + #display_path, hl = 'Directory' })
    line_to_header[#lines] = filepath

    -- Always expanded for current file (no fold needed)
    for _, item in ipairs(items_in_group) do
      local sev_char = util.get_severity_char(item.severity)
      local line_text = string.format('  [%s]  %d:%d  %s', sev_char, item.lnum, item.col, item.message)
      table.insert(lines, line_text)

      local sev_hl = util.severity_to_hl(item.severity)
      table.insert(highlights, { line = #lines - 1, col = 2, end_col = 5, hl = sev_hl })

      line_to_item[#lines] = item
    end
  end

  apply_buffer_content(bufnr, lines, highlights, line_to_item, line_to_header)
end

--- Render diagnostics into the buffer
---@param bufnr number
---@param items table[] Diagnostic items
function M._render(bufnr, items)
  local lines = {}
  local highlights = {}
  local line_to_item = {}
  local line_to_header = {}
  local virt_lines_map = {}

  -- Group by filepath
  local grouped = {}
  for _, item in ipairs(items) do
    grouped[item.filepath] = grouped[item.filepath] or {}
    table.insert(grouped[item.filepath], item)
  end

  -- Sort filepaths for consistent ordering
  local filepaths = vim.tbl_keys(grouped)
  table.sort(filepaths)

  for _, filepath in ipairs(filepaths) do
    local is_collapsed = M.collapsed[filepath]
    local items_in_group = grouped[filepath]
    local display_path = items_in_group[1].display_path
    local fold_icon = is_collapsed and '▸' or '▾'

    -- Count severity breakdown
    local sev_counts = {}
    for _, item in ipairs(items_in_group) do
      local char = util.get_severity_char(item.severity)
      sev_counts[char] = (sev_counts[char] or 0) + 1
    end

    -- Build virtual count line to display above the header
    local virt_line = {}
    local first = true
    for _, sev_char in ipairs(util.severity_chars) do
      if sev_counts[sev_char] then
        if not first then
          table.insert(virt_line, { ', ', 'Normal' })
        end
        first = false
        local count_str = '(' .. sev_counts[sev_char] .. ') ' .. sev_char
        local sev = util.char_to_severity(sev_char)
        table.insert(virt_line, { count_str, util.severity_to_hl(sev) })
      end
    end

    -- Filename line with fold icon
    local header_text = fold_icon .. ' ' .. display_path
    table.insert(lines, header_text)
    local header_line_idx = #lines - 1

    -- Store virtual count line above this header
    if #virt_line > 0 then
      virt_lines_map[header_line_idx] = virt_line
    end

    table.insert(highlights, { line = header_line_idx, col = 0, end_col = 2, hl = 'FoldColumn' })
    table.insert(highlights, { line = header_line_idx, col = 3, end_col = 3 + #display_path, hl = 'Directory' })
    line_to_header[#lines] = filepath

    if not is_collapsed then
      for _, item in ipairs(items_in_group) do
        local sev_char = util.get_severity_char(item.severity)
        local line_text = string.format('  [%s]  %d:%d  %s', sev_char, item.lnum, item.col, item.message)
        table.insert(lines, line_text)

        local sev_hl = util.severity_to_hl(item.severity)
        table.insert(highlights, { line = #lines - 1, col = 2, end_col = 5, hl = sev_hl })

        line_to_item[#lines] = item
      end
    end
  end

  -- If first header has a virtual count line, insert blank line at top
  -- so virt_lines_above on line 0 is visible
  if virt_lines_map[0] then
    table.insert(lines, 1, '')
    for _, hl in ipairs(highlights) do
      hl.line = hl.line + 1
    end
    line_to_item = shift_line_map(line_to_item, 1)
    line_to_header = shift_line_map(line_to_header, 1)
    virt_lines_map = shift_line_map(virt_lines_map, 1)
  end

  apply_buffer_content(bufnr, lines, highlights, line_to_item, line_to_header, virt_lines_map)
end

--- Open a floating window with the given buffer
---@param bufnr number
---@param opts table Config options
---@return number winid
function M._open_float(bufnr, opts)
  local width = opts.width
  local height = opts.height
  local position = opts.position

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

  vim.api.nvim_set_option_value('wrap', false, { win = winid })
  vim.api.nvim_set_option_value('cursorline', true, { win = winid })
  vim.api.nvim_set_option_value('number', false, { win = winid })
  vim.api.nvim_set_option_value('relativenumber', false, { win = winid })
  if opts.winhighlight then
    vim.api.nvim_set_option_value('winhighlight', opts.winhighlight, { win = winid })
  end

  return winid
end

return M
