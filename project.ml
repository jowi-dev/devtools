open Printf
open Common

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
          if trimmed = "[env]" then
            find_project_name true
          else if in_env_section && String.length trimmed > 0 then
            if String.starts_with ~prefix:"PROJECT_NAME" trimmed then
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

let search pattern_opt dir_opt =
  let pattern = match pattern_opt with
    | Some p -> p
    | None -> "" in
  let dir = match dir_opt with
    | Some d -> d
    | None -> "." in

  printf "Searching %s for: %s\n" dir (if pattern = "" then "(all files)" else pattern);
  flush stdout;

  let rg_cmd = if pattern = "" then
    sprintf "rg --line-number --column --no-heading --color=always . \"%s\"" dir
  else
    sprintf "rg --line-number --column --no-heading --color=always \"%s\" \"%s\"" pattern dir in

  let fzf_cmd = sprintf "%s | fzf --ansi --delimiter=: \
    --preview 'bat --color=always --highlight-line {2} {1}' \
    --preview-window 'right:60%%:+{2}/2' \
    --bind 'ctrl-o:execute(nvim {1} +{2})' \
    --bind 'enter:execute(nvim {1} +{2})'" rg_cmd in

  let exit_code = Sys.command fzf_cmd in
  if exit_code <> 0 && exit_code <> 130 then
    printf "Search failed or cancelled\n"

let files dir_opt =
  let dir = match dir_opt with
    | Some d -> d
    | None -> "." in
  let has_fd = Sys.command "which fd > /dev/null 2>&1" = 0 in

  let find_cmd = if has_fd then
    sprintf "fd --type f --hidden --exclude .git . \"%s\"" dir
  else
    let is_git = Sys.command "git rev-parse --is-inside-work-tree > /dev/null 2>&1" = 0 in
    if is_git then
      sprintf "git -C \"%s\" ls-files --cached --others --exclude-standard" dir
    else
      sprintf "find \"%s\" -type f -not -path '*/\\.git/*'" dir in

  let fzf_cmd = sprintf "%s | fzf --preview 'bat --color=always {}' --preview-window 'right:60%%' --bind 'enter:execute(nvim {})'" find_cmd in

  let exit_code = Sys.command fzf_cmd in
  if exit_code <> 0 && exit_code <> 130 then
    printf "Search failed or cancelled\n"

let explore () =
  let explorer = get_file_explorer () in
  let exit_code = Sys.command explorer in
  if exit_code <> 0 then
    printf "Failed to launch file explorer\n"

let plan topic =
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

    let subdir = if machine_type = "work" then "work" else "projects" in
    let plan_dir = Filename.concat (logs_root ()) subdir in
    printf "Plan directory: %s\n" plan_dir;
    flush stdout;

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

    printf "Opening in editor...\n";
    flush stdout;
    let editor = get_editor () in
    let cmd = sprintf "%s \"%s\"" editor filepath in
    printf "Running: %s\n" cmd;
    flush stdout;
    let _ = Sys.command cmd in
    ()

let handle_command args =
  match args with
  | [] -> search None None
  | ["search"] -> search None None
  | ["search"; pattern] -> search (Some pattern) None
  | ["search"; pattern; dir] -> search (Some pattern) (Some dir)
  | ["files"] -> files None
  | ["files"; dir] -> files (Some dir)
  | ["explore"] -> explore ()
  | ["plan"; topic] -> plan topic
  | _ ->
    print_endline "Error: Invalid project command";
    print_endline "Usage: j project <search [pattern] [dir]|files [dir]|explore|plan <topic>>";
    exit 1
