local this_file = debug.getinfo(1).source:match('@?(.*/)')
local this_dir = vim.fn.fnamemodify(this_file, ':p:h:h')

-- User may forget to run `:helptags`, if not using a plugin manager.
local function ensure_helptags()
  if vim.fn.getftime(this_dir .. '/doc/amazonq.txt') > vim.fn.getftime(this_dir .. '/doc/tags') then
    vim.cmd.helptags(vim.fn.fnameescape(this_dir .. '/doc'))
  end
end

ensure_helptags()
