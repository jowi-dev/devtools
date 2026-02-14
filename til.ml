open Printf
open Common

let ensure_dir () =
  let dir = til_path () in
  if not (file_exists dir) then (
    let cmd = sprintf "mkdir -p \"%s\"" dir in
    let _ = Sys.command cmd in
    ()
  )

let get_file_path topic =
  Filename.concat (til_path ()) (topic ^ ".md")

let get_template topic =
  let today = get_today_date () in
  sprintf "# TIL: %s\n\n## %s\n- \n" topic today

let edit topic =
  ensure_dir ();
  let til_file = get_file_path topic in

  if not (file_exists til_file) then (
    let template = get_template topic in
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

  if not is_public then ensure_dir ();

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

let search pattern =
  ensure_dir ();
  let dir = til_path () in

  printf "Searching TILs for: %s\n\n" pattern;

  let cmd = sprintf "rg -i --color=always \"%s\" \"%s\"/*.md 2>/dev/null" pattern dir in
  let exit_code = Sys.command cmd in
  if exit_code <> 0 then
    printf "No matches found\n"

let export topic =
  let private_til = get_file_path topic in

  if not (file_exists private_til) then (
    printf "Error: TIL '%s' not found at %s\n" topic private_til;
    printf "Create it first with: j til %s\n" topic;
    exit 1
  );

  printf "Opening TIL for polishing...\n";
  let editor = get_editor () in
  let edit_cmd = sprintf "%s \"%s\"" editor private_til in
  let _ = Sys.command edit_cmd in

  let public_til_dir = public_til_path () in
  let public_til = Filename.concat public_til_dir (topic ^ ".md") in

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

  printf "Exported '%s' to public repo at %s\n" topic public_til;
  printf "Don't forget to commit and push public_logs!\n"

let handle_command args =
  match args with
  | ["list"] ->
    list_tils false
  | ["list"; "--public"] ->
    list_tils true
  | ["search"; pattern] ->
    search pattern
  | ["export"; topic] ->
    export topic
  | [topic] ->
    edit topic
  | _ ->
    print_endline "Error: Invalid til command";
    print_endline "Usage: j til <topic|list [--public]|search <pattern>|export <topic>>";
    exit 1
