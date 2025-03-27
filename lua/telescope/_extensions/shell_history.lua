-- lua/telescope/_extensions/shell_history.lua
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

local M = {}

-- Function to fetch shell history
local function get_command_history(callback, max_items)
  return callback(require('shell_history').cmd_hist or { 'history is not ready yet' })
end

-- Main picker logic
local function shell_history_picker(opts)
  opts = opts or {}
  get_command_history(function(history)
    pickers
      .new(opts, {
        prompt_title = 'Shell History',
        finder = finders.new_table({
          results = history,
        }),
        sorter = conf.generic_sorter(opts),
        attach_mappings = function(_, map)
          actions.select_default:replace(function(prompt_bufnr)
            local selection = action_state.get_selected_entry().value
            actions.close(prompt_bufnr)
            vim.api.nvim_feedkeys(
              vim.api.nvim_replace_termcodes(':!' .. selection, true, false, true),
              'n',
              true
            )
          end)
          return true
        end,
      })
      :find()
  end, opts.max_items or 500)
end

-- Telescope extension entry point
return require('telescope').register_extension({
  setup = function(ext_config)
    -- Optional: handle user config here
  end,
  exports = {
    shell_history = shell_history_picker,
  },
})
