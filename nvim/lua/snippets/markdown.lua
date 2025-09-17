local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt

return {
  -- CLI documentation
  s("cli", fmt([[
# {}

## Environment Variables

## Usage Options
{}]], { i(1), i(2) })),
}