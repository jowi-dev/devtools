open Printf
open Sys

(* Package mappings: (name, repo_path, system_path) *)
let packages = [
  ("nvim", "nvim", Filename.concat (Sys.getenv "HOME") ".config/nvim");
  ("starship", "starship.toml", Filename.concat (Sys.getenv "HOME") ".config/starship.toml");
  ("fish", "fish", Filename.concat (Sys.getenv "HOME") ".config/fish");
  ("tmux", "tmux.conf", Filename.concat (Sys.getenv "HOME") ".config/tmux/tmux.conf");
]

let install_location = "/usr/local/bin/j"

let repo_root = Filename.dirname (Sys.argv.(0))

let show_help () =
  print_endline "j - Jowi's dev environment sync tool";
  print_endline "";
  print_endline "Usage: j <import|export|install> <package>";
  print_endline "";
  print_endline "Commands:";
  print_endline "  import <package>  Copy config from system location to repo";
  print_endline "  export <package>  Copy config from repo to system location";
  print_endline "  install          Install j command to /usr/local/bin";
  print_endline "";
  print_endline "Available packages:";
  List.iter (fun (name, repo_path, sys_path) ->
    printf "  %s: %s/%s <-> %s\n" name repo_root repo_path sys_path
  ) packages

let file_exists path =
  try
    let _ = Unix.stat path in true
  with Unix.Unix_error _ -> false

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

let sync_config action package_name =
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
      printf "✓ Exported %s successfully\n" package_name
    
    | "import" ->
      printf "Importing %s: %s -> %s\n" package_name sys_path repo_full_path;
      
      if not (file_exists sys_path) then (
        printf "Error: System config does not exist: %s\n" sys_path;
        exit 1
      );
      
      backup_if_exists repo_full_path;
      copy_recursive sys_path repo_full_path;
      printf "✓ Imported %s successfully\n" package_name
    
    | _ ->
      print_endline "Error: Action must be 'import' or 'export'";
      show_help ();
      exit 1

let () =
  match Array.length Sys.argv with
  | 1 -> show_help ()
  | 2 when Sys.argv.(1) = "install" -> install_self ()
  | 3 -> 
    let action = Sys.argv.(1) in
    let package = Sys.argv.(2) in
    sync_config action package
  | _ ->
    print_endline "Error: Invalid arguments";
    show_help ();
    exit 1