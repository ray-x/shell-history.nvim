# cmp-shellcmds-history

A nvim plugin that provides fuzzy completion for shell command history.
It is a nvim-cmp source for shell command history that reads the shell command history from the shell history file and use it as a completion source.

# Setup

```lua
-- setup with default values
require'cmp_shellcmds_history'.setup{
  default_interval=1200000, -- read/refresh history every 20 minutes
  max_items = 10000, -- maximum number of items to read from history
}

require'cmp'.setup { name = 'shellcmds_history', option = {
  kind_text = ' ',
  -- skip commands too simple
  minium_cmd_length = 3,
  ignore_cmds = { 'ls', 'll', 'dir', 'cd', 'pwd', 'echo', 'cat'},
  -- in case you want to use a custom formatter, e.g. run command with jobstart
  formatter = function(cmd)
    -- flatten the arguments
    return cmd
    -- or you can run the command with jobstart
    -- local jobstr = string.format("call jobstart(['/bin/bash', '-c', '%s'], {'on_stdout': {j, d, e -> print(d)}} )", cmd:sub(2, #cmd))
  end,
 }}
```
