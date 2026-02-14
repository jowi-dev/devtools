open Printf

let install_location = "/usr/local/bin/j"

let packages = [
  ("nvim", "nvim", Filename.concat (Sys.getenv "HOME") ".config/nvim");
  ("starship", "starship.toml", Filename.concat (Sys.getenv "HOME") ".config/starship.toml");
  ("fish", "fish", Filename.concat (Sys.getenv "HOME") ".config/fish");
  ("tmux", ".tmux.conf", Filename.concat (Sys.getenv "HOME") ".tmux.conf");
  ("ghostty", "ghostty-config", Filename.concat (Sys.getenv "HOME") ".config/ghostty/config");
  ("git", "git-config", Filename.concat (Sys.getenv "HOME") ".config/git/config");
]

let repo_root =
  try
    Sys.getenv "DEVTOOLS_ROOT"
  with Not_found ->
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
  | (Some _, None) -> true
  | (None, _) -> false

let format_time timestamp =
  let tm = Unix.localtime timestamp in
  sprintf "%04d-%02d-%02d %02d:%02d:%02d"
    (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1) tm.Unix.tm_mday
    tm.Unix.tm_hour tm.Unix.tm_min tm.Unix.tm_sec

let copy_recursive src dest =
  try
    let src_stat = Unix.stat src in
    (try
      let dest_stat = Unix.stat dest in
      let types_conflict = match (src_stat.Unix.st_kind, dest_stat.Unix.st_kind) with
        | (Unix.S_DIR, Unix.S_DIR) -> false
        | (Unix.S_DIR, _) -> true
        | (_, Unix.S_DIR) -> true
        | _ -> false
      in
      if types_conflict then (
        printf "Removing conflicting destination: %s\n" dest;
        let rm_cmd = sprintf "rm -rf \"%s\"" dest in
        let _ = Sys.command rm_cmd in
        ()
      )
    with Unix.Unix_error _ -> ());
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

let read_yes_no () =
  print_string "Proceed? (y/n): ";
  flush stdout;
  let response = read_line () in
  String.lowercase_ascii (String.trim response) = "y"

let get_editor () =
  try Sys.getenv "EDITOR"
  with Not_found -> "nvim"

let get_file_explorer () =
  try Sys.getenv "FILE_EXPLORER"
  with Not_found -> "nnn"

let get_machine_type () =
  try Sys.getenv "MACHINE_TYPE"
  with Not_found -> "personal"

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

let check_version_sync () =
  let current_exe = Sys.argv.(0) in
  if current_exe = install_location && file_exists install_location then (
    let source_file = Filename.concat repo_root "j.ml" in
    match (get_modification_time source_file, get_modification_time install_location) with
    | (Some source_time, Some installed_time) ->
      if source_time > installed_time then (
        printf "Warning: Your j source code has been updated!\n";
        printf "   Run 'j install' to update the installed version.\n";
        printf "   (Source modified: %s)\n\n" (format_time source_time)
      )
    | _ -> ()
  )
