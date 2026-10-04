local M = {
  is_active = false,
  current_course = nil,
  current_problem = nil,
  keys_typed = {},
  start_time = nil,
  key_hook = nil,
  prev_tab = nil,
  tabpage = nil,
  edit_buf = nil,
  edit_win = nil,
  target_buf = nil,
  target_win = nil,
  status_win = nil,
  result_win = nil,
  result_buf = nil,
}

function M.reset_session()
  M.keys_typed = {}
  M.start_time = vim.loop.hrtime()
end

function M.clear()
  if M.key_hook then
    pcall(vim.on_key, nil, M.key_hook)
    M.key_hook = nil
  end
  M.is_active = false
  M.current_course = nil
  M.current_problem = nil
  M.keys_typed = {}
  M.start_time = nil
  M.tabpage = nil
  M.edit_buf = nil
  M.edit_win = nil
  M.target_buf = nil
  M.target_win = nil
  M.status_win = nil
  M.result_win = nil
  M.result_buf = nil
end

return M
