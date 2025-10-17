local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt
local rep = require("luasnip.extras").rep

return {
  s("ele", fmt("<{} {}>{}</{}>", {
    i(1),  -- Tag name (used in both <> and </>)
    i(2),  -- HTML attrs beyond just the name
    i(3),         -- Content
    rep(1)
  })),
}
