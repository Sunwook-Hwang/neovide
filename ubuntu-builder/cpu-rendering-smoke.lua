vim.o.guifont = "DejaVu Sans Mono:h18"
vim.o.swapfile = false
vim.o.number = true
vim.o.laststatus = 2
vim.o.statusline = " CPU RENDERING | llvmpipe | glibc 2.28 | Neovim "
vim.api.nvim_set_hl(0, "Normal", { fg = "#e8edf5", bg = "#182b49" })
vim.api.nvim_set_hl(0, "StatusLine", { fg = "#102030", bg = "#64dca0" })
vim.api.nvim_set_hl(0, "LineNr", { fg = "#f4c36a", bg = "#182b49" })

vim.defer_fn(function()
  assert(vim.g.neovide, "Neovide did not attach")
  local uis = vim.api.nvim_list_uis()
  assert(#uis == 1 and uis[1].rgb and uis[1].width > 0 and uis[1].height > 0)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "Neovide CPU rendering verification",
    "",
    "Renderer: Mesa llvmpipe (CPU)",
    "GPU devices: none",
    "Runtime: AlmaLinux 8 / glibc 2.28",
    "Editor: official Neovim 0.11.5",
    "",
    "Text, cursor, window splits and redraw are active.",
    "Unicode: café — λ → ✓",
  })
  vim.cmd("vsplit")
  vim.api.nvim_win_set_cursor(0, { 8, 0 })
  vim.cmd("redraw!")
  vim.defer_fn(function()
    local report = {
      neovide_attached = vim.g.neovide,
      ui = vim.api.nvim_list_uis()[1],
      windows = #vim.api.nvim_list_wins(),
      text = vim.api.nvim_buf_get_lines(0, 0, -1, false),
      editor_version = vim.version(),
    }
    assert(report.windows == 2)
    vim.fn.writefile({ vim.fn.json_encode(report) }, vim.env.NEOVIDE_CPU_REPORT)
    vim.defer_fn(function() vim.cmd("qa!") end, 7000)
  end, 2000)
end, 1000)
