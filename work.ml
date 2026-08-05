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
    (* Linked worktrees have a 'commondir' file in their git-dir; the main repo does not *)
    Sys.file_exists (Filename.concat git_dir "commondir")

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

(* Create the worktree for [name] (assumes it does not already exist) and
   symlink .env.local from the main repo. Does not start/attach any tmux
   session — callers that want a session call [start] afterwards.
   [from_opt] controls the base of a newly created branch exactly as before:
   [Some base] passes it through to `git worktree add -b`, [None] omits it so
   git bases the new branch on the current HEAD. *)
let provision_worktree name branch_opt from_opt =
  let repo_root = git_repo_root () in
  let wt_path = worktree_path name in

  ensure_dir (Filename.dirname wt_path);

  let branch = match branch_opt with Some b -> b | None -> name in
  let cmd =
    if branch_exists_local branch || branch_exists_remote branch then
      sprintf "git worktree add '%s' '%s'" wt_path branch
    else
      match from_opt with
      (* --no-track: a branch cut from origin/<base> must NOT inherit it as
         upstream — with push.default=tracking that makes a later push land
         directly on the base branch (bit damascus 2026-07-30 and an
         autonomous axiom lane 2026-08-05). *)
      | Some base -> sprintf "git worktree add --no-track -b '%s' '%s' '%s'" branch wt_path base
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

  wt_path

