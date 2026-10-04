local config = require("vim-master.config")

local M = {
  data = {
    total_keys = 0,
    problems = {}, -- problem_id -> { cleared_count, best_keys, best_time_ms, last_keys, attempts }
  },
}

local function ensure_dir(filepath)
  local dir = vim.fs.dirname(filepath)
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
end

function M.load()
  local path = config.options.storage_path or config.defaults.storage_path
  if vim.fn.filereadable(path) == 1 then
    local content = table.concat(vim.fn.readfile(path), "\n")
    local ok, parsed = pcall(vim.json.decode, content)
    if ok and type(parsed) == "table" then
      M.data = vim.tbl_deep_extend("force", M.data, parsed)
    end
  end
end

function M.save()
  local path = config.options.storage_path or config.defaults.storage_path
  ensure_dir(path)
  local ok, encoded = pcall(vim.json.encode, M.data)
  if ok then
    local file = io.open(path, "w")
    if file then
      file:write(encoded)
      file:close()
    end
  end
end

function M.record_attempt(problem_id, keys_count, time_ms, cleared, ideal_keys_count)
  M.load()
  M.data.total_keys = (M.data.total_keys or 0) + keys_count

  local stats = M.data.problems[problem_id] or {
    cleared_count = 0,
    best_keys = nil,
    best_time_ms = nil,
    last_keys = nil,
    attempts = 0,
  }

  stats.attempts = stats.attempts + 1
  stats.last_keys = keys_count

  if cleared then
    stats.cleared_count = stats.cleared_count + 1
    if not stats.best_keys or keys_count < stats.best_keys then
      stats.best_keys = keys_count
    end
    if not stats.best_time_ms or time_ms < stats.best_time_ms then
      stats.best_time_ms = time_ms
    end
  end

  M.data.problems[problem_id] = stats
  M.save()
end

-- 苦手重み（出題ウェイト）の計算
function M.get_weight(problem_id, ideal_keys_count)
  M.load()
  local stats = M.data.problems[problem_id]
  if not stats or stats.cleared_count == 0 then
    return 3.0 -- 未クリアは最優先で出題
  end

  local ideal = ideal_keys_count or 6
  local last = stats.last_keys or ideal
  local ratio = last / ideal

  if ratio > 2.0 then
    return 2.5 -- 打鍵数が模範の2倍以上の手癖ロス
  elseif ratio > 1.2 then
    return 1.5 -- 模範より少し多い
  else
    return 0.5 -- 模範通りに指が動いた（頻度を下げる）
  end
end

return M
