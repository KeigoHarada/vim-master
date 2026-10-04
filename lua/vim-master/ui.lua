local config = require("vim-master.config")
local state = require("vim-master.state")
local storage = require("vim-master.storage")

local M = {}

-- ハイライトネームスペース
local ns_id = vim.api.nvim_create_namespace("vim_master_menu")

-- 汎用: フローティングウィンドウの作成ヘルパー
local function create_float(opts)
  local width = opts.width or math.floor(vim.o.columns * 0.6)
  local height = opts.height or math.floor(vim.o.lines * 0.5)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = opts.border or config.options.ui.border or "rounded",
    title = opts.title,
    title_pos = "center",
  })

  vim.wo[win].wrap = true
  vim.wo[win].breakindent = true

  return buf, win
end

-- 全角・半角混在テキストの自動折り返しヘルパー
local function wrap_text(text, max_width, prefix)
  prefix = prefix or ""
  local lines = {}
  local raw_lines = vim.split(text or "", "\n", { plain = true })

  for _, raw_line in ipairs(raw_lines) do
    if vim.fn.strdisplaywidth(raw_line) <= max_width then
      table.insert(lines, prefix .. raw_line)
    else
      local cur_line = ""
      for char in raw_line:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if vim.fn.strdisplaywidth(cur_line .. char) > max_width then
          table.insert(lines, prefix .. cur_line)
          cur_line = char
        else
          cur_line = cur_line .. char
        end
      end
      if cur_line ~= "" then
        table.insert(lines, prefix .. cur_line)
      end
    end
  end

  return lines
end


