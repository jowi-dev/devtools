open Printf
open Sys

(* Package mappings: (name, repo_path, system_path) *)
let packages = [
  ("nvim", "nvim", Filename.concat (Sys.getenv "HOME") ".config/nvim");
  ("starship", "starship.toml", Filename.concat (Sys.getenv "HOME") ".config/starship.toml");
  ("fish", "fish", Filename.concat (Sys.getenv "HOME") ".config/fish");
  ("tmux", "tmux.conf", Filename.concat (Sys.getenv "HOME") ".config/tmux/tmux.conf");
  ("git", "git-config", Filename.concat (Sys.getenv "HOME") ".config/git/config");
]

let install_location = "/usr/local/bin/j"

let repo_root =
  try
    Sys.getenv "DEVTOOLS_ROOT"
  with Not_found ->
    (* Fallback to current executable directory for local usage *)
    Filename.dirname (Sys.argv.(0))

let logs_root () = Filename.concat repo_root "logs"
let daily_path () = Filename.concat (logs_root ()) "dailies"
let til_path () = Filename.concat (logs_root ()) "til"
let public_logs_root () = Filename.concat repo_root "public_logs"
let public_til_path () = Filename.concat (public_logs_root ()) "til"

let show_help () =
  print_endline "j - Jowi's dev environment sync tool";
  print_endline "";
  print_endline "Usage: j [--force] <import|export|install> <package|--all>";
  print_endline "       j nvim <install|list|update|remove> [plugin-url|plugin-name] [custom-name]";
  print_endline "       j project <search> [pattern]";
  print_endline "       j plan [view|list|save|YYYY-MM-DD]";
  print_endline "       j til <topic|list|search> [pattern]";
  print_endline "";
  print_endline "Config Commands:";
  print_endline "  import <package>  Copy config from system location to repo";
  print_endline "  export <package>  Copy config from repo to system location";
  print_endline "  export --all     Export all available packages to system";
  print_endline "  install          Install j command to /usr/local/bin";
  print_endline "";
  print_endline "Nvim Commands:";
  print_endline "  nvim install <url> [name]  Install plugin from git URL as submodule";
  print_endline "                             Optional custom name overrides default";
  print_endline "  nvim list                  List installed plugins";
  print_endline "  nvim update <name>         Update plugin to latest version";
  print_endline "  nvim remove <name>         Remove plugin submodule";
  print_endline "";
  print_endline "Project Commands:";
  print_endline "  project search [pattern]   Search files with ripgrep+fzf, open in nvim";
  print_endline "";
  print_endline "Plan Commands:";
  print_endline "  plan                       Edit today's plan in $EDITOR";
  print_endline "  plan view                  View today's plan";
  print_endline "  plan list [n]              List last n days of plans (default 7)";
  print_endline "  plan save                  Commit and push logs to git";
  print_endline "  plan YYYY-MM-DD            Edit plan for specific date";
  print_endline "";
  print_endline "TIL Commands:";
  print_endline "  til <topic>                Edit TIL for topic (e.g., rust, nix)";
  print_endline "  til list [--public]        List all TIL topics (add --public for published)";
  print_endline "  til search <pattern>       Search across all TILs";
  print_endline "  til export <topic>         Polish and export TIL to public repo";
  print_endline "";
  print_endline "Options:";
  print_endline "  --force          Skip timestamp checks and prompts";
  print_endline "";
  print_endline "Available packages:";
  List.iter (fun (name, repo_path, sys_path) ->
    printf "  %s: %s/%s <-> %s\n" name repo_root repo_path sys_path
  ) packages

let file_exists path =
  try
    let _ = Unix.stat path in true
  with Unix.Unix_error _ -> false

let get_modification_time path =
  try
    let stat = Unix.stat path in
    Some stat.Unix.st_mtime
  with Unix.Unix_error _ -> None

