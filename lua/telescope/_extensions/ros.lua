local has_telescope, telescope = pcall(require, 'telescope')
if not has_telescope then
  error('This plugins requires nvim-telescope/telescope.nvim')
end

local actions = require('telescope.actions')
local builtin = require('telescope.builtin')
local action_state = require('telescope.actions.state')
local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local utils = require('telescope.utils')
local entry_display = require('telescope.pickers.entry_display')
local state = require('telescope.state')
local Path = require('plenary.path')

local conf = require('telescope.config').values

local health_ok = vim.fn["health#report_ok"]
local health_error = vim.fn["health#report_error"]

local make_displayer = function(opts)
  local displayer = entry_display.create {
    separator = " ",
    items = {
      { width = 30 },
      { width = 16 },
      { remaining = true },
    },
  }

  local make_display = function(entry)
    local display_path = Path:new(entry.filename)
    if opts['cwd'] then
      display_path = display_path:make_relative(opts['cwd'])
    end
    if opts.shorten_path then
      display_path = display_path:shorten()
    end

    return displayer {
      entry.value,
      {entry.pkg_type, "TelescopeResultsSpecialComment"},
      {display_path, "TelescopeResultsComment"},
      }
  end

  return function(line)
    local pkgname, path, type = string.match(line, '(%S+)%s+(%S+)%s+[\\(](%S+)[\\)]')
    return {
      ordinal = pkgname,
      -- Path to package.xml for file preview
      path = Path:new(path, "package.xml"):absolute(),
      value = pkgname,
      -- Path to the package root
      filename = path,
      pkg_type = type,
      display = make_display
    }
  end
end

local packages = function(opts)
  if vim.fn.executable("colcon") ~=  1 then
    print("This plugin rquires colcon to be installed")
    return
  end
  local basedir = opts['cwd'] or "."
  local results = utils.get_os_command_output({ 'colcon', '--log-base', '/dev/null', 'list', '--base-paths', basedir })
  if vim.tbl_isempty(results) then
    return
  end
  pickers.new {
    prompt_title = 'ROS packages',
    finder = finders.new_table {
      results = results,
      entry_maker = make_displayer(opts),
    },
    sorter = conf.generic_sorter(opts),
    previewer = conf.file_previewer(opts),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        vim.schedule(function()
            builtin.find_files{cwd=selection.filename, initial_mode="insert"}
        end)
      end)

      return true
    end,
  }:find()
end

local pkg_root = function(opts)
  local has_lsp_util, lsputil = pcall(require, 'lspconfig.util')
  if not has_lsp_util then
    error('This function requires neovim/nvim-lspconfig')
  end
  local ros_pattern = require('lspconfig.util').root_pattern("package.xml")
  opts = opts or {}
  opts.cwd = ros_pattern(vim.fn.bufname())
  return opts
end

local files = function(opts)
  require'telescope.builtin'.find_files(pkg_root(opts))
end

local grep_string = function(opts)
  require'telescope.builtin'.grep_string(pkg_root(opts))
end

local live_grep = function(opts)
  require'telescope.builtin'.live_grep(pkg_root(opts))
end

local health = function()
  if vim.fn.executable("colcon") == 1 then
    health_ok "colcon found"
  else
    health_error "colcon executable missing."
  end
end

return telescope.register_extension {
  exports = {
    packages = packages,
    files = files,
    grep_string = grep_string,
    live_grep = live_grep,
  },
  health = health
}
