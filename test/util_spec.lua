local util = require('amazonq.util')

local function eq(actual, expected, msg)
  assert(
    actual == expected,
    string.format('%s\nExp: %s\nGot: %s', msg or '', vim.inspect(expected), vim.inspect(actual))
  )
end

local function test_decode_html_entities()
  eq('< & >', util.decode_html_entities('&lt; &amp; >'))
end

test_decode_html_entities()
print('passed')
