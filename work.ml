open Printf

let session_name_of_dir dir =
  (* Use the last path component as session name, replacing dots with dashes *)
  let base = Filename.basename dir in
  String.map (fun c -> if c = '.' then '-' else c) base

let tmux_has_session name =
  let cmd = sprintf "tmux has-session -t '%s' 2>/dev/null" name in
  Sys.command cmd = 0

let tmux_new_session name dir =
  (* Create detached session with first window named "code" *)
  let cmd = sprintf "tmux new-session -d -s '%s' -c '%s' -n code" name dir in
  let _ = Sys.command cmd in

  (* Create remaining windows: fish, claude, server *)
  let windows = ["fish"; "claude"; "server"] in
  List.iter (fun win_name ->
    let cmd = sprintf "tmux new-window -t '%s' -n '%s' -c '%s'" name win_name dir in
    let _ = Sys.command cmd in
    ()
  ) windows;

  (* Select the first window *)
  let cmd = sprintf "tmux select-window -t '%s:code'" name in
  let _ = Sys.command cmd in
  ()

let tmux_attach name =
  let cmd = sprintf "tmux attach-session -t '%s'" name in
  let _ = Sys.command cmd in
  ()

let start dir =
  let abs_dir =
    if Filename.is_relative dir then
      Filename.concat (Sys.getcwd ()) dir
    else
      dir
  in

  if not (Sys.file_exists abs_dir) then (
    printf "Error: directory does not exist: %s\n" abs_dir;
    exit 1
  );

  let name = session_name_of_dir abs_dir in

  if tmux_has_session name then (
    printf "Attaching to existing session: %s\n" name;
    tmux_attach name
  ) else (
    printf "Creating session: %s (%s)\n" name abs_dir;
    tmux_new_session name abs_dir;
    tmux_attach name
  )

let handle_command args =
  match args with
  | [] -> start (Sys.getcwd ())
  | ["--help"] | ["-h"] ->
    print_endline "Usage: j work [directory]";
    print_endline "";
    print_endline "Start or attach to a tmux session for the given directory.";
    print_endline "Creates 4 windows: code, fish, claude, server.";
    print_endline "If no directory given, uses the current directory."
  | [dir] -> start dir
  | _ ->
    print_endline "Usage: j work [directory]";
    exit 1
