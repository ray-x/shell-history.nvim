local lprint = lprint or function(...) end

-- Detect user's shell
local function get_shell_type()
  local shell = vim.opt.shell:get()
  if shell:match('fish$') then
    return 'fish'
  elseif shell:match('zsh$') then
    return 'zsh'
  else
    return 'bash' -- Default to bash
  end
end

local source = {
  config = {
    keyword_pattern = [[.*]],
    initial_interval =  10 * 1000, -- 10s
    default_interval =  20 * 60 * 1000, -- every 20min
    max_items = 10000,
    trigger_chars = { '$', '>', '#' },  -- trigger characters when in editor mode
    ignore_cmds = { 'ls', 'll', 'dir', 'cd', 'pwd', 'echo', 'cat', 'htop', 'btop', 'lazygit', 'exit'},
    -- skip commands too simple
    minium_cmd_length = 3,
    formatter = function(...)
      -- flatten the arguments
      return table.concat({...}, ' ')
    end,
  }
}
local function get_command_history(callback)
  local shell_type = get_shell_type()
  local cmd

  if shell_type == 'fish' then
    cmd = string.format("history -z --max %d | tr '\\0' '\\n' | perl -pe 's/^/$.\t/g; s/\\n/\\n\\t/gm'",
    source.config.max_items)
  else
    cmd = 'history'
  end
  lprint(shell_type, cmd)

  local function on_output(_, data, _)
    if not data then
      return
    end
    local history = {}
    for _, line in ipairs(data) do
      if line ~= '' then -- Extract command from history output, skipping numbers and whitespace
        local cmd_text = line:gsub('^%s*%d+%s+', '')
        if cmd_text and cmd_text ~= '' then
          table.insert(history, cmd_text)
        end
      end
    end

    source.cmd_hist = history
    if callback then
      callback(history)
    end
  end

  vim.fn.jobstart(cmd, {
    on_stdout = on_output,
    stdout_buffered = true,
  })
end

source.setup = function(config)
  source.config = vim.tbl_deep_extend('force', source.config, config or {})
end
source.new = function()
  local self = setmetatable({}, { __index = source })
  -- Initialize with command history
  get_command_history()

  -- Refresh history periodically
  vim.defer_fn(function()
    vim.uv.new_timer():start(
      self.config.initial_interval,
      self.config.default_interval,
      vim.schedule_wrap(function()
        get_command_history()
      end)
    )
  end, 0)
  lprint(self.config, self)

  return self
end

source.get_keyword_pattern = function(_, params)
  params = params or {}
  params.option = params.option or {}
  params.option = vim.tbl_deep_extend('keep', params.option, source.config)
  vim.validate({
    keyword_pattern = {
      params.option.keyword_pattern,
      'string',
      '`opts.keyword_pattern` must be `string`',
    },
  })
  return params.option.keyword_pattern or '.*'
end

local cmd_regex = '\\%([^!#>\\$]\\)'
source.get_keyword_pattern = function(self, params)
  return  cmd_regex .. '*'
end

-- Check if we're in command-line mode
local function is_cmdline_mode()
  return vim.fn.mode() == 'c'
end


local function is_shell_cmdline(params)
  if not is_cmdline_mode() then
    return false
  end
  local cursor = params.context.cursor_before_line or ''
  -- cursor start with '!' in cmdline mode

  return cursor:sub(1, 1) == '!'
end

source.get_trigger_characters = function()
  if is_cmdline_mode() then
    return {'!'}
  end
  return source.config and source.config.trigger_characters or { '$', '#' }
end
local function after_trigger_chars(params)
  local cursor = params.context.cursor_before_line
  local trigger_chars = source.get_trigger_characters()
  local trigger_char = cursor:sub(-1)
  return vim.tbl_contains(trigger_chars, trigger_char)
end

function source:is_available()
  return true
end

source.get_debug_name = function()
  return 'shellcmd'
end

function source:complete(params, callback)
  local input = string.sub(params.context.cursor_before_line, params.offset)
  local items = {}
  local words = {}
  lprint(params, callback)

  if not is_shell_cmdline(params) and not after_trigger_chars(params) then
    lprint('not in shell cmdline, nor after trigger chars')
    return callback({ items = items, isIncomplete = false })
  end


  local trigger_chars = source.get_trigger_characters()
  local trigger_pos = nil
  local trigger_char = nil

  local cursor_line = params.context.cursor_before_line

  for _, char in ipairs(trigger_chars) do
    local pos = cursor_line:find(char .. "[^" .. vim.pesc(char) .. "]*$")
    if pos and (not trigger_pos or pos > trigger_pos) then
      trigger_pos = pos
      trigger_char = char
    end
  end

  local search_text = nil
  if trigger_pos then
    search_text = cursor_line:sub(trigger_pos + 1)
  end

  if not trigger_pos and not is_shell_cmdline(params) then
    lprint('not completing: not after trigger or shell cmdline')
    return callback({ items = {}, isIncomplete = false })
  end
  -- Refresh history when completion is triggered
  for _, word in ipairs(source.cmd_hist or {}) do
    -- if word start with ignore_cmds, skip
    if vim.tbl_contains(self.config.ignore_cmds, word) then
      goto continue
    end

    if #word <= self.config.minium_cmd_length then
      goto continue
    end
    for _, cmd in ipairs(self.config.ignore_cmds) do
      if word:sub(1, #cmd) == cmd then
        goto continue
      end
    end

    if search_text and search_text ~= "" and not word:lower():find(search_text:lower(), 1, true) then
      goto continue
    end
    if not words[word] and input ~= word then
      words[word] = true
      local w = word
      if #w > 60 then
        w = string.sub(w, 1, 60) .. '…'
      end
      if is_shell_cmdline(params) then
        word = '!' .. word
        w = '!' .. w
      end

      local filtered = word
      -- another option is use jobstart and print the output in on_output, so we can run the command in async way
      -- local jobstr = string.format("call jobstart(['/bin/bash', '-c', '%s'], {'on_stdout': {j, d, e -> print(d)}} )", word:sub(2, #word))
      table.insert(items, {
        label =  w,
        insertText = self.config.formatter(word),
        filterText = filtered,
        dup = 0,
        cmp = { kind_hl_group = '@keyword.cmd', kind_text = params.option.kind_text or '$' },
      })
    end
    ::continue::
  end
  if #items == 0 then
    lprint('no valible shell cmds in history file')
    callback({ items = {}, isIncomplete = false })
  end
  lprint(items[1], items[2])
  callback({ items = items })
end

return source