let worktree_new name branch_opt from_opt =
  let wt_path = worktree_path name in

  if Sys.file_exists wt_path then (
    printf "Worktree already exists: %s\n" wt_path;
    printf "Attaching to session...\n";
    start wt_path
  ) else (
    let wt_path = provision_worktree name branch_opt from_opt in
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

let worktree_restore () =
  if not (Sys.file_exists worktrees_root) then (
    printf "No worktrees directory found at %s\n" worktrees_root;
    exit 0
  );
  let restored = ref 0 in
  let skipped = ref 0 in
  let repo_dirs = Array.to_list (Sys.readdir worktrees_root) in
  List.iter (fun repo ->
    let repo_path = Filename.concat worktrees_root repo in
    if Sys.is_directory repo_path then (
      let wt_entries = Array.to_list (Sys.readdir repo_path) in
      List.iter (fun wt_name ->
        let wt_path = Filename.concat repo_path wt_name in
        if Sys.is_directory wt_path && is_worktree wt_path then (
          let session = session_name_of_dir wt_path in
          if tmux_has_session session then (
            printf "Already active: %s\n" session;
            incr skipped
          ) else (
            printf "Restoring: %s (%s)\n" session wt_path;
            tmux_new_session session wt_path;
            incr restored
          )
        )
      ) wt_entries
    )
  ) repo_dirs;
  printf "\n%d restored, %d already active.\n" !restored !skipped

(* Like [command_output] but reads every line, for multi-line command
   output (e.g. a `claude` run summary read back out via jq). *)
let command_output_full cmd =
  let ic = Unix.open_process_in cmd in
  let buf = Buffer.create 256 in
  (try
    while true do
      Buffer.add_string buf (input_line ic);
      Buffer.add_char buf '\n'
    done
  with End_of_file -> ());
  let _ = Unix.close_process_in ic in
  Buffer.contents buf

let command_ok cmd = Sys.command cmd = 0

(* The repo's default remote branch, e.g. "origin/staging" or "origin/main". *)
let default_base () =
  match command_output "git rev-parse --abbrev-ref origin/HEAD 2>/dev/null" with
  | Some ref when ref <> "" -> ref
  | _ ->
    eprintf "Error: could not resolve default branch (git rev-parse --abbrev-ref origin/HEAD)\n";
    exit 1

let timestamp () =
  let tm = Unix.localtime (Unix.time ()) in
  sprintf "%04d%02d%02d-%02d%02d%02d"
    (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1) tm.Unix.tm_mday
    tm.Unix.tm_hour tm.Unix.tm_min tm.Unix.tm_sec

let read_file path =
  let ic = open_in path in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  close_in ic;
  s

(* Options for `j work run`, all optional with defaults applied by [run_lane]. *)
type run_opts = {
  mutable ticket : string option;
  mutable from_ : string option;
  mutable model : string option;
  mutable max_turns : string option;
  mutable permission_mode : string option;
  mutable prompt : string option;
  mutable fg : bool;
}

let parse_run_args args =
  let name = ref None in
  let opts = { ticket = None; from_ = None; model = None; max_turns = None;
               permission_mode = None; prompt = None; fg = false } in
  let rec go = function
    | [] -> ()
    | "--from" :: v :: rest -> opts.from_ <- Some v; go rest
    | "--model" :: v :: rest -> opts.model <- Some v; go rest
    | "--max-turns" :: v :: rest -> opts.max_turns <- Some v; go rest
    | "--permission-mode" :: v :: rest -> opts.permission_mode <- Some v; go rest
    | "--prompt" :: v :: rest -> opts.prompt <- Some v; go rest
    | "--fg" :: rest -> opts.fg <- true; go rest
    | x :: rest ->
      (if !name = None then name := Some x
       else if opts.ticket = None then opts.ticket <- Some x);
      go rest
  in
  go args;
  (!name, opts)

(* Run one autonomous headless Claude Code session in a persistent per-lane
   worktree. Mirrors the bash reference implementation this replaces:
   provision the worktree if missing, cut a fresh timestamped branch off the
   resolved base every run, then invoke `claude -p` with billing-safe env and
   report the run JSON. *)
let run_lane name opts =
  let home = Sys.getenv "HOME" in
  let prompt_file =
    match opts.prompt with
    | Some p -> p
    | None -> Filename.concat home (sprintf ".claude/prompts/%s.md" name)
  in
  let model = match opts.model with Some m -> m | None -> "fable" in
  let max_turns = match opts.max_turns with Some t -> t | None -> "200" in
  let permission_mode = match opts.permission_mode with Some m -> m | None -> "acceptEdits" in

  (* --- preflight --- *)
  if not (Sys.file_exists prompt_file) then (
    eprintf "Error: no prompt at %s\n" prompt_file;
    exit 1
  );
  if not (command_ok "command -v claude >/dev/null 2>&1") then (
    eprintf "Error: claude not on PATH\n";
    exit 1
  );
  if not (command_ok "command -v jq >/dev/null 2>&1") then (
    eprintf "Error: jq not on PATH\n";
    exit 1
  );
  if not (command_ok "claude auth status >/dev/null 2>&1") then (
    eprintf "Error: not logged in to claude.ai — run 'claude auth login'\n";
    exit 1
  );

  let _ = git_repo_root () in
  (* When a ticket is given, scope the worktree to that ticket so multiple
     workstreams can run in parallel without colliding on the lane name. *)
  let wt_name = match opts.ticket with
    | Some t -> String.lowercase_ascii t
    | None -> name
  in
  let wt_path = worktree_path wt_name in

  (* --- provision if missing --- *)
  if not (Sys.file_exists wt_path) then (
    let base = match opts.from_ with Some b -> b | None -> default_base () in
    let _ = provision_worktree wt_name None (Some base) in
    ()
  );

  let _ = Sys.command (sprintf "git -C '%s' fetch --quiet origin" wt_path) in

  (match command_output (sprintf "git -C '%s' status --porcelain" wt_path) with
   | Some _ ->
     eprintf "Error: worktree %s is dirty — a previous run may have left work behind; inspect %s\n" wt_path wt_path;
     exit 1
   | None -> ());

  (* --- cut this run's branch --- *)
  let base = match opts.from_ with Some b -> b | None -> default_base () in
  let branch = sprintf "claude/%s-%s" wt_name (timestamp ()) in
  (* --no-track: without it a branch cut from origin/staging tracks staging,
     and push.default=tracking then sends `git push` straight to staging —
     the exact incident of 2026-08-05. *)
  let switch_cmd = sprintf "git -C '%s' switch -q --no-track -c '%s' '%s'" wt_path branch base in
  if Sys.command switch_cmd <> 0 then (
    eprintf "Error: failed to create branch %s from %s\n" branch base;
    exit 1
  );
  printf "worktree: %s  branch: %s\n" wt_path branch;

  (* --- build the prompt --- *)
  let prompt = read_file prompt_file in
  let prompt = match opts.ticket with
    | Some t -> prompt ^ sprintf "\n\nWork ticket: %s." t
    | None -> prompt
  in

  let log_dir = Filename.concat home ".local/state/j-work" in
  ensure_dir log_dir;
  let stamp = timestamp () in
  let log = Filename.concat log_dir (sprintf "%s-%s.log" wt_name stamp) in
  let prompt_tmp = Filename.concat log_dir (sprintf "%s-%s.prompt" wt_name stamp) in
  let out_json = Filename.concat log_dir (sprintf "%s-%s.json" wt_name stamp) in

  let oc = open_out prompt_tmp in
  output_string oc prompt;
  close_out oc;

  (* NOTE: managed settings may pin a different model than requested — verify
     the run JSON on first use to confirm --model actually took effect. *)
  (* Billing safety: these env vars, if present, silently bill the API instead
     of the claude.ai subscription. `env -u` (macOS/BSD) strips them before
     claude ever sees them. The prompt itself is never interpolated into this
     string — it's read from prompt_tmp via command substitution. *)
  let claude_cmd =
    sprintf "env -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN -u CLAUDECODE claude -p \"$(cat '%s')\" --model '%s' --permission-mode '%s' --output-format json --max-turns '%s' > '%s' 2>> '%s'"
      prompt_tmp model permission_mode max_turns out_json log
  in

  if opts.fg then (
    (* --- foreground: original synchronous behavior, unchanged --- *)
    let shell_cmd = sprintf "cd '%s' && %s" wt_path claude_cmd in
    let status = Sys.command shell_cmd in

    let result = try read_file out_json with Sys_error _ -> "" in
    let oc = open_out_gen [Open_append; Open_creat] 0o644 log in
    output_string oc (result ^ "\n");
    close_out oc;

    (* --- report --- *)
    if status <> 0 then (
      eprintf "run FAILED (exit %d) — log: %s\n" status log;
      let msg = command_output_full (sprintf "jq -r '.result // \"no result field\"' < '%s'" out_json) in
      eprintf "%s" msg;
      exit status
    );

    let jq_field field =
      match command_output (sprintf "jq -r '.%s // empty' < '%s'" field out_json) with
      | Some s -> s
      | None -> ""
    in
    let session_id = jq_field "session_id" in
    let turns = jq_field "num_turns" in
    let cost = jq_field "total_cost_usd" in
    let is_err =
      match command_output (sprintf "jq -r '.is_error // false' < '%s'" out_json) with
      | Some s -> s
      | None -> "false"
    in
    let summary = command_output_full (sprintf "jq -r '.result // empty' < '%s'" out_json) in

    printf "\n";
    printf "lane      %s\n" name;
    printf "worktree  %s\n" wt_path;
    printf "branch    %s\n" branch;
    printf "session   %s\n" session_id;
    printf "turns     %s\n" turns;
    printf "cost      $%s\n" cost;
    printf "error     %s\n" is_err;
    printf "log       %s\n" log;
    printf "\n";
    printf "resume:   claude --resume %s\n" session_id;
    printf "summary:\n";
    printf "%s" summary;

    if is_err = "true" then exit 1 else exit 0
  ) else (
    (* --- detached (default): hand the whole run lifecycle to a wrapper
       script, spawn it detached, and return the terminal immediately.
       `tm runs watch` picks up progress from the run store the wrapper
       writes to; `tail -f <log>` is the fallback for raw output. *)
    let wrapper = Filename.concat log_dir (sprintf "%s-%s.sh" wt_name stamp) in
    let ticket_str = match opts.ticket with Some t -> t | None -> "" in
    let tm_available = command_ok "command -v tm >/dev/null 2>&1" in

    let wrapper_script =
      String.concat "\n" [
        "#!/bin/sh";
        sprintf "cd '%s' || exit 1" wt_path;
        "";
        "RUN_ID=\"\"";
        sprintf "if [ -n '%s' ] && command -v tm >/dev/null 2>&1; then" ticket_str;
        sprintf "  RUN_ID=$(tm runs start --ticket '%s' --lane '%s' --worktree '%s' --branch '%s' --pid $$ 2>>'%s')" ticket_str name wt_path branch log;
        "  if [ -z \"$RUN_ID\" ]; then";
        sprintf "    echo 'note: tm runs start produced no run id; continuing untracked' >> '%s'" log;
        "  fi";
        sprintf "elif [ -n '%s' ]; then" ticket_str;
        sprintf "  echo 'note: tm not found on PATH at run time; continuing untracked' >> '%s'" log;
        "fi";
        "";
        "if [ -n \"$RUN_ID\" ]; then";
        "  export TSKMSTR_RUN_ID=\"$RUN_ID\"";
        "fi";
        "";
        claude_cmd;
        "STATUS=$?";
        "";
        "if [ -n \"$RUN_ID\" ]; then";
        "  SID=\"\"";
        "  IS_ERR=false";
        "  COST=\"\"";
        "  TURNS=\"\"";
        "  MODEL_USAGE=\"\"";
        "  PR_URL=\"\"";
        "  if command -v jq >/dev/null 2>&1; then";
        sprintf "    SID=$(jq -r '.session_id // empty' < '%s' 2>>'%s')" out_json log;
        (* claude -p can exit 0 while reporting is_error in its result JSON;
           the foreground path treats that as failure, so the wrapper must too. *)
        sprintf "    IS_ERR=$(jq -r '.is_error // false' < '%s' 2>>'%s')" out_json log;
        sprintf "    COST=$(jq -r '.total_cost_usd // empty' < '%s' 2>>'%s')" out_json log;
        sprintf "    TURNS=$(jq -r '.num_turns // empty' < '%s' 2>>'%s')" out_json log;
        sprintf "    MODEL_USAGE=$(jq -c '.modelUsage // empty' < '%s' 2>>'%s')" out_json log;
        "  fi";
        (* PR URL: prefer asking gh (accurate even if the summary text never
           mentions the URL); fall back to scraping the result text. Both
           paths degrade to empty on any failure — never fatal. *)
        "  if command -v gh >/dev/null 2>&1; then";
        sprintf "    PR_URL=$(gh pr list --head '%s' --json url -q '.[0].url' 2>>'%s')" branch log;
        "  fi";
        "  if [ -z \"$PR_URL\" ] && command -v jq >/dev/null 2>&1; then";
        sprintf "    PR_URL=$(jq -r '.result // \"\"' < '%s' 2>>'%s' | grep -oE 'https://github[^ )]*/pull/[0-9]+' | head -1)" out_json log;
        "  fi";
        "  if [ \"$STATUS\" -eq 0 ] && [ \"$IS_ERR\" != \"true\" ]; then FINAL_STATUS=done; else FINAL_STATUS=failed; fi";
        "  set -- \"$RUN_ID\" --status \"$FINAL_STATUS\"";
        "  if [ -n \"$SID\" ]; then set -- \"$@\" --session-id \"$SID\"; fi";
        sprintf "  set -- \"$@\" --transcript '%s'" out_json;
        "  if [ -n \"$COST\" ]; then set -- \"$@\" --cost-usd \"$COST\"; fi";
        "  if [ -n \"$TURNS\" ]; then set -- \"$@\" --num-turns \"$TURNS\"; fi";
        "  if [ -n \"$PR_URL\" ]; then set -- \"$@\" --pr-url \"$PR_URL\"; fi";
        (* --model-usage is not in every installed tm yet; only pass it when
           the running tm's own --help says it supports it. *)
        "  if [ -n \"$MODEL_USAGE\" ] && tm runs finish --help 2>/dev/null | grep -q -- --model-usage; then";
        "    set -- \"$@\" --model-usage \"$MODEL_USAGE\"";
        "  fi";
        sprintf "  tm runs finish \"$@\" 2>>'%s'" log;
        "fi";
        "";
        "exit $STATUS";
        "";
      ]
    in

    let oc = open_out wrapper in
    output_string oc wrapper_script;
    close_out oc;
    Unix.chmod wrapper 0o755;

    if not tm_available then
      printf "note: tm not found; run will not appear in tm runs watch\n";

    let spawn_cmd = sprintf "nohup sh '%s' >>'%s' 2>&1 </dev/null &" wrapper log in
    let _ = Sys.command spawn_cmd in

    printf "started   %s %s on %s\n" name (match opts.ticket with Some t -> t | None -> "-") branch;
    printf "worktree  %s\n" wt_path;
    printf "log       %s\n" log;
    printf "watch:    tm runs watch\n";
    printf "follow:   tail -f %s\n" log;
    (match opts.ticket with
     | Some t -> printf "resume:   tm runs resume %s\n" t
     | None -> ());
    exit 0
  )

let show_help () =
  print_endline "Usage: j work [command]";
  print_endline "";
  print_endline "Commands:";
  print_endline "  (no args)              Start/attach tmux session for current directory";
  print_endline "  <directory>            Start/attach tmux session for given directory";
  print_endline "  new <name> [branch] [--from base]  Create worktree + tmux session";
  print_endline "  remove <name>          Kill tmux session + remove worktree";
  print_endline "  list                   Show all tmux sessions with worktree status";
  print_endline "  restore                Recreate tmux sessions for all existing worktrees";
  print_endline "  run <name> [ticket] [--from base] [--model m] [--max-turns n]";
  print_endline "      [--permission-mode mode] [--prompt path] [--fg]";
  print_endline "                         Provision (if needed) + run headless Claude lane,";
  print_endline "                         detached by default (registers with `tm runs`);";
  print_endline "                         --fg runs synchronously in the foreground instead";
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
  | ["restore"] -> worktree_restore ()
  | ["list"] -> worktree_list ()
  | "run" :: run_args ->
    (match parse_run_args run_args with
     | (None, _) ->
       eprintf "Usage: j work run <name> [ticket] [--from base] [--model m] [--max-turns n] [--permission-mode mode] [--prompt path] [--fg]\n";
       exit 1
     | (Some name, opts) -> run_lane name opts)
  | [dir] -> start dir
  | _ -> show_help (); exit 1
