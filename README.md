# unidiagnostic.nvim

A simple, Colemak-friendly Neovim plugin to view all LSP / built-in diagnostics in a floating window.

## Features

- **All buffers**: Shows diagnostics from all open buffers
- **Grouped by file**: Diagnostics are grouped under their file path
- **Fold / unfold**: Retract files with too many errors to navigate faster
- **Short paths**: File names shown relative to cwd, not full absolute paths
- **Severity sorted**: Errors first, then warnings, info, hints
- **Configurable keys**: Customizable keymaps for actions
- **Auto-refresh**: Updates automatically on `DiagnosticChanged` and `BufWritePost`
- **Jump to error**: Press `<CR>` on any diagnostic to jump to it and open the diagnostic float at that location
- **Customizable position**: Center (default), or any corner of the screen

## Installation

### lazy.nvim
```lua
{
  'sheymor/unidiagnostic.nvim',
  config = function()
    require('unidiagnostic').setup()
  end,
}
```

### packer.nvim
```lua
use {
  'sheymor/unidiagnostic.nvim',
  config = function()
    require('unidiagnostic').setup()
  end,
}
```

## Configuration

```lua
require('unidiagnostic').setup({
  -- Window position
  position = 'center',       -- 'center' | 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right'
  width = 80,
  height = 20,
  border = 'rounded',

  -- Navigation keys (fully customizable)
  keys = {
    open       = '<CR>', -- jump to diagnostic location
    close      = 'q',    -- close window
    fold       = 'h',    -- toggle fold / retract file group
    search     = 's',    -- telescope search diagnostics in file under cursor
    search_all = 'S',    -- telescope search all diagnostics
  },

  -- Window highlights (blend with editor, nil = Neovim defaults)
  winhighlight = 'Normal:Normal,FloatBorder:VertSplit,FloatTitle:Title',

  -- Behavior
  auto_refresh      = true,
  severity_sort     = true, -- Error > Warn > Info > Hint
  fold_by_default   = true, -- start with all file groups collapsed

  -- Reserved for future scanner (ignored now)
  scanner = {
    enabled = false,
  },
})
```

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `:UnidiagnosticToggle` | Open or close the diagnostic window (all buffers) |
| `:UnidiagnosticCurrent` | Toggle diagnostics window for current file only |
| `:UnidiagnosticRefresh` | Manually refresh the window content |

**Note**: The all-buffers window (`:UnidiagnosticToggle`) and current-file window (`:UnidiagnosticCurrent`) are completely independent - you can have both open at the same time, or either one individually. Use `q` or `<Esc>` inside either window to close it.

If no diagnostics exist when opening, a notification is shown instead of an empty window.

### Default Keymaps (inside the float)

| Key | Action |
|-----|--------|
| `<CR>` | Jump to the diagnostic under cursor |
| `h` | Toggle fold / retract file group |
| `s` | Telescope search diagnostics in file under cursor |
| `S` | Telescope search all diagnostics |
| `q` | Close window |
| `<Esc>` | Close window |

## Display Format

### All Buffers (`:UnidiagnosticToggle`)
```
(1) e, (1) w
▸ lua/plugins/init.lua

(3) e, (2) w, (1) s
▸ src/core/engine.ts

(1) e
▾ init.lua
  [e]  3:1    Cannot find name 'console'
```

### Current File Only (`:UnidiagnosticCurrent`)
```
(2) e ▾ utils/path.lua
  [e]  15:8    Missing return type
  [e]  42:3    Undefined variable
```

- Counts shown **beside** the filename (inline, same line)
- Only `parent/filename` format shown (no full paths)
- `▾` — always expanded (no fold needed for single file)
- Severity letters in counts are colored: `e` error, `w` warn, `i` info, `s` suggest/hint
- `[e]` / `[w]` / `[i]` / `[s]` — colored by severity
- `line:column` — exact position
- Message — the diagnostic text
- Cursor automatically positioned at first diagnostic
- Buffer `filetype` is set to `unidiagnostic` for custom highlights or ftplugin hooks

## Future: Project Scanner

The architecture includes a reserved `scanner` config section. In the future, this will allow running external tools (e.g., `eslint`, `tsc`, `cargo check`) to populate diagnostics for unopened files, giving true project-wide coverage beyond what LSP provides.

## License

MIT
