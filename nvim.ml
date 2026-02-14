open Printf
open Common

let plugins_path () =
  Filename.concat repo_root "nvim/pack/plugins/start"

let extract_plugin_name_from_url url =
  let parts = String.split_on_char '/' url in
  match List.rev parts with
  | name :: _ when String.ends_with ~suffix:".git" name ->
    String.sub name 0 (String.length name - 4)
  | name :: _ -> name
  | [] -> failwith "Invalid git URL"

let install_plugin url custom_name_opt =
  printf "Installing nvim plugin from %s\n" url;

  let plugin_name = match custom_name_opt with
    | Some name -> name
    | None -> extract_plugin_name_from_url url in

  let plugins_dir = plugins_path () in
  let plugin_path = Filename.concat plugins_dir plugin_name in

  if file_exists plugin_path then (
    printf "Error: Plugin '%s' already exists at %s\n" plugin_name plugin_path;
    exit 1
  );

  let _ = Sys.command (sprintf "mkdir -p \"%s\"" plugins_dir) in

  let submodule_path = sprintf "nvim/pack/plugins/start/%s" plugin_name in
  let add_cmd = sprintf "cd \"%s\" && git submodule add \"%s\" \"%s\"" repo_root url submodule_path in
  let exit_code = Sys.command add_cmd in

  if exit_code <> 0 then (
    printf "Error: Failed to add plugin as submodule\n";
    exit 1
  );

  printf "Successfully installed plugin '%s'\n" plugin_name;
  printf "  Location: %s\n" plugin_path

let list_plugins () =
  let plugins_dir = plugins_path () in

  if not (file_exists plugins_dir) then (
    print_endline "No nvim plugins directory found";
    exit 0
  );

  printf "Installed nvim plugins in %s:\n" plugins_dir;
  print_endline "";

  let list_cmd = sprintf "ls -la \"%s\"" plugins_dir in
  let _ = Sys.command list_cmd in
  ()

let remove_plugin name =
  printf "Removing nvim plugin '%s'\n" name;

  let plugins_dir = plugins_path () in
  let plugin_path = Filename.concat plugins_dir name in

  if not (file_exists plugin_path) then (
    printf "Error: Plugin '%s' not found at %s\n" name plugin_path;
    exit 1
  );

  let submodule_path = sprintf "nvim/pack/plugins/start/%s" name in

  let deinit_cmd = sprintf "cd \"%s\" && git submodule deinit -f \"%s\"" repo_root submodule_path in
  let rm_cmd = sprintf "cd \"%s\" && git rm -f \"%s\"" repo_root submodule_path in
  let cleanup_cmd = sprintf "cd \"%s\" && rm -rf \".git/modules/%s\"" repo_root submodule_path in

  let exit1 = Sys.command deinit_cmd in
  let exit2 = Sys.command rm_cmd in
  let _ = Sys.command cleanup_cmd in

  if exit1 <> 0 || exit2 <> 0 then (
    printf "Warning: Some cleanup commands failed, but plugin directory removed\n"
  );

  printf "Successfully removed plugin '%s'\n" name

let update_plugin name =
  printf "Updating nvim plugin '%s'\n" name;

  let plugins_dir = plugins_path () in
  let plugin_path = Filename.concat plugins_dir name in

  if not (file_exists plugin_path) then (
    printf "Error: Plugin '%s' not found at %s\n" name plugin_path;
    exit 1
  );

  let submodule_path = sprintf "nvim/pack/plugins/start/%s" name in

  let update_cmd = sprintf "cd \"%s\" && git submodule update --remote \"%s\"" repo_root submodule_path in
  let exit_code = Sys.command update_cmd in

  if exit_code <> 0 then (
    printf "Error: Failed to update plugin '%s'\n" name;
    exit 1
  );

  printf "Successfully updated plugin '%s' to latest version\n" name

let handle_command args =
  match args with
  | ["install"; url] -> install_plugin url None
  | ["install"; url; custom_name] -> install_plugin url (Some custom_name)
  | ["list"] -> list_plugins ()
  | ["update"; name] -> update_plugin name
  | ["remove"; name] -> remove_plugin name
  | _ ->
    print_endline "Error: Invalid nvim command";
    print_endline "Usage: j nvim <install|list|update|remove> [plugin-url|plugin-name] [custom-name]";
    exit 1
