open Printf

let worktrees_root = Filename.concat (Sys.getenv "HOME") "Worktrees"

let command_output cmd =
  let ic = Unix.open_process_in cmd in
  try
    let line = input_line ic in
    let _ = Unix.close_process_in ic in
    Some (String.trim line)
  with End_of_file ->
    let _ = Unix.close_process_in ic in
    None

let git_repo_root () =
  match command_output "git rev-parse --path-format=absolute --git-common-dir 2>/dev/null" with
  | None ->
    eprintf "Error: not inside a git repository\n";
    exit 1
  | Some git_dir ->
    (* Strip trailing /.git *)
    if Filename.basename git_dir = ".git" then
      Filename.dirname git_dir
    else
      git_dir

let repo_name () =
  Filename.basename (git_repo_root ())

let is_worktree dir =
  match command_output (sprintf "git -C '%s' rev-parse --git-dir 2>/dev/null" dir) with
  | None -> false
  | Some git_dir ->
    (* In a worktree, --git-dir returns a path to a file, not a directory *)
    try
      let stat = Unix.stat git_dir in
      stat.Unix.st_kind = Unix.S_REG
    with Unix.Unix_error _ -> false

let worktree_path name =
  Filename.concat (Filename.concat worktrees_root (repo_name ())) name

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

let branch_exists_local branch =
  Sys.command (sprintf "git show-ref --verify --quiet refs/heads/%s 2>/dev/null" branch) = 0

let branch_exists_remote branch =
  Sys.command (sprintf "git show-ref --verify --quiet refs/remotes/origin/%s 2>/dev/null" branch) = 0

let ensure_dir path =
  if not (Sys.file_exists path) then
    let _ = Sys.command (sprintf "mkdir -p '%s'" path) in ()

let worktree_new name branch_opt from_opt =
  let repo_root = git_repo_root () in
  let wt_path = worktree_path name in

  if Sys.file_exists wt_path then (
    printf "Worktree already exists: %s\n" wt_path;
    printf "Attaching to session...\n";
    start wt_path
  ) else (
    ensure_dir (Filename.dirname wt_path);

    let branch = match branch_opt with Some b -> b | None -> name in
    let cmd =
      if branch_exists_local branch || branch_exists_remote branch then
        sprintf "git worktree add '%s' '%s'" wt_path branch
      else
        match from_opt with
        | Some base -> sprintf "git worktree add -b '%s' '%s' '%s'" branch wt_path base
        | None -> sprintf "git worktree add -b '%s' '%s'" branch wt_path
    in

    printf "Creating worktree: %s (branch: %s)\n" wt_path branch;
    let exit_code = Sys.command cmd in
    if exit_code <> 0 then (
      eprintf "Error: failed to create worktree\n";
      exit 1
    );

    (* Symlink .env.local from main repo if it exists *)
    let env_local = Filename.concat repo_root ".env.local" in
    if Sys.file_exists env_local then (
      let target = Filename.concat wt_path ".env.local" in
      let _ = Sys.command (sprintf "ln -sf '%s' '%s'" env_local target) in
      printf "Linked .env.local from main repo\n"
    );

    start wt_path
  )

let worktree_remove name =
  let wt_path = worktree_path name in

  if not (Sys.file_exists wt_path) then (
    eprintf "Error: worktree does not exist: %s\n" wt_path;
    exit 1
  );

  let session = session_name_of_dir wt_path in
  if tmux_has_session session then (
    printf "Killing tmux session: %s\n" session;
    let _ = Sys.command (sprintf "tmux kill-session -t '%s'" session) in ()
  );

  printf "Removing worktree: %s\n" wt_path;
  let exit_code = Sys.command (sprintf "git worktree remove '%s'" wt_path) in
  if exit_code <> 0 then (
    eprintf "Worktree has uncommitted changes. Use: git worktree remove --force '%s'\n" wt_path;
    exit 1
  );
  printf "Done.\n"

let worktree_list () =
  let ic = Unix.open_process_in "tmux list-sessions -F '#{session_name}|#{session_path}' 2>/dev/null" in
  let sessions = ref [] in
  (try while true do
    let line = input_line ic in
    match String.split_on_char '|' line with
    | [name; path] -> sessions := (name, path) :: !sessions
    | _ -> ()
  done with End_of_file -> ());
  let _ = Unix.close_process_in ic in

  printf "%-20s %-50s %s\n" "SESSION" "DIR" "TYPE";
  printf "%-20s %-50s %s\n" "-------" "---" "----";
  List.iter (fun (name, path) ->
    let kind = if is_worktree path then "worktree" else "session" in
    printf "%-20s %-50s %s\n" name path kind
  ) (List.rev !sessions)

let show_help () =
  print_endline "Usage: j work [command]";
  print_endline "";
  print_endline "Commands:";
  print_endline "  (no args)              Start/attach tmux session for current directory";
  print_endline "  <directory>            Start/attach tmux session for given directory";
  print_endline "  new <name> [branch] [--from base]  Create worktree + tmux session";
  print_endline "  remove <name>          Kill tmux session + remove worktree";
  print_endline "  list                   Show all tmux sessions with worktree status";
  print_endline "";
  print_endline "Worktrees are created at ~/Worktrees/<repo-name>/<name>/";
  print_endline "Sessions get 4 windows: code, fish, claude, server."

let handle_command args =
  match args with
  | [] -> start (Sys.getcwd ())
  | ["--help"] | ["-h"] -> show_help ()
  | ["new"; name] -> worktree_new name None None
  | ["new"; name; "--from"; base] -> worktree_new name None (Some base)
  | ["new"; name; branch] -> worktree_new name (Some branch) None
  | ["new"; name; branch; "--from"; base] -> worktree_new name (Some branch) (Some base)
  | ["remove"; name] -> worktree_remove name
  | ["list"] -> worktree_list ()
  | [dir] -> start dir
  | _ -> show_help (); exit 1
