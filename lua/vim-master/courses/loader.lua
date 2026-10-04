local storage = require("vim-master.storage")

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
  for _, mod_name in ipairs(builtin_courses) do
    local ok, course = pcall(require, mod_name)
    if ok and course then
      table.insert(courses, course)
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
