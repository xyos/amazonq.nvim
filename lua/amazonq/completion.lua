local util = require('amazonq.util')
local lsp = require('amazonq.lsp')
local log = require('amazonq.log')
local lspserver = require('amazonq.lsp.server')

local M = {}
local in_proc_server

function M.get_client()
  local clients = vim.lsp.get_clients({
    bufnr = 0, -- 0 is the current buffer
    name = 'amazonq',
  })
  return #clients > 0 and clients[1] or nil
end

--- Starts a in-process LSP server which routes "textDocument/completion"
--- requests to the Amazon Q LSP server, and returns the result.
---
--- @return table
local function create_server()
  local srv = lspserver.create_server({
    capabilities = {
      completionProvider = {
        -- triggerCharacters = { '.' },
        -- 👀??
        triggerCharacters = {}, -- No automatic triggers, only manual.
      },
    },
    handlers = {
      ['textDocument/completion'] = function(_, _, on_complete)
        local client = assert(M.get_client())
        log.log('Generating code completion')

        local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
        params.context = {
          -- Expected by: https://github.com/aws/language-servers/blob/a3b88c0400335890d8d6d3440809a3b197e14e11/server/aws-lsp-codewhisperer/src/language-server/codeWhispererServer.ts#L354
          triggerKind = vim.lsp.protocol.CompletionTriggerKind.Invoked,
        }

        -- Get the current line and cursor position
        local cursor_position = vim.api.nvim_win_get_cursor(0)
        local current_line = cursor_position[1] - 1 -- Subtract 1 for 0-indexing
        local current_col = cursor_position[2]

        lsp.lsp_request(client, 'aws/textDocument/inlineCompletionWithReferences', params, function(err, result)
          if err then
            util.msg(('Generating code completion failed: %s'):format(vim.inspect(err)), vim.log.levels.ERROR)
          elseif result and result.items then
            if vim.fn.has('nvim-0.11') == 0 then
              -- HACK: Replace NUL (^@) chars in the multiline result. See ":help NL-used-for-Nul".
              -- Not needed for Nvim 0.11+: https://github.com/neovim/neovim/issues/7769
              -- TODO(jmkeyes): Remove this after bumping minimum Nvim to 0.11+.
              vim.api.nvim_create_autocmd({ 'CompleteDone' }, {
                once = true,
                buffer = 0,
                group = lsp.augroup,
                callback = function()
                  if not vim.api.nvim_get_current_line():find('\0') then
                    return
                  end
                  -- Replace NUL bytes with newlines.
                  vim.cmd [[exe "keeppatterns substitute /\n/\\r/ge"]]
                  -- :substitute positions the cursor at the first column of the last line inserted.
                  -- Place cursor at the end.
                  vim.fn.cursor(vim.fn.line('.'), vim.v.maxcol)
                end,
              })
            end

            local items --[[@type lsp.CompletionItem[] ]] = vim.tbl_map(function(item)
              return  --[[@type lsp.CompletionItem]]{
                label = item.insertText:sub(1, 72):gsub('^%s+', ''):gsub('%s+', ' ') .. '…',
                -- Note: intentionally not `Snippet`, because completion engines tend to omit or de-rank snippets
                -- (TODO: but maybe that's appropriate? Using `Reference` here is arguably bad behavior).
                kind = vim.lsp.protocol.CompletionItemKind.Reference,
                insertText = item.insertText,
                -- Note: intentionally not `Snippet`, to avoid entering "snippet mode".
                -- Especially matters if placeholder-like tokens (`${3:foo}`) happen to be in the result.
                insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
                documentation = {
                  kind = vim.lsp.protocol.MarkupKind.Markdown,
                  value = ('```\n%s\n```'):format(item.insertText),
                },
                labelDetails = {
                  description = util.productName, -- Show that the completion is from AmazonQ.
                },
                -- To append the completion after the trigger text
                textEdit = {
                  newText = item.insertText,
                  range = {
                    start = {
                      line = current_line,
                      character = current_col, -- Ensure it starts at the cursor position
                    },
                    ['end'] = {
                      line = current_line,
                      character = current_col, -- Both start and end at cursor position to avoid replacing
                    },
                  },
                },
              }
            end, result.items)

            on_complete(nil, items)
          else
            util.msg('Generating code completion failed: empty result')
          end
        end)
      end,
    },
  })

  return srv
end

--- Starts (reuses existing) the "shim" LSP client in the current buffer.
function M.start(config)
  assert(config)
  assert(in_proc_server)
  vim.lsp.start({
    name = 'amazonq-completion',
    cmd = in_proc_server.cmd,
    -- Use some properties from the main LSP config.
    root_dir = config.root_dir,
  })
end

function M.setup()
  in_proc_server = create_server()
end

M.setup()

return M
