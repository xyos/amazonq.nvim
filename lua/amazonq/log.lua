--- Primitive logger for development purposes.
local M = {}

local log_enabled = false
local logfile = vim.fs.joinpath(vim.fn.stdpath('log')--[[@as string]], 'amazonq.log')

--- @param level? vim.log.levels Log severity level
local function level_name(level)
  for k, v in pairs(vim.log.levels) do
    if v == level then
      return k
    end
  end
end

--- Init the logging module.
---
--- @param opts { enable: boolean }
function M.init(opts)
  log_enabled = not not (opts and opts.enable)
end

--- Logs a message (for debugging) if `debug=true` was passed to init, else does nothing.
---
--- Logs are written to file:
---
--- ```
--- vim.fs.joinpath(vim.fn.stdpath('log'), 'amazonq.log')
--- ```
---
--- @param msg any
--- @param level? vim.log.levels Log severity level
function M.log(msg, level)
  if not log_enabled then
    return
  end
  level = level or vim.log.levels.INFO

  -- Remove metamethods (avoids noise in logs).
  msg = type(msg) == 'table' and setmetatable(vim.deepcopy(msg), nil) or msg
  local timestr = vim.fn.strftime('%Y-%m-%d %X')
  local msgstr = type(msg) == 'string' and msg or vim.inspect(msg)
  msgstr = ('%s %s %s'):format(timestr, level_name(level), msgstr)
  -- XXX: 😞 need to do this until writefile() supports Lua strings => Blob https://github.com/neovim/neovim/pull/31930
  local msglist = vim.split(msgstr, '\n')
  vim.fn.writefile(msglist, logfile, 'a')
end

return M
