local config = require("vim-master.config")
local loader = require("vim-master.courses.loader")
local ui = require("vim-master.ui")
local engine = require("vim-master.engine")

local M = {}

function M.setup(opts)
  config.setup(opts)
end

function M.open(course_id)
  local courses = loader.get_courses()
  if #courses == 0 then
    vim.notify("[VimMaster] コースが見つかりません", vim.log.levels.WARN)
    return
  end

  if course_id and course_id ~= "" then
    local selected = loader.get_course(course_id)
    if selected then
      engine.start(selected)
      return
    end
  end

  -- メニューの表示
  ui.show_menu(courses, function(selected_course)
    engine.start(selected_course)
  end)
end

return M
