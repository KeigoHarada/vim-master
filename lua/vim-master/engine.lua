local state = require("vim-master.state")
local ui = require("vim-master.ui")
local storage = require("vim-master.storage")
local loader = require("vim-master.courses.loader")

local M = {}

-- キーコードを可読な文字列（<Esc>, <CR>等）に変換するヘルパー
local function format_key(key)
  if not key or key == "" then
    return ""
  end

  local byte = string.byte(key)
  if byte == 27 then
    return "<Esc>"
  elseif byte == 13 or key == "\r" or key == "\n" then
    return "<CR>"
  elseif byte == 9 or key == "\t" then
    return "<Tab>"
  elseif byte == 8 or byte == 127 then
    return "<BS>"
  elseif byte == 32 then
    return " "
  elseif byte < 32 then
    return string.format("<C-%c>", byte + 64)
  end
  return key
end

local function format_keys_typed(keys)
  local parts = {}
  for _, k in ipairs(keys) do
    table.insert(parts, format_key(k))
  end
  return table.concat(parts, "")
end

-- キーフックの開始
local function start_key_monitoring()
  if state.key_hook then
    pcall(vim.on_key, nil, state.key_hook)
    state.key_hook = nil
  end

  state.key_hook = vim.on_key(function(key)
    if not state.is_active or state.result_win then
      return
    end

    -- 編集バッファにフォーカスがある時のみ打鍵をカウント
    local current_win = vim.api.nvim_get_current_win()
    if current_win == state.edit_win then
      table.insert(state.keys_typed, key)
      -- リアルタイムステータス更新
      vim.schedule(function()
        if state.is_active and not state.result_win then
          ui.update_status(#state.keys_typed)
        end
      end)
    end
  end)
end

-- 問題の開始
local function launch_problem(problem)
  state.reset_session()
  ui.render_problem(problem)
  ui.update_status(0)
end

-- 次の問題へ
function M.next_problem()
  if not state.current_course then
    return
  end
  local next_p = loader.pick_problem(state.current_course, state.current_problem and state.current_problem.id)
  if next_p then
    launch_problem(next_p)
  end
end

-- 同じ問題をリトライ
function M.retry_current()
  if state.current_problem then
    launch_problem(state.current_problem)
  end
end

-- Submit判定
function M.submit()
  if not state.is_active or not state.current_problem or not state.edit_buf then
    return
  end

  local current_lines = vim.api.nvim_buf_get_lines(state.edit_buf, 0, -1, false)
  local current_text = table.concat(current_lines, "\n")
  local target_text = state.current_problem.target or ""

  -- テキストの一致判定
  if current_text == target_text then
    local end_time = vim.loop.hrtime()
    local elapsed_ns = end_time - (state.start_time or end_time)
    local elapsed_sec = elapsed_ns / 1e9
    local elapsed_ms = math.floor(elapsed_sec * 1000)
    local keys_count = #state.keys_typed

    -- 学習履歴の保存
    storage.record_attempt(
      state.current_problem.id,
      keys_count,
      elapsed_ms,
      true,
      state.current_problem.ideal_count
    )

    local stats = {
      keys_count = keys_count,
      ideal_count = state.current_problem.ideal_count or 0,
      time_sec = elapsed_sec,
      your_keys_str = format_keys_typed(state.keys_typed),
    }

    ui.show_result(state.current_problem, stats, {
      on_retry = function()
        M.retry_current()
      end,
      on_next = function()
        M.next_problem()
      end,
      on_quit = function()
        M.stop()
      end,
    })
  else
    ui.notify_not_match()
  end
end

-- コースの開始
function M.start(course)
  state.clear()
  state.is_active = true
  state.current_course = course

  -- ドリル画面（スプリット）作成
  ui.setup_drill_screen(
    function()
      M.submit()
    end,
    function()
      M.retry_current()
    end,
    function()
      M.stop()
    end
  )

  -- キー監視開始
  start_key_monitoring()

  -- 最初の問題を抽選して開始
  M.next_problem()
end

-- ドリル終了
function M.stop()
  if state.key_hook then
    pcall(vim.on_key, nil, state.key_hook)
    state.key_hook = nil
  end
  state.is_active = false
  ui.close_drill()
end

return M
