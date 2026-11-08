-- nvim --clean -l tests/runtime.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
local runtime = require 'custom.runtime'
local original = {
  system = vim.system,
  defer_fn = vim.defer_fn,
  notify = vim.notify,
  uis = vim.api.nvim_list_uis,
  executable = vim.fn.executable,
  expand = vim.fn.expand,
  env = { DISPLAY = vim.env.DISPLAY, WAYLAND_DISPLAY = vim.env.WAYLAND_DISPLAY, SSH_CONNECTION = vim.env.SSH_CONNECTION, SSH_TTY = vim.env.SSH_TTY },
  rtp = vim.o.runtimepath,
}
local root = vim.fn.tempname()
local notices = {}
vim.notify = function(message) notices[#notices + 1] = message end
local ok, err = xpcall(function()
  vim.env.DISPLAY = ':1'
  vim.env.SSH_CONNECTION = nil
  vim.env.SSH_TTY = nil
  vim.api.nvim_list_uis = function() return { {} } end
  vim.fn.executable = function() return 1 end
  local calls = 0
  local response = { code = 0, stdout = '(uint32 1,)' }
  vim.system = function(args, opts)
    calls = calls + 1
    assert(args[1] == 'gdbus' and opts.timeout == 300)
    return { wait = function() return response end }
  end
  assert(runtime.system_is_dark())
  for _, result in ipairs {
    { code = 0, stdout = '(uint32 2,)' },
    { code = 0, stdout = 'invalid' },
    { code = 124 },
    { code = 1 },
  } do
    response = result
    assert(not runtime.system_is_dark())
  end
  vim.system = function()
    return { wait = function() return nil end }
  end
  assert(not runtime.system_is_dark())
  vim.system = function() error 'spawn failed' end
  assert(not runtime.system_is_dark())
  vim.system = function() error 'must skip query' end
  vim.fn.executable = function() return 0 end
  assert(not runtime.system_is_dark())
  vim.fn.executable = function() return 1 end
  vim.api.nvim_list_uis = function() return {} end
  assert(not runtime.system_is_dark())
  vim.api.nvim_list_uis = function() return { {} } end
  vim.env.SSH_CONNECTION = 'remote'
  assert(not runtime.system_is_dark())
  vim.env.SSH_CONNECTION = nil
  vim.env.DISPLAY = nil
  vim.env.WAYLAND_DISPLAY = nil
  assert(not runtime.system_is_dark())
  assert(calls == 5)

  -- Every failure clears busy, including spawn, timeout and callback errors.
  local busy, callbacks, done_count
  local function done()
    busy = false
    done_count = done_count + 1
  end
  local function attempt(result, callback)
    busy, callbacks, done_count = true, 0, 0
    vim.system = function(args, opts, cb)
      assert(vim.deep_equal(args, { 'kitten', '@', 'ls' }))
      assert(opts.timeout == 5000)
      if result == 'throw' then error 'missing kitten' end
      cb(result)
    end
    runtime.run_dock({ 'ls' }, function(output)
      callbacks = callbacks + 1
      if callback then
        callback(output)
      else
        done()
      end
    end, done)
    assert(vim.wait(1000, function() return not busy end))
    assert(done_count == 1)
  end
  attempt 'throw'
  assert(callbacks == 0)
  attempt { code = 1, stderr = 'denied' }
  assert(callbacks == 0)
  attempt { code = 124, stderr = '' }
  assert(callbacks == 0)
  attempt({ code = 0, stdout = '[]' }, function() error 'bad callback' end)
  assert(callbacks == 1)
  attempt { code = 0, stdout = '[]' } -- retry succeeds
  assert(callbacks == 1)

  -- A process may never complete, even after vim.system's TERM timeout.
  -- Drive the independent deadline and ensure late callbacks are ignored.
  local deadline, late, killed
  local closed = false
  vim.defer_fn = function(fn, delay)
    assert(delay == 5000)
    deadline = fn
    return {
      is_closing = function() return closed end,
      stop = function() end,
      close = function() closed = true end,
    }
  end
  vim.system = function(_, _, cb)
    late = cb
    return { kill = function(_, signal) killed = signal end }
  end
  busy, done_count, callbacks = true, 0, 0
  runtime.run_dock({ 'ls' }, function() callbacks = callbacks + 1 end, done)
  assert(busy)
  deadline()
  assert(not busy and done_count == 1 and killed == 9 and closed)
  busy = true -- represents a newer toggle; old completion must not clear it
  late { code = 0, stdout = '[]' }
  vim.wait(20)
  assert(busy and done_count == 1 and callbacks == 0)
  deadline() -- completion/deadline may settle an operation only once
  assert(done_count == 1)
  vim.defer_fn = original.defer_fn

  -- Missing, broken and incompatible local Pi integrations are nonfatal.
  vim.fn.expand = function(path)
    assert(path == '~/git/pi-nvim')
    return root
  end
  assert(runtime.setup_pi() == nil and not runtime.pi_ready)
  vim.fn.mkdir(root .. '/lua/pi-nvim', 'p')
  package.preload['pi-nvim'] = function() error 'broken require' end
  assert(runtime.setup_pi() == nil)
  assert(not vim.list_contains(vim.opt.runtimepath:get(), root))
  package.loaded['pi-nvim'] = nil
  package.preload['pi-nvim'] = function()
    return { setup = function() error 'incompatible setup' end }
  end
  assert(runtime.setup_pi() == nil and not runtime.pi_ready)
  package.loaded['pi-nvim'] = nil
  package.preload['pi-nvim'] = function()
    return { setup = function() end }
  end
  assert(runtime.setup_pi() == nil) -- missing append API
  package.loaded['pi-nvim'] = nil
  local plugin = { setup = function(opts) assert(opts.set_default_keymaps) end }
  for _, method in ipairs { 'append_selection', 'append_selection_prompt', 'append_file', 'append_buffer' } do
    plugin[method] = function() end
  end
  package.preload['pi-nvim'] = function() return plugin end
  assert(runtime.setup_pi() == plugin and runtime.pi_ready)
  assert(vim.list_contains(vim.opt.runtimepath:get(), root))
  assert(#notices >= 8)
end, debug.traceback)
vim.system, vim.notify, vim.defer_fn = original.system, original.notify, original.defer_fn
vim.api.nvim_list_uis, vim.fn.executable, vim.fn.expand = original.uis, original.executable, original.expand
for _, key in ipairs { 'DISPLAY', 'WAYLAND_DISPLAY', 'SSH_CONNECTION', 'SSH_TTY' } do
  vim.env[key] = original.env[key]
end
vim.o.runtimepath = original.rtp
package.loaded['pi-nvim'], package.preload['pi-nvim'] = nil, nil
vim.fn.delete(root, 'rf')
assert(ok, err)
print 'runtime integration tests passed'
