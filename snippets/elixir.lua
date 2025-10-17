local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt

return {
  -- Text snippet
  s("Text", fmt("<Text>{}</Text>", { i(1) })),
  
  -- Template variable
  s("tvar", fmt("<%= {} %>", { i(1) })),
  
  -- Delegate
  s("dele", fmt([[
# -----------------------------------------------------------------------------
#  {} 
# -----------------------------------------------------------------------------
@doc delegate_to: {{PapaPal.Web.API.V2.Resolvers.{}, :call, 3}}
defdelegate {}(parent, args, context),
  to: PapaPal.Web.API.V2.Resolvers.{},
  as: :call]], { i(1), i(2), i(3), i(2) })),
  
  -- Defmodule
  s("defmo", fmt([[
defmodule {} do
@moduledoc """
This is gonna be awesome dude, write your tests first and eat your vegetables

#TODO: ADD METRICS
#TODO: ADD LOGGING
"""

require Logger

end]], { i(1, "PapaPal") })),
  
  -- Deprecated module
  s("deprecated", t({
    '@moduledoc """',
    '--------------------------------------------------------------------------------',
    ' ',
    '  This module is deprecated. Please refrain from leveraging it in new features',
    ' ',
    '--------------------------------------------------------------------------------',
    '"""'
  })),
  
  -- Block comment
  s("comment", fmt([[
# -----------------------------------------------------------------------------
# {} hello
# -----------------------------------------------------------------------------]], { i(1) })),
  
  -- Pry
  s("pry", t("require IEx; IEx.pry")),
  
  -- IO inspect
  s("insp", fmt('IO.inspect({}, limit: :infinity, pretty: true, label: "{}")', { i(1), i(2) })),
  
  -- Pipe IO inspect
  s("pinsp", fmt('|> IO.inspect(limit: :infinity, pretty: true, label: "{}")', { i(1) })),
  
  -- Def function
  s("def", fmt([[
@doc ""
@spec {}() :: :ok
def {}({}) do

end]], { i(1), i(1), i(2) })),
  
  -- Defp private function
  s("defp", fmt([[
# Little blurb about this private
defp {}({}) do

end]], { i(1), i(2) })),
  
  -- Test
  s("test", fmt('test "{}", %{{{}}} do\n\nend', { i(1), i(2) })),
  
  -- Describe block
  s("desc", fmt([[
describe "{}" do
	setup do
		{}
		:ok
	end

end]], { i(1), i(2) })),
  
  -- Environment variable
  s("env_var", fmt([[
defp get_{} do
  Application.get_env(:papa_pal, :{})
end]], { i(1), i(1) })),
  
  -- Soft migration
  s("soft_migr", fmt([[
	use Ecto.Migration

	@disable_ddl_transaction true
	@disable_migration_lock true

	@schema {} 

	def change do
		alter table(@schema) do
			add(:soft_deleted_at, :utc_datetime_usec, [])
		end

		create index(@schema, [:soft_deleted_at], concurrently: true)
	end]], { i(1) })),
  
  -- Soft delete field
  s("soft_field", t("field(:soft_deleted_at, :utc_datetime_usec)")),
  
  -- Oban new job
  s("oban_new", fmt([[
	|> {}.new(args,
	# scheduled_at: Timex.now(), 
	# schedule_in: {{15, :minutes}} 
	)
	|> Oban.insert()]], { i(1) })),
  
  -- Oban job
  s("oban_job", t({
    '@moduledoc """',
    '"""',
    '@max_attempt 20',
    '',
    'require Logger',
    '',
    'use Oban.Worker,',
    '  queue: :default,',
    '  max_attempts: @max_attempt',
    '\t# priority: # 0 to 3',
    '\t# unique: [:arg1, :arg2, :arg3]',
    '',
    '@impl Oban.Worker',
    '@spec perform(%Oban.Job{}) :: :ok | :error',
    '@doc ""',
    'def perform(%Oban.Job{args: args}) do',
    'Logger.info("Performing Job", [args: args])',
    'end'
  })),
  
  -- Logger snippets
  s("log_info", fmt([[
Logger.info("{}",[
	# id: some_id,
	# val: some_val
])]], { i(1) })),
  
  s("log_warn", fmt([[
Logger.warn("{}",[
	# id: some_id,
	# val: some_val
])]], { i(1) })),
  
  s("log_error", fmt([[
Logger.error("{}",[
	# id: some_id,
	# val: some_val
])]], { i(1) })),
  
  -- Resolver error
  s("res_error", fmt([[
%{{
  code: :error_code,
  key: :schema_field_name,
  message: "{}",
  messages: ["{}"]
}}]], { i(1), i(1) })),
}