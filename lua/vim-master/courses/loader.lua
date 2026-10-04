local storage = require("vim-master.storage")
local config = require("vim-master.config")

local M = {}

-- 組み込みコースの定義
local builtin_courses = {
  "vim-master.courses.lv1_motion",
  "vim-master.courses.lv2_textobj",
  "vim-master.courses.lv3_multi",
  "vim-master.courses.practical_refactor",
  "vim-master.courses.practical_log",
}

function M.get_courses()
  local courses = {}
  -- 1. 組み込みコースの読み込み
  for _, mod_name in ipairs(builtin_courses) do
    local ok, course = pcall(require, mod_name)
    if ok and course then
      table.insert(courses, course)
    end
  end

  -- 2. ユーザー独自コースの自動スキャン
  local custom_dir = config.options.custom_courses_dir or config.defaults.custom_courses_dir
  if custom_dir and vim.fn.isdirectory(custom_dir) == 1 then
    local files = vim.fn.glob(custom_dir .. "/*.lua", false, true)
    for _, file_path in ipairs(files) do
      local chunk, err = loadfile(file_path)
      if chunk then
        local ok, course = pcall(chunk)
        if ok and type(course) == "table" and course.problems and #course.problems > 0 then
          course.is_custom = true
          if not course.id then
            course.id = vim.fs.basename(file_path):gsub("%.lua$", "")
          end
          if not course.name then
            course.name = "Custom: " .. course.id
          end
          table.insert(courses, course)
        end
      end
    end
  end

  return courses
end


function M.get_course(course_id)
  local courses = M.get_courses()
  for _, c in ipairs(courses) do
    if c.id == course_id then
      return c
    end
  end
  return courses[1]
end

-- 苦手スコアに応じた重み付けランダム抽選
function M.pick_problem(course, exclude_id)
  if not course or not course.problems or #course.problems == 0 then
    return nil
  end

  local candidates = {}
  local total_weight = 0

  for _, p in ipairs(course.problems) do
    if #course.problems == 1 or p.id ~= exclude_id then
      local weight = storage.get_weight(p.id, p.ideal_count)
      table.insert(candidates, { problem = p, weight = weight })
      total_weight = total_weight + weight
    end
  end

  if #candidates == 0 then
    return course.problems[1]
  end

  local rand = math.random() * total_weight
  local current = 0
  for _, item in ipairs(candidates) do
    current = current + item.weight
    if rand <= current then
      return item.problem
    end
  end

  return candidates[#candidates].problem
end

return M
