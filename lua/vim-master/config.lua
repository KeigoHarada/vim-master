local M = {}

M.defaults = {
  keymaps = {
    submit = "<CR>",
    reset = "<C-c>r",
    quit = "<C-c>q",
  },
  ui = {
    border = "rounded",
    width_ratio = 0.5,
  },
  storage_path = vim.fn.stdpath("data") .. "/vim-master/stats.json",
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
