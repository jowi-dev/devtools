open Printf
open Common

let get_template date =
  sprintf "# %s\n\n## Goals\n- [ ] \n- [ ] \n- [ ] \n\n## Notes\n\n\n## Done\n- \n" date

let ensure_daily_dir () =
  let dir = daily_path () in
  if not (file_exists dir) then (
    let cmd = sprintf "mkdir -p \"%s\"" dir in
    let _ = Sys.command cmd in
    ()
  )

let get_path date =
  Filename.concat (daily_path ()) (date ^ ".md")

let edit date =
  ensure_daily_dir ();
  let plan_path = get_path date in

  if not (file_exists plan_path) then (
    let template = get_template date in
    let oc = open_out plan_path in
    output_string oc template;
    close_out oc;
    printf "Created new plan for %s\n" date
  );

  let editor = get_editor () in
  let cmd = sprintf "%s \"%s\"" editor plan_path in
  let _ = Sys.command cmd in
  ()

let view date =
  let plan_path = get_path date in

  if not (file_exists plan_path) then (
    printf "No plan found for %s\n" date;
    exit 1
  );

  let viewer = if Sys.command "which bat > /dev/null 2>&1" = 0 then
    "bat --style=plain"
  else
    "less" in

  let cmd = sprintf "%s \"%s\"" viewer plan_path in
  let _ = Sys.command cmd in
  ()

let list n =
  ensure_daily_dir ();
  let dir = daily_path () in

  printf "Recent plans (last %d days):\n\n" n;

  let cmd = sprintf "ls -t \"%s\"/*.md 2>/dev/null | head -n %d" dir n in
  let ic = Unix.open_process_in cmd in

  let rec read_files () =
    try
      let file = input_line ic in
      let basename = Filename.basename file in
      let date = String.sub basename 0 (String.length basename - 3) in
      printf "  %s - %s\n" date file;
      read_files ()
    with End_of_file -> () in

  read_files ();
  let _ = Unix.close_process_in ic in
  ()

let save_logs () =
  let logs_dir = logs_root () in
  let today = get_today_date () in
  let commit_msg = sprintf "logs for %s" today in

  printf "Saving logs to git...\n";

  let add_cmd = sprintf "cd \"%s\" && git add ." logs_dir in
  let _ = Sys.command add_cmd in

  let status_cmd = sprintf "cd \"%s\" && git diff --cached --quiet" logs_dir in
  let has_changes = Sys.command status_cmd <> 0 in

  if not has_changes then (
    printf "No changes to commit\n";
    exit 0
  );

  let commit_cmd = sprintf "cd \"%s\" && git commit -m \"%s\"" logs_dir commit_msg in
  let exit_code = Sys.command commit_cmd in
  if exit_code <> 0 then (
    printf "Error: Failed to commit changes\n";
    exit 1
  );

  printf "Pushing to remote...\n";
  let push_cmd = sprintf "cd \"%s\" && git push" logs_dir in
  let exit_code = Sys.command push_cmd in
  if exit_code <> 0 then (
    printf "Error: Failed to push to remote\n";
    exit 1
  );

  printf "Successfully saved logs for %s\n" today

let handle_command args =
  match args with
  | [] ->
    let today = get_today_date () in
    edit today
  | ["view"] ->
    let today = get_today_date () in
    view today
  | ["list"] ->
    list 7
  | ["list"; n_str] ->
    (try
      let n = int_of_string n_str in
      list n
    with _ ->
      print_endline "Error: Invalid number for list count";
      exit 1)
  | ["save"] ->
    save_logs ()
  | [date] when is_valid_date date ->
    edit date
  | _ ->
    print_endline "Error: Invalid plan command";
    print_endline "Usage: j plan [view|list [n]|save|YYYY-MM-DD]";
    exit 1
