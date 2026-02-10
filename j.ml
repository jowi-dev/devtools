open Printf
open Sys

(* Package mappings: (name, repo_path, system_path) *)
let packages = [
  ("nvim", "nvim", Filename.concat (Sys.getenv "HOME") ".config/nvim");
  ("starship", "starship.toml", Filename.concat (Sys.getenv "HOME") ".config/starship.toml");
  ("fish", "fish", Filename.concat (Sys.getenv "HOME") ".config/fish");
  ("tmux", ".tmux.conf", Filename.concat (Sys.getenv "HOME") ".tmux.conf");
  ("ghostty", "ghostty-config", Filename.concat (Sys.getenv "HOME") ".config/ghostty/config");
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
let nixos_configs_root () =
  try Sys.getenv "NIXOS_CONFIGS_ROOT"
  with Not_found -> Filename.concat (Sys.getenv "HOME") "Projects/nixos-configs"
let remotes_config_path () = Filename.concat (nixos_configs_root ()) ".remotes"

let show_help () =
  print_endline "j - Jowi's dev environment sync tool";
  print_endline "";
  print_endline "Usage: j [--force] <import|export|install> <package|--all>";
  print_endline "       j config <load|save> [message]";
  print_endline "       j nvim <install|list|update|remove> [plugin-url|plugin-name] [custom-name]";
  print_endline "       j project <search> [pattern]";
  print_endline "       j plan [view|list|save|YYYY-MM-DD]";
  print_endline "       j til <topic|list|search> [pattern]";
  print_endline "       j remote <add|list|pull|deploy|ssh|flash|pull-key|discover> [args]";
  print_endline "";
  print_endline "Config Commands:";
  print_endline "  import <package>  Copy config from system location to repo";
  print_endline "  export <package>  Copy config from repo to system location";
  print_endline "  export --all      Export all available packages to system";
  print_endline "  install           Install j command to /usr/local/bin";
  print_endline "";
  print_endline "Git Sync Commands:";
  print_endline "  config load       Pull repo and update all submodules from remote";
  print_endline "  config save [msg] Commit and push repo and submodules to remote";
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
  print_endline "  project files              Search by file name with fzf, open in nvim";
  print_endline "  project explore            Open current directory in file explorer (nnn)";
  print_endline "  project plan <topic>       Create/edit project planning doc";
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
  print_endline "Remote NixOS Commands:";
  print_endline "  remote add <name> <host> [user]  Register a remote NixOS machine";
  print_endline "  remote list                      Show configured remotes";
  print_endline "  remote pull <name>               Pull config from remote to local repo";
  print_endline "  remote deploy <name>             Deploy config to remote and rebuild";
  print_endline "  remote ssh <name>                SSH into remote machine";
  print_endline "  remote flash                     Build and flash installer ISO to USB";
  print_endline "  remote pull-key <name>           Pull SSH keys from remote for secrets.nix";
  print_endline "  remote discover                  Scan for mDNS-discoverable devices on LAN";
  print_endline "  remote setup <build> [--name n]  Deploy build config to init machine and register remote";
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
  try
    let src_stat = Unix.stat src in

    (* Check if dest exists and has conflicting type *)
    (try
      let dest_stat = Unix.stat dest in
      let types_conflict = match (src_stat.Unix.st_kind, dest_stat.Unix.st_kind) with
        | (Unix.S_DIR, Unix.S_DIR) -> false
        | (Unix.S_DIR, _) -> true  (* src is dir, dest is file *)
        | (_, Unix.S_DIR) -> true  (* src is file, dest is dir *)
        | _ -> false               (* both are files *)
      in
      if types_conflict then (
        printf "Removing conflicting destination: %s\n" dest;
        let rm_cmd = sprintf "rm -rf \"%s\"" dest in
        let _ = Sys.command rm_cmd in
        ()
      )
    with Unix.Unix_error _ -> ()); (* dest doesn't exist, continue *)

    let cmd = match src_stat.Unix.st_kind with
      | Unix.S_DIR -> sprintf "rsync -a \"%s/\" \"%s\"" src dest
      | _ -> sprintf "cp \"%s\" \"%s\"" src dest
    in
    let exit_code = Sys.command cmd in
    if exit_code <> 0 then
      failwith (sprintf "Failed to sync %s to %s" src dest)
  with Unix.Unix_error _ ->
    failwith (sprintf "Failed to stat source: %s" src)


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

let check_version_sync () =
  (* Only check if we're running from the installed location *)
  let current_exe = Sys.argv.(0) in
  if current_exe = install_location && file_exists install_location then (
    let source_file = Filename.concat repo_root "j.ml" in

    match (get_modification_time source_file, get_modification_time install_location) with
    | (Some source_time, Some installed_time) ->
      if source_time > installed_time then (
        printf "⚠️  Warning: Your j source code has been updated!\n";
        printf "   Run 'j install' to update the installed version.\n";
        printf "   (Source modified: %s)\n\n" (format_time source_time)
      )
    | _ -> ()
  )

let install_self () =
  (* If running from install location, use the repo binary instead *)
  let current_exe = Sys.argv.(0) in
  let source_exe =
    if current_exe = install_location then
      Filename.concat repo_root "j"
    else
      current_exe in

  printf "Installing j to %s\n" install_location;

  if not (file_exists source_exe) then (
    printf "Error: Cannot find source executable at %s\n" source_exe;
    print_endline "Please run 'make j' first to build the binary.";
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
  
  (* Copy source executable to install location *)
  let install_cmd = sprintf "sudo cp \"%s\" \"%s\"" source_exe install_location in
  let exit_code = Sys.command install_cmd in
  if exit_code <> 0 then (
    printf "Error: Failed to install j to %s\n" install_location;
    exit 1
  );
  
  (* Make sure it's executable *)
  let chmod_cmd = sprintf "sudo chmod +x \"%s\"" install_location in
  let _ = Sys.command chmod_cmd in

  (* Remove extended attributes that may cause macOS to block execution *)
  let xattr_cmd = sprintf "sudo xattr -c \"%s\" 2>/dev/null || true" install_location in
  let _ = Sys.command xattr_cmd in

  (* Re-sign the binary with adhoc signature (required after sudo cp) *)
  let codesign_cmd = sprintf "sudo codesign -s - -f \"%s\" 2>/dev/null || true" install_location in
  let _ = Sys.command codesign_cmd in

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

let project_files () =
  (* Use fd if available, fallback to find *)
  let has_fd = Sys.command "which fd > /dev/null 2>&1" = 0 in

  let find_cmd = if has_fd then
    "fd --type f --hidden --exclude .git"
  else
    "find . -type f -not -path '*/\\.git/*'" in

  let fzf_cmd = sprintf "%s | fzf --preview 'bat --color=always {}' --preview-window 'right:60%%' --bind 'enter:execute(nvim {})'" find_cmd in

  let exit_code = Sys.command fzf_cmd in
  if exit_code <> 0 && exit_code <> 130 then (* 130 is fzf cancelled with Ctrl-C *)
    printf "Search failed or cancelled\n"

let get_file_explorer () =
  try Sys.getenv "FILE_EXPLORER"
  with Not_found -> "nnn"

let get_editor () =
  try Sys.getenv "EDITOR"
  with Not_found -> "nvim"

let project_explore () =
  let explorer = get_file_explorer () in
  let exit_code = Sys.command explorer in
  if exit_code <> 0 then
    printf "Failed to launch file explorer\n"

let get_machine_type () =
  try Sys.getenv "MACHINE_TYPE"
  with Not_found -> "personal"

let read_project_name () =
  let mise_file = "./mise.toml" in
  if not (file_exists mise_file) then
    None
  else
    try
      let ic = open_in mise_file in
      let rec find_project_name in_env_section =
        try
          let line = input_line ic in
          let trimmed = String.trim line in
          (* Check if we're entering [env] section *)
          if trimmed = "[env]" then
            find_project_name true
          (* If in env section, look for PROJECT_NAME *)
          else if in_env_section && String.length trimmed > 0 then
            if String.starts_with ~prefix:"PROJECT_NAME" trimmed then
              (* Parse: PROJECT_NAME = "value" *)
              match String.split_on_char '=' trimmed with
              | [_key; value] ->
                let cleaned = String.trim value in
                let unquoted =
                  if String.length cleaned >= 2 &&
                     String.get cleaned 0 = '"' &&
                     String.get cleaned (String.length cleaned - 1) = '"' then
                    String.sub cleaned 1 (String.length cleaned - 2)
                  else
                    cleaned
                in
                close_in ic;
                Some unquoted
              | _ -> find_project_name in_env_section
            (* If we hit another section, stop looking *)
            else if String.starts_with ~prefix:"[" trimmed then
              find_project_name false
            else
              find_project_name in_env_section
          else
            find_project_name in_env_section
        with End_of_file ->
          close_in ic;
          None
      in
      find_project_name false
    with Sys_error _ -> None

let project_plan topic =
  (* Get PROJECT_NAME from mise.toml *)
  printf "Reading PROJECT_NAME from mise.toml...\n";
  flush stdout;

  match read_project_name () with
  | None ->
    printf "Error: PROJECT_NAME not found in ./mise.toml\n";
    printf "Please add it to your mise.toml:\n";
    printf "  [env]\n";
    printf "  PROJECT_NAME = \"your-project-name\"\n";
    exit 1
  | Some project_name ->
    printf "Found PROJECT_NAME: %s\n" project_name;
    flush stdout;

    let machine_type = get_machine_type () in
    printf "MACHINE_TYPE: %s\n" machine_type;
    flush stdout;

    (* Determine directory based on machine type *)
    let subdir = if machine_type = "work" then "work" else "projects" in
    let plan_dir = Filename.concat (logs_root ()) subdir in
    printf "Plan directory: %s\n" plan_dir;
    flush stdout;

    (* Ensure directory exists *)
    if not (file_exists plan_dir) then (
      printf "Creating directory...\n";
      flush stdout;
      let cmd = sprintf "mkdir -p \"%s\"" plan_dir in
      let _ = Sys.command cmd in
      ()
    );

    let filename = sprintf "%s_%s.md" project_name topic in
    let filepath = Filename.concat plan_dir filename in
    printf "File path: %s\n" filepath;
    flush stdout;

    (* Create file if it doesn't exist *)
    if not (file_exists filepath) then (
      printf "Creating new file...\n";
      flush stdout;
      let oc = open_out filepath in
      fprintf oc "# %s - %s\n\n" project_name topic;
      fprintf oc "## Overview\n\n";
      fprintf oc "## Diagrams\n\n```mermaid\ngraph TD\n    A[Start] --> B[End]\n```\n\n";
      fprintf oc "## Notes\n\n";
      close_out oc;
      printf "Created new project plan: %s/%s\n" subdir filename
    );

    (* Open in editor *)
    printf "Opening in editor...\n";
    flush stdout;
    let editor = get_editor () in
    let cmd = sprintf "%s \"%s\"" editor filepath in
    printf "Running: %s\n" cmd;
    flush stdout;
    let _ = Sys.command cmd in
    ()

(* Remote NixOS management functions *)
type remote = {
  name: string;
  host: string;
  user: string;
}

let ensure_nixos_configs_dir () =
  let dir = nixos_configs_root () in
  if not (file_exists dir) then (
    let cmd = sprintf "mkdir -p \"%s\"" dir in
    let _ = Sys.command cmd in
    ()
  )

let read_remotes () =
  let path = remotes_config_path () in
  if not (file_exists path) then []
  else
    let ic = open_in path in
    let rec read_lines acc =
      try
        let line = input_line ic in
        let parts = String.split_on_char ',' line in
        match parts with
        | [name; host; user] ->
          read_lines ({ name; host; user } :: acc)
        | _ -> read_lines acc
      with End_of_file ->
        close_in ic;
        List.rev acc
    in
    read_lines []

let write_remotes remotes =
  ensure_nixos_configs_dir ();
  let path = remotes_config_path () in
  let oc = open_out path in
  List.iter (fun r ->
    fprintf oc "%s,%s,%s\n" r.name r.host r.user
  ) remotes;
  close_out oc

let find_remote name =
  let remotes = read_remotes () in
  List.find_opt (fun r -> r.name = name) remotes

let remote_add name host user =
  let remotes = read_remotes () in
  (* Check if remote already exists *)
  (match List.find_opt (fun r -> r.name = name) remotes with
  | Some _ ->
    printf "Error: Remote '%s' already exists\n" name;
    exit 1
  | None -> ());

  let new_remote = { name; host; user } in
  let updated_remotes = new_remote :: remotes in
  write_remotes updated_remotes;
  printf "✓ Added remote '%s' (%s@%s)\n" name user host

let remote_list () =
  let remotes = read_remotes () in
  if List.length remotes = 0 then
    print_endline "No remotes configured. Use 'j remote add <name> <host> [user]' to add one."
  else begin
    print_endline "Configured remotes:";
    List.iter (fun r ->
      printf "  %s: %s@%s\n" r.name r.user r.host
    ) remotes
  end

let remote_pull name =
  match find_remote name with
  | None ->
    printf "Error: Remote '%s' not found. Use 'j remote list' to see configured remotes.\n" name;
    exit 1
  | Some remote ->
    ensure_nixos_configs_dir ();
    let machine_dir = Filename.concat (nixos_configs_root ()) ("machines/" ^ name) in
    let cmd = sprintf "mkdir -p \"%s\"" machine_dir in
    let _ = Sys.command cmd in

    printf "Pulling NixOS configuration from %s@%s...\n" remote.user remote.host;

    (* Pull configuration.nix *)
    let scp_config = sprintf "scp %s@%s:/etc/nixos/configuration.nix \"%s/configuration.nix\""
      remote.user remote.host machine_dir in
    printf "Running: %s\n" scp_config;
    let result = Sys.command scp_config in
    if result <> 0 then (
      printf "Error: Failed to pull configuration.nix\n";
      exit 1
    );

    (* Pull hardware-configuration.nix *)
    let scp_hardware = sprintf "scp %s@%s:/etc/nixos/hardware-configuration.nix \"%s/hardware-configuration.nix\""
      remote.user remote.host machine_dir in
    printf "Running: %s\n" scp_hardware;
    let result = Sys.command scp_hardware in
    if result <> 0 then (
      printf "Warning: Failed to pull hardware-configuration.nix (may not exist)\n"
    );

    printf "✓ Successfully pulled configuration to %s\n" machine_dir;
    printf "\nNext steps:\n";
    printf "  1. Review the configuration: nvim %s/configuration.nix\n" machine_dir;
    printf "  2. Commit to git: cd %s && git add . && git commit -m 'Initial config for %s'\n"
      (nixos_configs_root ()) name;
    printf "  3. Deploy changes: j remote deploy %s\n" name

let remote_deploy name =
  match find_remote name with
  | None ->
    printf "Error: Remote '%s' not found. Use 'j remote list' to see configured remotes.\n" name;
    exit 1
  | Some remote ->
    let machine_dir = Filename.concat (nixos_configs_root ()) ("machines/" ^ name) in
    let config_file = Filename.concat machine_dir "configuration.nix" in

    if not (file_exists config_file) then (
      printf "Error: Configuration not found at %s\n" config_file;
      printf "Run 'j remote pull %s' first to fetch the configuration.\n" name;
      exit 1
    );

    printf "Deploying configuration to %s@%s...\n" remote.user remote.host;

    (* Clone/update nixos-configs from GitHub *)
    let flake_path = "/tmp/nixos-configs" in
    let clone_cmd = sprintf
      "ssh %s@%s 'if [ -d %s ]; then cd %s && git pull; else git clone git@github.com:jowi-dev/nixos-configs.git %s; fi'"
      remote.user remote.host flake_path flake_path flake_path in
    printf "Cloning/updating from GitHub: %s\n" clone_cmd;
    let result = Sys.command clone_cmd in
    if result <> 0 then (
      printf "Error: Failed to clone/update configuration from GitHub\n";
      exit 1
    );

    (* Deploy using flake *)
    let rebuild_cmd = sprintf
      "ssh -t %s@%s 'cd %s && sudo nixos-rebuild switch --flake .#%s --impure'"
      remote.user remote.host flake_path name in
    printf "\nRebuilding NixOS with flake: %s\n" rebuild_cmd;
    printf "This may take a few minutes (first build will download and compile Rust dependencies)...\n";
    flush stdout;
    let result = Sys.command rebuild_cmd in
    if result <> 0 then (
      printf "Error: NixOS rebuild failed\n";
      exit 1
    );

    (* Send a message to the console TTY *)
    let notify_cmd = sprintf
      "ssh %s@%s 'echo -e \"\\n\\n=== DEPLOYMENT SUCCESSFUL ===\\nHello from Alien!\\nSystem rebuilt via j remote deploy\\n\" | sudo tee /dev/tty1 > /dev/null'"
      remote.user remote.host in
    let _ = Sys.command notify_cmd in

    printf "✓ Successfully deployed and rebuilt %s\n" name

let remote_ssh name =
  match find_remote name with
  | None ->
    printf "Error: Remote '%s' not found. Use 'j remote list' to see configured remotes.\n" name;
    exit 1
  | Some remote ->
    let ssh_cmd = sprintf "ssh %s@%s" remote.user remote.host in
    printf "Connecting to %s@%s...\n" remote.user remote.host;
    let result = Sys.command ssh_cmd in
    exit result

let remote_pull_key name =
  match find_remote name with
  | None ->
    printf "Error: Remote '%s' not found. Use 'j remote list' to see configured remotes.\n" name;
    exit 1
  | Some remote ->
    let configs_root = nixos_configs_root () in

    if not (file_exists configs_root) then (
      printf "Error: nixos-configs not found at %s\n" configs_root;
      exit 1
    );

    (* Read local Mac public key *)
    let home = Sys.getenv "HOME" in
    let local_pubkey_path = Filename.concat home ".ssh/id_ed25519.pub" in

    if not (file_exists local_pubkey_path) then (
      printf "Error: No SSH public key found at %s\n" local_pubkey_path;
      printf "Generate one with: ssh-keygen -t ed25519\n";
      exit 1
    );

    let local_pubkey =
      let ic = open_in local_pubkey_path in
      let line = input_line ic in
      close_in ic;
      String.trim line
    in

    printf "Mac public key: %s\n" local_pubkey;

    (* SCP GitHub private key from remote *)
    let github_key_dest = Filename.concat configs_root "github-key" in
    let scp_priv = sprintf "scp %s@%s:~/.ssh/id_ed25519 \"%s\""
      remote.user remote.host github_key_dest in
    printf "Pulling GitHub private key from %s@%s...\n" remote.user remote.host;
    let result = Sys.command scp_priv in
    if result <> 0 then (
      printf "Error: Failed to pull private key from remote\n";
      exit 1
    );

    (* Read GitHub public key from remote *)
    let read_pubkey_cmd = sprintf "ssh %s@%s 'cat ~/.ssh/id_ed25519.pub'"
      remote.user remote.host in
    let ic = Unix.open_process_in read_pubkey_cmd in
    let github_pubkey = try String.trim (input_line ic) with End_of_file -> "" in
    let _ = Unix.close_process_in ic in

    if github_pubkey = "" then (
      printf "Error: Failed to read public key from remote\n";
      exit 1
    );

    printf "GitHub public key: %s\n" github_pubkey;

    (* Write secrets.nix *)
    let secrets_path = Filename.concat configs_root "secrets.nix" in
    let oc = open_out secrets_path in
    fprintf oc "{\n";
    fprintf oc "  authorizedKey = \"%s\";\n" local_pubkey;
    fprintf oc "  githubPrivateKeyFile = ./github-key;\n";
    fprintf oc "  githubPublicKey = \"%s\";\n" github_pubkey;
    fprintf oc "}\n";
    close_out oc;

    printf "✓ Generated %s\n" secrets_path;
    printf "✓ Saved GitHub private key to %s\n" github_key_dest;
    printf "\nThese files are gitignored and will be baked into the ISO at build time.\n"

let remote_flash () =
  let configs_root = nixos_configs_root () in

  (* Check if nixos-configs exists *)
  if not (file_exists configs_root) then (
    printf "Error: nixos-configs not found at %s\n" configs_root;
    printf "Clone it first: git clone git@github.com:jowi-dev/nixos-configs.git %s\n" configs_root;
    exit 1
  );

  (* Check for secrets.nix *)
  let secrets_path = Filename.concat configs_root "secrets.nix" in
  if not (file_exists secrets_path) then (
    printf "⚠️  Warning: %s not found\n" secrets_path;
    printf "   The ISO will be built without SSH keys or GitHub credentials.\n";
    printf "   Generate secrets with: j remote pull-key <name>\n\n"
  );

  printf "🔨 Building NixOS installer ISO...\n";
  let build_cmd = sprintf "cd %s && nix build .#installer-iso" configs_root in
  let result = Sys.command build_cmd in
  if result <> 0 then (
    printf "Error: Failed to build ISO\n";
    exit 1
  );

  (* Find the ISO *)
  let iso_path = sprintf "%s/result/iso" configs_root in
  let find_iso = sprintf "ls %s/*.iso 2>/dev/null | head -1" iso_path in
  let iso_file =
    let ic = Unix.open_process_in find_iso in
    let line = try input_line ic with End_of_file -> "" in
    let _ = Unix.close_process_in ic in
    line
  in

  if iso_file = "" then (
    printf "Error: ISO not found in %s\n" iso_path;
    exit 1
  );

  printf "\n✓ ISO built: %s\n\n" iso_file;

  (* List available USB drives *)
  printf "📀 Available USB drives:\n";
  let _ = Sys.command "diskutil list | grep -E '(external|removable)' -B 5" in
  printf "\n";

  (* Prompt for USB device using gum *)
  printf "Enter USB device (e.g., /dev/disk4): ";
  flush stdout;
  let device = read_line () in

  (* Confirm *)
  let confirm_msg = sprintf "⚠️  This will ERASE ALL DATA on %s. Continue?" device in
  let confirm_cmd = sprintf "gum confirm \"%s\"" confirm_msg in
  let result = Sys.command confirm_cmd in
  if result <> 0 then (
    printf "Cancelled.\n";
    exit 0
  );

  (* Unmount the device first *)
  printf "\n🔓 Unmounting %s...\n" device;
  let unmount_cmd = sprintf "diskutil unmountDisk %s" device in
  let _ = Sys.command unmount_cmd in

  (* Flash the ISO *)
  printf "\n💾 Flashing ISO to %s...\n" device;
  printf "This may take several minutes...\n\n";
  let flash_cmd = sprintf "sudo dd if=%s of=%s bs=4m status=progress" iso_file device in
  let result = Sys.command flash_cmd in
  if result <> 0 then (
    printf "Error: Failed to flash ISO\n";
    exit 1
  );

  (* Eject *)
  printf "\n🎉 Ejecting USB drive...\n";
  let eject_cmd = sprintf "diskutil eject %s" device in
  let _ = Sys.command eject_cmd in

  printf "\n✓ USB drive ready! You can now:\n";
  printf "  1. Boot from this USB on any machine\n";
  printf "  2. It will auto-connect to WiFi and enable SSH\n";
  printf "  3. Deploy with: j remote add <name> <ip> root && j remote deploy <name>\n"

let remote_setup build_name remote_name =
  let init_host = "init.local" in
  let user = "root" in

  printf "Setting up new machine...\n";
  printf "  Build config: %s\n" build_name;
  printf "  Remote name:  %s\n" remote_name;
  printf "  Init host:    %s@%s\n" user init_host;
  printf "\n";

  (* Check that the build config exists in nixos-configs *)
  let configs_root = nixos_configs_root () in
  if not (file_exists configs_root) then (
    printf "Error: nixos-configs not found at %s\n" configs_root;
    exit 1
  );

  (* Verify the flake has this build config *)
  let check_cmd = sprintf "nix flake show %s --json 2>/dev/null | grep -q '\"%s\"'"
    configs_root build_name in
  let result = Sys.command check_cmd in
  if result <> 0 then (
    printf "Warning: Could not verify that '%s' exists as a flake config in %s\n" build_name configs_root;
    printf "Continuing anyway...\n\n"
  );

  (* Check if remote name already exists *)
  let remotes = read_remotes () in
  if List.exists (fun r -> r.name = remote_name) remotes then (
    printf "Error: Remote '%s' already exists. Use 'j remote list' to see configured remotes.\n" remote_name;
    exit 1
  );

  (* Clone/update nixos-configs on the init machine *)
  let flake_path = "/tmp/nixos-configs" in
  let clone_cmd = sprintf
    "ssh %s@%s 'if [ -d %s ]; then cd %s && git pull; else git clone git@github.com:jowi-dev/nixos-configs.git %s; fi'"
    user init_host flake_path flake_path flake_path in
  printf "Cloning/updating nixos-configs on %s...\n" init_host;
  let result = Sys.command clone_cmd in
  if result <> 0 then (
    printf "Error: Failed to clone/update configuration on %s\n" init_host;
    exit 1
  );

  (* Deploy the build config *)
  let rebuild_cmd = sprintf
    "ssh -t %s@%s 'cd %s && sudo nixos-rebuild switch --flake .#%s --impure'"
    user init_host flake_path build_name in
  printf "\nRebuilding NixOS with flake config '%s'...\n" build_name;
  printf "This may take a few minutes...\n";
  flush stdout;
  let result = Sys.command rebuild_cmd in
  if result <> 0 then (
    printf "Error: NixOS rebuild failed\n";
    exit 1
  );

  (* Register the remote *)
  let final_host = remote_name ^ ".local" in
  let new_remote = { name = remote_name; host = final_host; user } in
  write_remotes (new_remote :: remotes);

  printf "\n✓ Successfully deployed '%s' config to init machine\n" build_name;
  printf "✓ Registered remote '%s' at %s@%s\n" remote_name user final_host;
  printf "\nThe machine's hostname is now '%s'. You can:\n" build_name;
  printf "  ssh %s@%s\n" user final_host;
  printf "  j remote ssh %s\n" remote_name;
  printf "  j remote deploy %s\n" remote_name

let remote_discover () =
  printf "Scanning for devices on the local network (3 seconds)...\n\n";
  flush stdout;

  (* Use dns-sd to browse for workstation services published by Avahi *)
  let tmpfile = Filename.temp_file "j-discover" ".txt" in
  let cmd = sprintf "dns-sd -B _workstation._tcp . > \"%s\" 2>/dev/null & PID=$!; sleep 3; kill $PID 2>/dev/null; wait $PID 2>/dev/null" tmpfile in
  let _ = Sys.command cmd in

  let ic = open_in tmpfile in
  let devices = ref [] in
  (try while true do
    let line = input_line ic in
    (* Lines look like: "... Add ... local. _workstation._tcp. hostname [xx:xx:xx:xx:xx:xx]" *)
    if String.length line > 0 then
      let parts = String.split_on_char ' ' line in
      let non_empty = List.filter (fun s -> String.length s > 0) parts in
      (* Find lines with "Add" that contain instance names *)
      if List.mem "Add" non_empty then
        (* The instance name is everything after _workstation._tcp. *)
        let rec find_after_service = function
          | [] -> None
          | x :: rest when String.length x > 0 && String.get x 0 = '_' ->
            (* Skip service type fields, instance name follows *)
            (match rest with
            | [] -> None
            | _ -> Some (String.concat " " rest))
          | _ :: rest -> find_after_service rest
        in
        match find_after_service (List.rev (List.rev non_empty)) with
        | Some name ->
          (* Extract hostname (before the MAC address in brackets) *)
          let hostname = match String.split_on_char '[' name with
            | h :: _ -> String.trim h
            | [] -> name
          in
          if not (List.mem hostname !devices) then
            devices := hostname :: !devices
        | None -> ()
  done with End_of_file -> ());
  close_in ic;
  (try Sys.remove tmpfile with _ -> ());

  let found = List.rev !devices in
  if List.length found = 0 then
    printf "No mDNS devices found. Make sure target machines have Avahi enabled.\n"
  else (
    printf "Discoverable devices:\n";
    List.iter (fun name ->
      printf "  %s  →  %s.local\n" name name
    ) found
  )

let handle_remote_command args =
  match args with
  | ["add"; name; host] -> remote_add name host "root"
  | ["add"; name; host; user] -> remote_add name host user
  | ["list"] -> remote_list ()
  | ["pull"; name] -> remote_pull name
  | ["deploy"; name] -> remote_deploy name
  | ["ssh"; name] -> remote_ssh name
  | ["flash"] -> remote_flash ()
  | ["pull-key"; name] -> remote_pull_key name
  | ["discover"] -> remote_discover ()
  | ["setup"; build] -> remote_setup build build
  | ["setup"; build; "--name"; name] -> remote_setup build name
  | _ ->
    print_endline "Error: Invalid remote command";
    print_endline "Usage: j remote <add|list|pull|deploy|ssh|flash|pull-key|discover|setup> [args]";
    show_help ();
    exit 1

let handle_project_command args =
  match args with
  | [] -> project_search None
  | ["search"] -> project_search None
  | ["search"; pattern] -> project_search (Some pattern)
  | ["files"] -> project_files ()
  | ["explore"] -> project_explore ()
  | ["plan"; topic] -> project_plan topic
  | _ ->
    print_endline "Error: Invalid project command";
    print_endline "Usage: j project <search [pattern]|files|explore|plan <topic>>";
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

(* Config command functions *)
let config_load () =
  printf "Loading config from remote repository...\n";

  (* Pull main repository *)
  printf "\n=== Pulling main repository ===\n";
  let pull_cmd = sprintf "cd \"%s\" && git pull" repo_root in
  let exit_code = Sys.command pull_cmd in
  if exit_code <> 0 then (
    printf "Error: Failed to pull from main repository\n";
    exit 1
  );

  (* Update submodules *)
  printf "\n=== Updating submodules ===\n";
  let submodule_cmd = sprintf "cd \"%s\" && git submodule update --init --recursive --remote" repo_root in
  let exit_code = Sys.command submodule_cmd in
  if exit_code <> 0 then (
    printf "Warning: Some submodules may not have updated correctly\n"
  );

  printf "\n✓ Successfully loaded config from remote\n"

let config_save message_opt =
  let today = get_today_date () in
  let commit_msg = match message_opt with
    | Some msg -> msg
    | None -> sprintf "updates %s" today in

  printf "Saving config to remote repository...\n";

  (* Commit and push owned submodules first, so main repo records updated pointers *)
  let owned_submodules = ["logs"; "public_logs"] in
  List.iter (fun sub ->
    let sub_path = Filename.concat repo_root sub in
    if file_exists sub_path then (
      printf "\n=== %s ===\n" sub;

      (* Ensure we're on main *)
      let checkout_cmd = sprintf "cd \"%s\" && git checkout main 2>/dev/null || git checkout -b main" sub_path in
      let _ = Sys.command checkout_cmd in

      (* Check for changes *)
      let diff_cmd = sprintf "cd \"%s\" && git status --short" sub_path in
      let ic = Unix.open_process_in diff_cmd in
      let has_output = (try let _ = input_line ic in true with End_of_file -> false) in
      let _ = Unix.close_process_in ic in

      if has_output then (
        let add_cmd = sprintf "cd \"%s\" && git add ." sub_path in
        let _ = Sys.command add_cmd in
        let commit_cmd = sprintf "cd \"%s\" && git commit -m \"%s\"" sub_path commit_msg in
        let _ = Sys.command commit_cmd in
        ()
      );

      (* Push *)
      let push_cmd = sprintf "cd \"%s\" && git push -u origin main" sub_path in
      let exit_code = Sys.command push_cmd in
      if exit_code <> 0 then
        printf "Warning: Failed to push %s\n" sub
      else
        printf "✓ Pushed %s\n" sub
    )
  ) owned_submodules;

  (* Now commit and push main repo with updated submodule pointers *)
  printf "\n=== Main repository ===\n";
  let add_cmd = sprintf "cd \"%s\" && git add ." repo_root in
  let _ = Sys.command add_cmd in

  let diff_cmd = sprintf "cd \"%s\" && git diff --cached --quiet" repo_root in
  let has_changes = Sys.command diff_cmd <> 0 in

  if not has_changes then (
    printf "No changes to commit in main repository\n"
  ) else (
    let commit_cmd = sprintf "cd \"%s\" && git commit -m \"%s\"" repo_root commit_msg in
    let exit_code = Sys.command commit_cmd in
    if exit_code <> 0 then (
      printf "Error: Failed to commit changes\n";
      exit 1
    );
    printf "✓ Committed changes\n"
  );

  let push_cmd = sprintf "cd \"%s\" && git push" repo_root in
  let exit_code = Sys.command push_cmd in
  if exit_code <> 0 then (
    printf "Error: Failed to push to remote\n";
    exit 1
  );

  printf "\n✓ Successfully saved config to remote\n"

let handle_config_command args =
  match args with
  | ["load"] -> config_load ()
  | ["save"] -> config_save None
  | ["save"; message] -> config_save (Some message)
  | _ ->
    print_endline "Error: Invalid config command";
    print_endline "Usage: j config <load|save [message]>";
    show_help ();
    exit 1

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

  (* Check version sync for all commands except help and install *)
  (match args with
  | [] | ["install"] -> ()
  | _ -> check_version_sync ()
  );

  match args with
  | [] -> show_help ()
  | ["install"] -> install_self ()
  | ["export"; "--all"] -> export_all_packages ()
  | "config" :: config_args -> handle_config_command config_args
  | "nvim" :: nvim_args -> handle_nvim_command nvim_args
  | "project" :: project_args -> handle_project_command project_args
  | "plan" :: plan_args -> handle_plan_command plan_args
  | "til" :: til_args -> handle_til_command til_args
  | "remote" :: remote_args -> handle_remote_command remote_args
  | [action; package] -> sync_config force_flag action package
  | _ ->
    print_endline "Error: Invalid arguments";
    show_help ();
    exit 1
