local kNoop = 2

local watched_options = {
  "full_shape",
  "simplification",
  "extended_charset",
}

local watched = {}
for _, name in ipairs(watched_options) do
  watched[name] = true
end

local function user_data_dir()
  if not rime_api or type(rime_api.get_user_data_dir) ~= "function" then
    return "."
  end
  local ok, dir = pcall(rime_api.get_user_data_dir)
  if ok and type(dir) == "string" and dir ~= "" then
    return dir
  end
  ok, dir = pcall(rime_api.get_user_data_dir, rime_api)
  if ok and type(dir) == "string" and dir ~= "" then
    return dir
  end
  return "."
end

local function state_path()
  return user_data_dir() .. "/lua/persistent_switches.state"
end

local function read_state(env)
  env.state = {}
  local file = io.open(state_path(), "r")
  if not file then
    return
  end

  for line in file:lines() do
    local name, value = line:match("^%s*([%w_]+)%s*=%s*(%a+)%s*$")
    if watched[name] then
      env.state[name] = value == "true"
    end
  end
  file:close()
end

local function write_state(env)
  local file = io.open(state_path(), "w")
  if not file then
    if log then
      log.warning("persistent_switches: cannot write " .. state_path())
    end
    return
  end

  for _, name in ipairs(watched_options) do
    local value = env.state[name]
    if value ~= nil then
      file:write(name, "=", value and "true" or "false", "\n")
    end
  end
  file:close()
end

local function apply_state(env)
  if not env.state then
    read_state(env)
  end

  local context = env.engine.context
  env.restoring = true
  for _, name in ipairs(watched_options) do
    local value = env.state[name]
    if value ~= nil and context:get_option(name) ~= value then
      context:set_option(name, value)
    end
  end
  env.restoring = false
end

local function remember_state(ctx, name, env)
  if env.restoring or not watched[name] then
    return
  end

  local value = ctx:get_option(name)
  if env.state[name] == value then
    return
  end

  env.state[name] = value
  write_state(env)
end

local processor = {}

function processor.init(env)
  read_state(env)
  apply_state(env)
  env.option_notifier = env.engine.context.option_update_notifier:connect(
    function(ctx, name)
      remember_state(ctx, name, env)
    end
  )
end

function processor.func(_, env)
  apply_state(env)
  return kNoop
end

function processor.fini(env)
  if env.option_notifier then
    env.option_notifier:disconnect()
  end
end

return processor