-- 1. 起動画面: テーマ選択ウィンドウ（リッチ版）
function M.show_menu(courses, on_select)
  storage.load()
  local total_keys = storage.data.total_keys or 0

  local selected_idx = 1
  local width = 64
  local item_line_map = {} -- course_idx -> line_number (0-indexed)

  local function build_content(sel)
    local lines = {}
    local highlights = {} -- { line, hl_group, col_start, col_end }

    -- ヘッダー
    table.insert(lines, "")
    table.insert(lines, "   VimMaster")
    table.insert(highlights, { #lines - 1, "Title", 3, -1 })
    table.insert(lines, "   達人までの道筋")
    table.insert(highlights, { #lines - 1, "Comment", 3, -1 })
    table.insert(lines, "  ──────────────────────────────────────────────────────────")
    table.insert(highlights, { #lines - 1, "Comment", 2, -1 })
    table.insert(lines, "")

    -- コースリスト
    item_line_map = {}
    for i, c in ipairs(courses) do
      local is_selected = (i == sel)
      local prefix = is_selected and "▶  " or "   "
      local title_line = string.format(" %s%d. %s", prefix, i, c.name)
      table.insert(lines, title_line)
      item_line_map[i] = #lines - 1

      if is_selected then
        table.insert(highlights, { #lines - 1, "Directory", 1, -1 }) -- 選択中は落ち着いた色で一括表示
      else
        table.insert(highlights, { #lines - 1, "Normal", 1, -1 })
      end

      if c.description and c.description ~= "" then
        local desc_line = string.format("       %s", c.description)
        table.insert(lines, desc_line)
        table.insert(highlights, { #lines - 1, "Comment", 7, -1 })
      end
      table.insert(lines, "")
    end

    -- フッター
    table.insert(lines, "  ──────────────────────────────────────────────────────────")
    table.insert(highlights, { #lines - 1, "Comment", 2, -1 })
    table.insert(lines, "   <Enter>: Select    j/k: Move    1-5: Direct    s: Stats    q: Quit")
    table.insert(highlights, { #lines - 1, "SpecialKey", 3, -1 })
    table.insert(lines, "")

    return lines, highlights
  end

  local initial_lines = build_content(selected_idx)
  local height = math.min(#initial_lines, vim.o.lines - 4)

  local buf, win = create_float({
    width = width,
    height = height,
    title = " Course Select ",
  })

  vim.wo[win].cursorline = false -- 矢印とカスタムハイライトを使うためシンプルに

  local function redraw()
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    vim.bo[buf].modifiable = true
    local lines, highlights = build_content(selected_idx)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    -- ハイライトの適用
    vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
    for _, hl in ipairs(highlights) do
      vim.api.nvim_buf_add_highlight(buf, ns_id, hl[2], hl[1], hl[3], hl[4])
    end

    -- 選択行にカーソルを合わせる
    local target_line = (item_line_map[selected_idx] or 4) + 1
    pcall(vim.api.nvim_win_set_cursor, win, { target_line, 1 })
  end

  redraw()

  local function close_menu()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  -- キーマップ: 移動 (j/k)
  vim.keymap.set("n", "j", function()
    if selected_idx < #courses then
      selected_idx = selected_idx + 1
      redraw()
    end
  end, { buffer = buf, nowait = true })

  vim.keymap.set("n", "k", function()
    if selected_idx > 1 then
      selected_idx = selected_idx - 1
      redraw()
    end
  end, { buffer = buf, nowait = true })

  -- 番号キーでのダイレクトジャンプ (1-9)
  for num = 1, math.min(#courses, 9) do
    vim.keymap.set("n", tostring(num), function()
      selected_idx = num
      redraw()
    end, { buffer = buf, nowait = true })
  end

  -- 統計画面の表示 (s)
  vim.keymap.set("n", "s", function()
    close_menu()
    M.show_stats()
  end, { buffer = buf, nowait = true })

  -- 決定
  vim.keymap.set("n", "<CR>", function()
    close_menu()
    if courses[selected_idx] then
      on_select(courses[selected_idx])
    end
  end, { buffer = buf, nowait = true })

  -- 終了
  vim.keymap.set("n", "q", close_menu, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", close_menu, { buffer = buf, nowait = true })
end



-- 2. ドリル画面の構築（左右スプリット）
function M.setup_drill_screen(on_submit, on_reset, on_quit)
  state.prev_tab = vim.api.nvim_get_current_tabpage()
  vim.cmd("tabnew")
  state.tabpage = vim.api.nvim_get_current_tabpage()

  -- 左: 編集用バッファ
  state.edit_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.edit_buf].buftype = "nofile"
  vim.bo[state.edit_buf].bufhidden = "wipe"
  vim.bo[state.edit_buf].swapfile = false
  state.edit_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.edit_win, state.edit_buf)
  pcall(vim.api.nvim_buf_set_name, state.edit_buf, "[EDIT]")

  -- 右: 目標テキスト用バッファ (左右スプリット)
  vim.cmd("rightbelow vsplit")
  state.target_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.target_buf].buftype = "nofile"
  vim.bo[state.target_buf].bufhidden = "wipe"
  vim.bo[state.target_buf].swapfile = false
  state.target_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.target_win, state.target_buf)
  pcall(vim.api.nvim_buf_set_name, state.target_buf, "[TARGET]")

  -- 連動スクロールと行番号の設定
  for _, win in ipairs({ state.edit_win, state.target_win }) do
    vim.wo[win].number = true
    vim.wo[win].scrollbind = true
    vim.wo[win].wrap = false
  end

  -- フォーカスを編集ウィンドウ（左）に戻す
  vim.api.nvim_set_current_win(state.edit_win)

  -- キーマップの設定 (バッファローカル)
  local keymaps = config.options.keymaps or config.defaults.keymaps

  -- Submit判定
  if keymaps.submit and keymaps.submit ~= "" then
    vim.keymap.set("n", keymaps.submit, on_submit, {
      buffer = state.edit_buf,
      nowait = true,
      desc = "VimMaster: Submit answer",
    })
  end

  -- Reset
  if keymaps.reset and keymaps.reset ~= "" then
    vim.keymap.set("n", keymaps.reset, on_reset, {
      buffer = state.edit_buf,
      nowait = true,
      desc = "VimMaster: Reset problem",
    })
  end

  -- Quit
  if keymaps.quit and keymaps.quit ~= "" then
    vim.keymap.set("n", keymaps.quit, on_quit, {
      buffer = state.edit_buf,
      nowait = true,
      desc = "VimMaster: Quit drill",
    })
  end
end

-- 3. 問題データのバッファへの展開
function M.render_problem(problem)
  state.current_problem = problem

  -- 左: 初期テキスト
  vim.bo[state.edit_buf].modifiable = true
  local init_lines = vim.split(problem.initial or "", "\n", { plain = true })
  vim.api.nvim_buf_set_lines(state.edit_buf, 0, -1, false, init_lines)

  -- 右: 正解テキスト
  vim.bo[state.target_buf].modifiable = true
  local target_lines = vim.split(problem.target or "", "\n", { plain = true })
  vim.api.nvim_buf_set_lines(state.target_buf, 0, -1, false, target_lines)
  vim.bo[state.target_buf].modifiable = false

  -- シンタックスハイライト
  if problem.filetype then
    vim.bo[state.edit_buf].filetype = problem.filetype
    vim.bo[state.target_buf].filetype = problem.filetype
  end

  -- カーソル位置の初期化
  local cursor = problem.cursor or { 1, 0 }
  pcall(vim.api.nvim_win_set_cursor, state.edit_win, { cursor[1], cursor[2] })
end


-- 4. ステータス行の更新 (リアルタイム打鍵数)
function M.update_status(keys_count)
  local keymaps = config.options.keymaps or config.defaults.keymaps
  local msg = string.format(
    " [Keys: %d]  %s: Submit  %s: Reset  %s: Quit",
    keys_count,
    keymaps.submit == "\r" and "<Enter>" or keymaps.submit,
    keymaps.reset,
    keymaps.quit
  )
  vim.api.nvim_echo({ { msg, "Normal" } }, false, {})
end

-- 5. 不一致時のフィードバック
function M.notify_not_match()
  vim.api.nvim_echo({ { " Not match yet", "WarningMsg" } }, false, {})
end


-- 6. リザルト画面の表示（統一デザイン版）
function M.show_result(problem, stats, callbacks)
  local lines = {}
  local highlights = {} -- { line, hl_group, col_start, col_end }

  -- ヘッダー
  table.insert(lines, "")
  table.insert(lines, "   VimMaster")
  table.insert(highlights, { #lines - 1, "Title", 3, -1 })

  table.insert(lines, "   CLEAR!")
  table.insert(highlights, { #lines - 1, "DiagnosticOk", 3, -1 })

  table.insert(lines, "  ──────────────────────────────────────────────────────────")
  table.insert(highlights, { #lines - 1, "Comment", 2, -1 })
  table.insert(lines, "")

  -- スコア
  local score_str = string.format("   Keys: %-3d (Par: %-2d)               Time: %.2fs", stats.keys_count, stats.ideal_count, stats.time_sec)
  table.insert(lines, score_str)
  table.insert(highlights, { #lines - 1, "Special", 3, -1 })
  table.insert(lines, "")

  -- キー対比
  table.insert(lines, "  ──────────────────────────────────────────────────────────")
  table.insert(highlights, { #lines - 1, "Comment", 2, -1 })

  local max_key_len = 40
  local yk_str = stats.your_keys_str or ""
  if #yk_str > max_key_len then
    yk_str = string.sub(yk_str, 1, max_key_len - 6) .. string.format("... (%d keys)", stats.keys_count)
  end

  local ik_str = problem.ideal_keys or "N/A"
  if #ik_str > max_key_len then
    ik_str = string.sub(ik_str, 1, max_key_len - 3) .. "..."
  end

  local yk_line = string.format("   Your Keys  : %s", yk_str)
  table.insert(lines, yk_line)
  table.insert(highlights, { #lines - 1, "Keyword", 3, 15 })

  local ik_line = string.format("   Ideal Keys : %s", ik_str)
  table.insert(lines, ik_line)
  table.insert(highlights, { #lines - 1, "DiagnosticOk", 3, 15 })
  table.insert(highlights, { #lines - 1, "Function", 16, -1 })

  table.insert(lines, "  ──────────────────────────────────────────────────────────")
  table.insert(highlights, { #lines - 1, "Comment", 2, -1 })
  table.insert(lines, "")

  -- 解説（自動折り返し）
  table.insert(lines, "   【解説】")
  table.insert(highlights, { #lines - 1, "Title", 3, -1 })

  local exp_lines = wrap_text(problem.explanation or "なし", 56, "   ")
  for _, el in ipairs(exp_lines) do
    table.insert(lines, el)
    table.insert(highlights, { #lines - 1, "Normal", 3, -1 })
  end
  table.insert(lines, "")

  -- フッター
  table.insert(lines, "  ──────────────────────────────────────────────────────────")
  table.insert(highlights, { #lines - 1, "Comment", 2, -1 })
  table.insert(lines, "   <Enter>/n: Next    r: Retry    q: Quit")
  table.insert(highlights, { #lines - 1, "SpecialKey", 3, -1 })
  table.insert(lines, "")

  local width = math.min(68, vim.o.columns - 4)
  local height = math.min(#lines + 1, vim.o.lines - 4)
  local buf, win = create_float({
    width = width,
    height = height,
    title = " Result ",
  })


  state.result_buf = buf
  state.result_win = win

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  -- ハイライト適用
  vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(buf, ns_id, hl[2], hl[1], hl[3], hl[4])
  end

  local function close_result()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    state.result_buf = nil
    state.result_win = nil
  end

  -- リトライ
  vim.keymap.set("n", "r", function()
    close_result()
    callbacks.on_retry()
  end, { buffer = buf, nowait = true })

  -- 次へ
  local function go_next()
    close_result()
    callbacks.on_next()
  end
  vim.keymap.set("n", "<CR>", go_next, { buffer = buf, nowait = true })
  vim.keymap.set("n", "n", go_next, { buffer = buf, nowait = true })

  -- 終了
  vim.keymap.set("n", "q", function()
    close_result()
    callbacks.on_quit()
  end, { buffer = buf, nowait = true })
end


-- 7. ドリルの終了と画面復帰
function M.close_drill()
  if state.tabpage and vim.api.nvim_tabpage_is_valid(state.tabpage) then
    vim.cmd("tabclose")
  end
  state.clear()
end

-- 8. 学習統計・進捗の表示
function M.show_stats()
  storage.load()
  local loader = require("vim-master.courses.loader")
  local courses = loader.get_courses()

  local lines = {}
  local highlights = {}

  table.insert(lines, "")
  table.insert(lines, "   VimMaster")
  table.insert(highlights, { #lines - 1, "Title", 3, -1 })
  table.insert(lines, "   学習記録")
  table.insert(highlights, { #lines - 1, "Comment", 3, -1 })
  table.insert(lines, "  ──────────────────────────────────────────────────────────")
  table.insert(highlights, { #lines - 1, "Comment", 2, -1 })
  table.insert(lines, "")

  local total_keys = storage.data.total_keys or 0
  local total_cleared = 0
  local total_problems = 0

  for _, c in ipairs(courses) do
    for _, p in ipairs(c.problems or {}) do
      total_problems = total_problems + 1
      local stat = storage.data.problems[p.id]
      if stat and stat.cleared_count and stat.cleared_count > 0 then
        total_cleared = total_cleared + 1
      end
    end
  end

  table.insert(lines, string.format("   Total Practice : %s Keys", vim.fn.printf("%'d", total_keys)))
  table.insert(highlights, { #lines - 1, "Special", 3, -1 })

  table.insert(lines, string.format("   Cleared        : %d / %d Problems", total_cleared, total_problems))
  table.insert(highlights, { #lines - 1, "Directory", 3, -1 })
  table.insert(lines, "")

  table.insert(lines, "  ──────────────────────────────────────────────────────────")
  table.insert(highlights, { #lines - 1, "Comment", 2, -1 })
  table.insert(lines, "   [問題別 ベスト記録]")
  table.insert(highlights, { #lines - 1, "Title", 3, -1 })
  table.insert(lines, "")

  for _, c in ipairs(courses) do
    table.insert(lines, string.format("   ■ %s", c.name))
    table.insert(highlights, { #lines - 1, "Function", 3, -1 })

    for _, p in ipairs(c.problems or {}) do
      local stat = storage.data.problems[p.id]
      if stat and stat.cleared_count and stat.cleared_count > 0 then
        local time_str = stat.best_time_ms and string.format("%.2fs", stat.best_time_ms / 1000) or "N/A"
        local p_line = string.format("     • %-18s Best: %2d keys (Par: %2d)  Time: %s", p.title, stat.best_keys or 0, p.ideal_count or 0, time_str)
        table.insert(lines, p_line)
        table.insert(highlights, { #lines - 1, "Normal", 5, -1 })
      else
        local p_line = string.format("     • %-18s [未クリア]", p.title)
        table.insert(lines, p_line)
        table.insert(highlights, { #lines - 1, "Comment", 5, -1 })
      end
    end
    table.insert(lines, "")
  end

  table.insert(lines, "  ──────────────────────────────────────────────────────────")
  table.insert(highlights, { #lines - 1, "Comment", 2, -1 })
  table.insert(lines, "   j/k: Scroll    q/<Esc>: Close")
  table.insert(highlights, { #lines - 1, "SpecialKey", 3, -1 })
  table.insert(lines, "")

  local width = math.min(70, vim.o.columns - 4)
  local height = math.min(#lines, vim.o.lines - 4)
  local buf, win = create_float({
    width = width,
    height = height,
    title = " Statistics ",
  })

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  -- ハイライト適用
  vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(buf, ns_id, hl[2], hl[1], hl[3], hl[4])
  end

  local function close_stats()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.keymap.set("n", "q", close_stats, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", close_stats, { buffer = buf, nowait = true })
end

return M

