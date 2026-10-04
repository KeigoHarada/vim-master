if vim.g.loaded_vim_master == 1 then
  return
end
vim.g.loaded_vim_master = 1

vim.api.nvim_create_user_command("VimMaster", function(opts)
  require("vim-master").open(opts.args)
end, {
  nargs = "?",
  desc = "Start VimMaster drill session",
})
