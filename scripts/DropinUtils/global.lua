---@omw-context global
local yamlFolderParser = require("scripts.DropinUtils.utils.yamlFolderParser")

local config = yamlFolderParser.new("scripts/DropinUtils/config/", { logTag = "[yamlFolderParser]" })
config:load()

local extraGreetings = config:getList("extra_greetings", { lowercase = false })

print(("yamlFolderParser loaded %d file(s), %d extra_greetings entries")
    :format(config:count(), #extraGreetings))
for _, greeting in ipairs(extraGreetings) do
    print(greeting)
end

return {}
