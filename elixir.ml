open Printf

let show_help () =
  print_endline "j ex - Elixir development helpers";
  print_endline "";
  print_endline "Usage: j ex <command>";
  print_endline "";
  print_endline "Commands:";
  print_endline "  dbg    Start IEx with pry-based debugger (iex --dbg pry -S mix)";
  print_endline "";
  print_endline "Add dbg() calls in your code, then run j ex dbg to drop into";
  print_endline "an interactive pry session when they're hit."

let run_debugger () =
  let cmd = "iex --dbg pry -S mix" in
  printf "Starting: %s\n" cmd;
  let exit_code = Sys.command cmd in
  if exit_code <> 0 then
    exit exit_code

let handle_command args =
  match args with
  | [] | ["--help"] | ["-h"] -> show_help ()
  | ["dbg"] -> run_debugger ()
  | _ ->
    eprintf "Error: Unknown elixir command\n";
    show_help ();
    exit 1
