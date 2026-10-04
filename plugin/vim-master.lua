if vim.g.loaded_vim_master == 1 then
  return
end
vim.g.loaded_vim_master = 1

vim.api.nvim_create_user_command("VimMaster", function(opts)
  require("vim-master").open(opts.args)
end, {
  nargs = "?",
  complete = function(arglead)
    local candidates = { "stats" }
    local ok, loader = pcall(require, "vim-master.courses.loader")
    if ok then
      for _, c in ipairs(loader.get_courses()) do
        table.insert(candidates, c.id)
      end
    end
    return vim.tbl_filter(function(item)
      return vim.startswith(item, arglead)
    end, candidates)
  end,
  desc = "Start VimMaster drill session or view stats",
})

