# cmp-shellcmds-history

A nvim plugin that provides fuzzy completion for shell command history.
It is a nvim-cmp source for shell command that reads the shell command history from the history file and use it as a completion source.
You can use the plugin for nvim command mode and also in edit mode

## autocomplete in command line

![Image](https://github.com/user-attachments/assets/c697a715-61b8-4158-8e9f-c73a73074f7f)


## autocomplete in your buffer editing

![Image](https://github.com/user-attachments/assets/e34a418b-d549-4cfb-8519-93279b2c26e3)


# Setup

```lua
-- setup with default values
require'cmp_shellcmds_history'.setup{
  default_interval=1200000, -- read/refresh history every 20 minutes
  max_items = 10000, -- maximum number of items to read from history
}
local cmp = require('cmp')

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
  -- autocomplete for buffer editing
  sources = { { name = 'shellcmds_history' } }
 }}
 -- autocomplete in command line
 cmp.setup.cmdline(':', { { name = 'shellcmds_history' } },
```

