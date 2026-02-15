open Printf
open Common

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
  print_endline "  remote flash [--builder name] [--disk /dev/diskN]  Build and flash installer ISO to USB";
  print_endline "  remote pull-key <name>           Pull SSH keys from remote for secrets.nix";
  print_endline "  remote discover                  Scan for mDNS-discoverable devices on LAN";
  print_endline "  remote setup <build> [--name n]  Deploy build config to init machine and register remote";
  print_endline "  remote screen-off <name>         Turn off screen on remote machine";
  print_endline "  remote screen-on <name>          Turn on screen on remote machine";
  print_endline "";
  print_endline "Options:";
  print_endline "  --force          Skip timestamp checks and prompts";
  print_endline "";
  print_endline "Available packages:";
  List.iter (fun (name, repo_path, sys_path) ->
    printf "  %s: %s/%s <-> %s\n" name repo_root repo_path sys_path
  ) packages

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

  (match args with
  | [] | ["install"] -> ()
  | _ -> check_version_sync ()
  );

  match args with
  | [] -> show_help ()
  | ["install"] -> Config.install_self ()
  | ["export"; "--all"] -> Config.export_all_packages ()
  | "config" :: config_args -> Config.handle_command config_args
  | "nvim" :: nvim_args -> Nvim.handle_command nvim_args
  | "project" :: project_args -> Project.handle_command project_args
  | "plan" :: plan_args -> Plan.handle_command plan_args
  | "til" :: til_args -> Til.handle_command til_args
  | "remote" :: remote_args -> Remote.handle_command remote_args
  | [action; package] -> Config.sync_config force_flag action package
  | _ ->
    print_endline "Error: Invalid arguments";
    show_help ();
    exit 1