let is_newer src_path dest_path =
  match (get_modification_time src_path, get_modification_time dest_path) with
  | (Some src_time, Some dest_time) -> src_time > dest_time
  | (Some _, None) -> true  (* Source exists, dest doesn't *)
  | (None, _) -> false      (* Source doesn't exist *)

let format_time timestamp =
  let tm = Unix.localtime timestamp in
  sprintf "%04d-%02d-%02d %02d:%02d:%02d"
    (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1) tm.Unix.tm_mday
    tm.Unix.tm_hour tm.Unix.tm_min tm.Unix.tm_sec

let copy_recursive src dest =
  let cmd = sprintf "cp -r \"%s\" \"%s\"" src dest in
  let exit_code = Sys.command cmd in
  if exit_code <> 0 then
    failwith (sprintf "Failed to copy %s to %s" src dest)

let backup_if_exists path =
  if file_exists path then (
    let backup_path = path ^ ".backup" in
    printf "Backing up existing config to %s\n" backup_path;
    copy_recursive path backup_path;
    let rm_cmd = sprintf "rm -rf \"%s\"" path in
    let _ = Sys.command rm_cmd in
    ()
  )

let ensure_parent_dir path =
  let parent = Filename.dirname path in
  if not (file_exists parent) then (
    let cmd = sprintf "mkdir -p \"%s\"" parent in
    let _ = Sys.command cmd in
    ()
  )

let find_package name =
  try
    Some (List.find (fun (n, _, _) -> n = name) packages)
  with Not_found -> None

let install_self () =
  let current_exe = Sys.argv.(0) in
  printf "Installing j to %s\n" install_location;
  
  if not (file_exists current_exe) then (
    print_endline "Error: Cannot find current executable";
    exit 1
  );
  
  (* Create /usr/local/bin if it doesn't exist *)
  let install_dir = Filename.dirname install_location in
  if not (file_exists install_dir) then (
    let cmd = sprintf "sudo mkdir -p \"%s\"" install_dir in
    let exit_code = Sys.command cmd in
    if exit_code <> 0 then (
      printf "Error: Failed to create directory %s\n" install_dir;
      exit 1
    )
  );
  
  (* Backup existing installation if it exists *)
  if file_exists install_location then (
    printf "Backing up existing j to %s.backup\n" install_location;
    let backup_cmd = sprintf "sudo cp \"%s\" \"%s.backup\"" install_location install_location in
    let _ = Sys.command backup_cmd in
    ()
  );
  
  (* Copy current executable to install location *)
  let install_cmd = sprintf "sudo cp \"%s\" \"%s\"" current_exe install_location in
  let exit_code = Sys.command install_cmd in
  if exit_code <> 0 then (
    printf "Error: Failed to install j to %s\n" install_location;
    exit 1
  );
  
  (* Make sure it's executable *)
  let chmod_cmd = sprintf "sudo chmod +x \"%s\"" install_location in
  let _ = Sys.command chmod_cmd in
  
  printf "✓ Successfully installed j to %s\n" install_location;
  print_endline "You can now use 'j' from anywhere!"

let read_yes_no () =
  print_string "Proceed? (y/n): ";
  flush stdout;
  let response = read_line () in
  String.lowercase_ascii (String.trim response) = "y"

let extract_plugin_name_from_url url =
  let parts = String.split_on_char '/' url in
  match List.rev parts with
  | name :: _ when String.ends_with ~suffix:".git" name ->
    String.sub name 0 (String.length name - 4)
  | name :: _ -> name
  | [] -> failwith "Invalid git URL"

let nvim_plugins_path () =
  Filename.concat repo_root "nvim/pack/plugins/start"

let nvim_install_plugin url custom_name_opt =
  printf "Installing nvim plugin from %s\n" url;
  
  let plugin_name = match custom_name_opt with
    | Some name -> name
    | None -> extract_plugin_name_from_url url in
  
  let plugins_dir = nvim_plugins_path () in
  let plugin_path = Filename.concat plugins_dir plugin_name in
  
  (* Check if plugin already exists *)
  if file_exists plugin_path then (
    printf "Error: Plugin '%s' already exists at %s\n" plugin_name plugin_path;
    exit 1
  );
  
  (* Ensure plugins directory exists *)
  let _ = Sys.command (sprintf "mkdir -p \"%s\"" plugins_dir) in
  
  (* Add as git submodule *)
  let submodule_path = sprintf "nvim/pack/plugins/start/%s" plugin_name in
  let add_cmd = sprintf "cd \"%s\" && git submodule add \"%s\" \"%s\"" repo_root url submodule_path in
  let exit_code = Sys.command add_cmd in
  
  if exit_code <> 0 then (
    printf "Error: Failed to add plugin as submodule\n";
    exit 1
  );
  
  printf "✓ Successfully installed plugin '%s'\n" plugin_name;
  printf "  Location: %s\n" plugin_path

let nvim_list_plugins () =
  let plugins_dir = nvim_plugins_path () in
  
  if not (file_exists plugins_dir) then (
    print_endline "No nvim plugins directory found";
    exit 0
  );
  
  printf "Installed nvim plugins in %s:\n" plugins_dir;
  print_endline "";
  
  let list_cmd = sprintf "ls -la \"%s\"" plugins_dir in
  let _ = Sys.command list_cmd in
  ()

let nvim_remove_plugin name =
  printf "Removing nvim plugin '%s'\n" name;
  
  let plugins_dir = nvim_plugins_path () in
  let plugin_path = Filename.concat plugins_dir name in
  
  if not (file_exists plugin_path) then (
    printf "Error: Plugin '%s' not found at %s\n" name plugin_path;
    exit 1
  );
  
  let submodule_path = sprintf "nvim/pack/plugins/start/%s" name in
  
  (* Remove from git submodules *)
  let deinit_cmd = sprintf "cd \"%s\" && git submodule deinit -f \"%s\"" repo_root submodule_path in
  let rm_cmd = sprintf "cd \"%s\" && git rm -f \"%s\"" repo_root submodule_path in
  let cleanup_cmd = sprintf "cd \"%s\" && rm -rf \".git/modules/%s\"" repo_root submodule_path in
  
  let exit1 = Sys.command deinit_cmd in
  let exit2 = Sys.command rm_cmd in  
  let _ = Sys.command cleanup_cmd in
  
  if exit1 <> 0 || exit2 <> 0 then (
    printf "Warning: Some cleanup commands failed, but plugin directory removed\n"
  );
  
  printf "✓ Successfully removed plugin '%s'\n" name

let nvim_update_plugin name =
  printf "Updating nvim plugin '%s'\n" name;
  
  let plugins_dir = nvim_plugins_path () in
  let plugin_path = Filename.concat plugins_dir name in
  
  if not (file_exists plugin_path) then (
    printf "Error: Plugin '%s' not found at %s\n" name plugin_path;
    exit 1
  );
  
  let submodule_path = sprintf "nvim/pack/plugins/start/%s" name in
  
  (* Update the submodule to latest *)
  let update_cmd = sprintf "cd \"%s\" && git submodule update --remote \"%s\"" repo_root submodule_path in
  let exit_code = Sys.command update_cmd in
  
  if exit_code <> 0 then (
    printf "Error: Failed to update plugin '%s'\n" name;
    exit 1
  );
  
  printf "✓ Successfully updated plugin '%s' to latest version\n" name

let project_search pattern_opt =
  let pattern = match pattern_opt with
    | Some p -> p
    | None -> "" in
  
  printf "Searching current directory for: %s\n" (if pattern = "" then "(all files)" else pattern);
  flush stdout;
  
  (* Build the search command *)
  let rg_cmd = if pattern = "" then 
    "rg --line-number --column --no-heading --color=always ."
  else
    sprintf "rg --line-number --column --no-heading --color=always \"%s\"" pattern in
  
  (* Build the fzf command with nvim integration *)
  let fzf_cmd = sprintf "%s | fzf --ansi --delimiter=: \
    --preview 'bat --color=always --highlight-line {2} {1}' \
    --preview-window 'right:60%%:+{2}/2' \
    --bind 'ctrl-o:execute(nvim {1} +{2})' \
    --bind 'enter:execute(nvim {1} +{2})'" rg_cmd in
  
  let exit_code = Sys.command fzf_cmd in
  if exit_code <> 0 && exit_code <> 130 then (* 130 is fzf cancelled with Ctrl-C *)
    printf "Search failed or cancelled\n"

let handle_project_command args =
  match args with
  | [] -> project_search None
  | ["search"] -> project_search None
  | ["search"; pattern] -> project_search (Some pattern)
  | _ ->
    print_endline "Error: Invalid project command";
    print_endline "Usage: j project search [pattern]";
    show_help ();
    exit 1

(* Plan command functions *)
let get_today_date () =
  let tm = Unix.localtime (Unix.time ()) in
  sprintf "%04d-%02d-%02d"
    (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1) tm.Unix.tm_mday

let is_valid_date str =
  try
    let parts = String.split_on_char '-' str in
    match parts with
    | [year; month; day] ->
      let y = int_of_string year in
      let m = int_of_string month in
      let d = int_of_string day in
      String.length year = 4 &&
      String.length month = 2 &&
      String.length day = 2 &&
      y >= 2000 && y <= 2100 &&
      m >= 1 && m <= 12 &&
      d >= 1 && d <= 31
    | _ -> false
  with _ -> false

let get_plan_template date =
  sprintf "# %s\n\n## Goals\n- [ ] \n- [ ] \n- [ ] \n\n## Notes\n\n\n## Done\n- \n" date

let ensure_daily_dir () =
  let dir = daily_path () in
  if not (file_exists dir) then (
    let cmd = sprintf "mkdir -p \"%s\"" dir in
    let _ = Sys.command cmd in
    ()
  )

let get_plan_path date =
  Filename.concat (daily_path ()) (date ^ ".md")

let get_editor () =
  try Sys.getenv "EDITOR"
  with Not_found -> "nvim"

let edit_plan date =
  ensure_daily_dir ();
  let plan_path = get_plan_path date in

  (* Create template if file doesn't exist *)
  if not (file_exists plan_path) then (
    let template = get_plan_template date in
    let oc = open_out plan_path in
    output_string oc template;
    close_out oc;
    printf "Created new plan for %s\n" date
  );

  let editor = get_editor () in
  let cmd = sprintf "%s \"%s\"" editor plan_path in
  let _ = Sys.command cmd in
  ()

let view_plan date =
  let plan_path = get_plan_path date in

  if not (file_exists plan_path) then (
    printf "No plan found for %s\n" date;
    exit 1
  );

  (* Try bat first, fall back to less *)
  let viewer = if Sys.command "which bat > /dev/null 2>&1" = 0 then
    "bat --style=plain"
  else
    "less" in

  let cmd = sprintf "%s \"%s\"" viewer plan_path in
  let _ = Sys.command cmd in
  ()

let list_plans n =
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

  (* Add all changes *)
  let add_cmd = sprintf "cd \"%s\" && git add ." logs_dir in
  let _ = Sys.command add_cmd in

  (* Check if there are changes to commit *)
  let status_cmd = sprintf "cd \"%s\" && git diff --cached --quiet" logs_dir in
  let has_changes = Sys.command status_cmd <> 0 in

  if not has_changes then (
    printf "No changes to commit\n";
    exit 0
  );

  (* Commit changes *)
  let commit_cmd = sprintf "cd \"%s\" && git commit -m \"%s\"" logs_dir commit_msg in
  let exit_code = Sys.command commit_cmd in
  if exit_code <> 0 then (
    printf "Error: Failed to commit changes\n";
    exit 1
  );

  (* Push to remote *)
  printf "Pushing to remote...\n";
  let push_cmd = sprintf "cd \"%s\" && git push" logs_dir in
  let exit_code = Sys.command push_cmd in
  if exit_code <> 0 then (
    printf "Error: Failed to push to remote\n";
    exit 1
  );

  printf "✓ Successfully saved logs for %s\n" today

let handle_plan_command args =
  match args with
  | [] ->
    let today = get_today_date () in
    edit_plan today
  | ["view"] ->
    let today = get_today_date () in
    view_plan today
  | ["list"] ->
    list_plans 7
  | ["list"; n_str] ->
    (try
      let n = int_of_string n_str in
      list_plans n
    with _ ->
      print_endline "Error: Invalid number for list count";
      exit 1)
  | ["save"] ->
    save_logs ()
  | [date] when is_valid_date date ->
    edit_plan date
  | _ ->
    print_endline "Error: Invalid plan command";
    print_endline "Usage: j plan [view|list [n]|save|YYYY-MM-DD]";
    show_help ();
    exit 1

(* TIL command functions *)
let ensure_til_dir () =
  let dir = til_path () in
  if not (file_exists dir) then (
    let cmd = sprintf "mkdir -p \"%s\"" dir in
    let _ = Sys.command cmd in
    ()
  )

let get_til_file_path topic =
  Filename.concat (til_path ()) (topic ^ ".md")

let get_til_template topic =
  let today = get_today_date () in
  sprintf "# TIL: %s\n\n## %s\n- \n" topic today

let edit_til topic =
  ensure_til_dir ();
  let til_file = get_til_file_path topic in

  (* Create template if file doesn't exist *)
  if not (file_exists til_file) then (
    let template = get_til_template topic in
    let oc = open_out til_file in
    output_string oc template;
    close_out oc;
    printf "Created new TIL for %s\n" topic
  );

  let editor = get_editor () in
  let cmd = sprintf "%s \"%s\"" editor til_file in
  let _ = Sys.command cmd in
  ()

let list_tils is_public =
  let dir = if is_public then public_til_path () else til_path () in
  let label = if is_public then "Public TIL topics" else "TIL topics" in

  if not is_public then ensure_til_dir ();

  printf "%s:\n\n" label;

  let cmd = sprintf "ls \"%s\"/*.md 2>/dev/null | sort" dir in
  let ic = Unix.open_process_in cmd in

  let rec read_files () =
    try
      let file = input_line ic in
      let basename = Filename.basename file in
      let topic = String.sub basename 0 (String.length basename - 3) in
      printf "  %s\n" topic;
      read_files ()
    with End_of_file -> () in

  read_files ();
  let _ = Unix.close_process_in ic in
  ()

let search_tils pattern =
  ensure_til_dir ();
  let dir = til_path () in

  printf "Searching TILs for: %s\n\n" pattern;

  let cmd = sprintf "rg -i --color=always \"%s\" \"%s\"/*.md 2>/dev/null" pattern dir in
  let exit_code = Sys.command cmd in
  if exit_code <> 0 then
    printf "No matches found\n"

let export_til topic =
  let private_til = get_til_file_path topic in

  if not (file_exists private_til) then (
    printf "Error: TIL '%s' not found at %s\n" topic private_til;
    printf "Create it first with: j til %s\n" topic;
    exit 1
  );

  printf "Opening TIL for polishing...\n";
  let editor = get_editor () in
  let edit_cmd = sprintf "%s \"%s\"" editor private_til in
  let _ = Sys.command edit_cmd in

  (* Copy to public location *)
  let public_til_dir = public_til_path () in
  let public_til = Filename.concat public_til_dir (topic ^ ".md") in

  (* Ensure public til directory exists *)
  if not (file_exists public_til_dir) then (
    let cmd = sprintf "mkdir -p \"%s\"" public_til_dir in
    let _ = Sys.command cmd in
    ()
  );

  let copy_cmd = sprintf "cp \"%s\" \"%s\"" private_til public_til in
  let exit_code = Sys.command copy_cmd in

  if exit_code <> 0 then (
    printf "Error: Failed to export TIL to public repo\n";
    exit 1
  );

  printf "✓ Exported '%s' to public repo at %s\n" topic public_til;
  printf "Don't forget to commit and push public_logs!\n"

let handle_til_command args =
  match args with
  | ["list"] ->
    list_tils false
  | ["list"; "--public"] ->
    list_tils true
  | ["search"; pattern] ->
    search_tils pattern
  | ["export"; topic] ->
    export_til topic
  | [topic] ->
    edit_til topic
  | _ ->
    print_endline "Error: Invalid til command";
    print_endline "Usage: j til <topic|list [--public]|search <pattern>|export <topic>>";
    show_help ();
    exit 1

let handle_nvim_command args =
  match args with
  | ["install"; url] -> nvim_install_plugin url None
  | ["install"; url; custom_name] -> nvim_install_plugin url (Some custom_name)
  | ["list"] -> nvim_list_plugins ()
  | ["update"; name] -> nvim_update_plugin name
  | ["remove"; name] -> nvim_remove_plugin name
  | _ ->
    print_endline "Error: Invalid nvim command";
    print_endline "Usage: j nvim <install|list|update|remove> [plugin-url|plugin-name] [custom-name]";
    show_help ();
    exit 1

let export_all_packages () =
  print_endline "Exporting all packages to system locations...";
  print_endline "";
  
  let failed_exports = ref [] in
  
  List.iter (fun (name, repo_path, sys_path) ->
    let repo_full_path = Filename.concat repo_root repo_path in
    
    printf "Exporting %s: %s -> %s\n" name repo_full_path sys_path;
    
    if not (file_exists repo_full_path) then (
      printf "  ⚠️  Skipping %s (source does not exist)\n" name;
      failed_exports := name :: !failed_exports
    ) else (
      try
        ensure_parent_dir sys_path;
        backup_if_exists sys_path;
        copy_recursive repo_full_path sys_path;
        printf "  ✓ Exported %s successfully\n" name
      with
      | Failure msg ->
        printf "  ❌ Failed to export %s: %s\n" name msg;
        failed_exports := name :: !failed_exports
    );
    print_endline ""
  ) packages;
  
  let failed_count = List.length !failed_exports in
  let total_count = List.length packages in
  let success_count = total_count - failed_count in
  
  printf "Export complete: %d/%d packages successful\n" success_count total_count;
  if failed_count > 0 then (
    printf "Failed packages: %s\n" (String.concat ", " (List.rev !failed_exports))
  )

let sync_config force_flag action package_name =
  match find_package package_name with
  | None ->
    printf "Error: Unknown package '%s'\n" package_name;
    print_endline "Run 'j' for available packages";
    exit 1
  | Some (_, repo_path, sys_path) ->
    let repo_full_path = Filename.concat repo_root repo_path in

    match action with
    | "export" ->
      printf "Exporting %s: %s -> %s\n" package_name repo_full_path sys_path;

      if not (file_exists repo_full_path) then (
        printf "Error: Source path does not exist: %s\n" repo_full_path;
        exit 1
      );

      ensure_parent_dir sys_path;
      backup_if_exists sys_path;
      copy_recursive repo_full_path sys_path;
      printf "✓ Exported %s successfully\n" package_name;

      (* Source fish config if we just exported it *)
      if package_name = "fish" then (
        printf "Sourcing fish config...\n";
        let source_cmd = "fish -c 'source ~/.config/fish/config.fish'" in
        let _ = Sys.command source_cmd in
        printf "✓ Fish config reloaded\n"
      )

    | "import" ->
      printf "Importing %s: %s -> %s\n" package_name sys_path repo_full_path;

      if not (file_exists sys_path) then (
        printf "Error: System config does not exist: %s\n" sys_path;
        exit 1
      );

      (* Check timestamps unless --force is used *)
      if not force_flag && file_exists repo_full_path then (
        let sys_newer = is_newer sys_path repo_full_path in
        let sys_time = match get_modification_time sys_path with
          | Some t -> format_time t
          | None -> "unknown" in
        let repo_time = match get_modification_time repo_full_path with
          | Some t -> format_time t
          | None -> "unknown" in

        printf "System config: %s\n" sys_time;
        printf "Repo config:   %s\n" repo_time;

        if not sys_newer then (
          printf "⚠️  System config is not newer than repo config.\n";
        );

        if not (read_yes_no ()) then (
          print_endline "Import cancelled.";
          exit 0
        )
      );

      backup_if_exists repo_full_path;
      copy_recursive sys_path repo_full_path;
      printf "✓ Imported %s successfully\n" package_name

    | _ ->
      print_endline "Error: Action must be 'import' or 'export'";
      show_help ();
      exit 1

let parse_args () =
  let force = ref false in
  let args = ref [] in
  let argc = Array.length Sys.argv in
  
  for i = 1 to argc - 1 do
    let arg = Sys.argv.(i) in
    if arg = "--force" then
      force := true
    else
      args := arg :: !args
  done;
  
  (!force, List.rev !args)

let () =
  let (force_flag, args) = parse_args () in
  match args with
  | [] -> show_help ()
  | ["install"] -> install_self ()
  | ["export"; "--all"] -> export_all_packages ()
  | "nvim" :: nvim_args -> handle_nvim_command nvim_args
  | "project" :: project_args -> handle_project_command project_args
  | "plan" :: plan_args -> handle_plan_command plan_args
  | "til" :: til_args -> handle_til_command til_args
  | [action; package] -> sync_config force_flag action package
  | _ ->
    print_endline "Error: Invalid arguments";
    show_help ();
    exit 1