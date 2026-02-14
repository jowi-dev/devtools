open Printf
open Common

let install_self () =
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

  let install_dir = Filename.dirname install_location in
  if not (file_exists install_dir) then (
    let cmd = sprintf "sudo mkdir -p \"%s\"" install_dir in
    let exit_code = Sys.command cmd in
    if exit_code <> 0 then (
      printf "Error: Failed to create directory %s\n" install_dir;
      exit 1
    )
  );

  if file_exists install_location then (
    printf "Backing up existing j to %s.backup\n" install_location;
    let backup_cmd = sprintf "sudo cp \"%s\" \"%s.backup\"" install_location install_location in
    let _ = Sys.command backup_cmd in
    ()
  );

  let install_cmd = sprintf "sudo cp \"%s\" \"%s\"" source_exe install_location in
  let exit_code = Sys.command install_cmd in
  if exit_code <> 0 then (
    printf "Error: Failed to install j to %s\n" install_location;
    exit 1
  );

  let chmod_cmd = sprintf "sudo chmod +x \"%s\"" install_location in
  let _ = Sys.command chmod_cmd in

  let xattr_cmd = sprintf "sudo xattr -c \"%s\" 2>/dev/null || true" install_location in
  let _ = Sys.command xattr_cmd in

  let codesign_cmd = sprintf "sudo codesign -s - -f \"%s\" 2>/dev/null || true" install_location in
  let _ = Sys.command codesign_cmd in

  printf "Successfully installed j to %s\n" install_location;
  print_endline "You can now use 'j' from anywhere!"

let export_all_packages () =
  print_endline "Exporting all packages to system locations...";
  print_endline "";

  let failed_exports = ref [] in

  List.iter (fun (name, repo_path, sys_path) ->
    let repo_full_path = Filename.concat repo_root repo_path in

    printf "Exporting %s: %s -> %s\n" name repo_full_path sys_path;

    if not (file_exists repo_full_path) then (
      printf "  Skipping %s (source does not exist)\n" name;
      failed_exports := name :: !failed_exports
    ) else (
      try
        ensure_parent_dir sys_path;
        copy_recursive repo_full_path sys_path;
        printf "  Exported %s successfully\n" name
      with
      | Failure msg ->
        printf "  Failed to export %s: %s\n" name msg;
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
      printf "Exported %s successfully\n" package_name;

      if package_name = "fish" then (
        printf "Sourcing fish config...\n";
        let source_cmd = "fish -c 'source ~/.config/fish/config.fish'" in
        let _ = Sys.command source_cmd in
        printf "Fish config reloaded\n"
      )

    | "import" ->
      printf "Importing %s: %s -> %s\n" package_name sys_path repo_full_path;

      if not (file_exists sys_path) then (
        printf "Error: System config does not exist: %s\n" sys_path;
        exit 1
      );

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
          printf "System config is not newer than repo config.\n";
        );

        if not (read_yes_no ()) then (
          print_endline "Import cancelled.";
          exit 0
        )
      );

      copy_recursive sys_path repo_full_path;
      printf "Imported %s successfully\n" package_name

    | _ ->
      print_endline "Error: Action must be 'import' or 'export'";
      exit 1

let config_load () =
  printf "Loading config from remote repository...\n";

  printf "\n=== Pulling main repository ===\n";
  let pull_cmd = sprintf "cd \"%s\" && git pull" repo_root in
  let exit_code = Sys.command pull_cmd in
  if exit_code <> 0 then (
    printf "Error: Failed to pull from main repository\n";
    exit 1
  );

  printf "\n=== Updating submodules ===\n";
  let submodule_cmd = sprintf "cd \"%s\" && git submodule update --init --recursive --remote" repo_root in
  let exit_code = Sys.command submodule_cmd in
  if exit_code <> 0 then (
    printf "Warning: Some submodules may not have updated correctly\n"
  );

  printf "\nSuccessfully loaded config from remote\n"

let config_save message_opt =
  let today = get_today_date () in
  let commit_msg = match message_opt with
    | Some msg -> msg
    | None -> sprintf "updates %s" today in

  printf "Saving config to remote repository...\n";

  let owned_submodules = ["logs"; "public_logs"] in
  List.iter (fun sub ->
    let sub_path = Filename.concat repo_root sub in
    if file_exists sub_path then (
      printf "\n=== %s ===\n" sub;

      let checkout_cmd = sprintf "cd \"%s\" && git checkout main 2>/dev/null || git checkout -b main" sub_path in
      let _ = Sys.command checkout_cmd in

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

      let push_cmd = sprintf "cd \"%s\" && git push -u origin main" sub_path in
      let exit_code = Sys.command push_cmd in
      if exit_code <> 0 then
        printf "Warning: Failed to push %s\n" sub
      else
        printf "Pushed %s\n" sub
    )
  ) owned_submodules;

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
    printf "Committed changes\n"
  );

  let push_cmd = sprintf "cd \"%s\" && git push" repo_root in
  let exit_code = Sys.command push_cmd in
  if exit_code <> 0 then (
    printf "Error: Failed to push to remote\n";
    exit 1
  );

  printf "\nSuccessfully saved config to remote\n"

let handle_command args =
  match args with
  | ["load"] -> config_load ()
  | ["save"] -> config_save None
  | ["save"; message] -> config_save (Some message)
  | _ ->
    print_endline "Error: Invalid config command";
    print_endline "Usage: j config <load|save [message]>";
    exit 1
