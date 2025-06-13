-- This module is a temporary workaround until either/both of these land:
-- 1. Q LSP supports standard "textDocument/inlineCompletion" https://github.com/aws/language-servers/issues/741
-- 2. Nvim 0.11 gains `vim.lsp.server()` https://github.com/neovim/neovim/pull/24338
--
-- This module can be removed once the above are implemented.

local M = {}

function M.create_server(opts)
  opts = opts or {}
  local server = {}
  server.messages = {}

  function server.cmd(dispatchers)
    local closing = false
    local handlers = opts.handlers or {}
    local srv = {}

    function srv.request(method, params, callback)
      table.insert(server.messages, {
        method = method,
        params = params,
      })
      local handler = handlers[method]
      if handler then
        handler(method, params, callback)
      elseif method == 'initialize' then
        callback(nil, {
          capabilities = opts.capabilities or {},
        })
      elseif method == 'shutdown' then
        callback(nil, nil)
      end
      local request_id = #server.messages
      return true, request_id
    end

    function srv.notify(method, params)
      table.insert(server.messages, {
        method = method,
        params = params,
      })
      if method == 'exit' then
        dispatchers.on_exit(0, 15)
      end
    end

    function srv.is_closing()
      return closing
    end

    function srv.terminate()
      closing = true
    end

    return srv
  end

  return server
end

return M
