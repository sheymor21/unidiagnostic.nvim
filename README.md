# unidiagnostic.nvim

A simple, Colemak-friendly Neovim plugin to view all LSP / built-in diagnostics in a floating window.

## Features

- **All buffers**: Shows diagnostics from all open buffers
- **Grouped by file**: Diagnostics are grouped under their file path
- **Fold / unfold**: Retract files with too many errors to navigate faster
- **Short paths**: File names shown relative to cwd, not full absolute paths
- **Severity sorted**: Errors first, then warnings, info, hints
- **Colemak-friendly**: Configurable navigation keys
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

  -- Navigation keys (Colemak-friendly by default, fully customizable)
  keys = {
    up    = 'k',    -- move up
    down  = 'j',    -- move down
    open  = '<CR>', -- jump to diagnostic location
    close = 'q',    -- close window
    fold  = 'h',    -- toggle fold / retract file group
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
| `:UnidiagnosticToggle` | Open or close the diagnostic window |
| `:UnidiagnosticRefresh` | Manually refresh the window content |

If no diagnostics exist when opening, a notification is shown instead of an empty window.

### Default Keymaps (inside the float)

| Key | Action |
|-----|--------|
| `j` / `k` | Navigate down / up |
| `<CR>` | Jump to the diagnostic under cursor |
| `h` | Toggle fold / retract file group |
| `q` | Close window |
| `<Esc>` | Close window |

## Display Format

```
(1) e, (1) w
▸ lua/plugins/init.lua

(3) e, (2) w, (1) s
▸ src/core/engine.ts

(1) e
▾ init.lua
  [e]  3:1    Cannot find name 'console'
```

- `▾` / `▸` — expanded / collapsed file group
- Counts shown **above** the filename
- Severity letters in counts are colored: `e` error, `w` warn, `i` info, `s` suggest/hint
- `[e]` / `[w]` / `[i]` / `[s]` — colored by severity
- `line:column` — exact position
- Message — the diagnostic text
- Cursor automatically skips severity-count lines when navigating with `j`/`k`
- Buffer `filetype` is set to `unidiagnostic` for custom highlights or ftplugin hooks

## Future: Project Scanner

The architecture includes a reserved `scanner` config section. In the future, this will allow running external tools (e.g., `eslint`, `tsc`, `cargo check`) to populate diagnostics for unopened files, giving true project-wide coverage beyond what LSP provides.

## License

MIT
