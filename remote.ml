open Printf
open Common

type remote = {
  name: string;
  host: string;
  user: string;
}

let ensure_configs_dir () =
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
  ensure_configs_dir ();
  let path = remotes_config_path () in
  let oc = open_out path in
  List.iter (fun r ->
    fprintf oc "%s,%s,%s\n" r.name r.host r.user
  ) remotes;
  close_out oc

let find name =
  let remotes = read_remotes () in
  List.find_opt (fun r -> r.name = name) remotes

let find_live_remote ?exclude () =
  let remotes = read_remotes () in
  let candidates = match exclude with
    | None -> remotes
    | Some name -> List.filter (fun r -> r.name <> name) remotes
  in
  List.find_opt (fun r ->
    let cmd = sprintf "ssh -o ConnectTimeout=3 -o BatchMode=yes %s@%s 'true' 2>/dev/null"
      r.user r.host in
    Sys.command cmd = 0
  ) candidates

let add name host user =
  let remotes = read_remotes () in
  (match List.find_opt (fun r -> r.name = name) remotes with
  | Some _ ->
    printf "Error: Remote '%s' already exists\n" name;
    exit 1
  | None -> ());

  let new_remote = { name; host; user } in
  let updated_remotes = new_remote :: remotes in
  write_remotes updated_remotes;
  printf "Added remote '%s' (%s@%s)\n" name user host

let list () =
  let remotes = read_remotes () in
  if List.length remotes = 0 then
    print_endline "No remotes configured. Use 'j remote add <name> <host> [user]' to add one."
  else begin
    print_endline "Configured remotes:";
    List.iter (fun r ->
      printf "  %s: %s@%s\n" r.name r.user r.host
    ) remotes
  end

let pull name =
  match find name with
  | None ->
    printf "Error: Remote '%s' not found. Use 'j remote list' to see configured remotes.\n" name;
    exit 1
  | Some remote ->
    ensure_configs_dir ();
    let machine_dir = Filename.concat (nixos_configs_root ()) ("machines/" ^ name) in
    let cmd = sprintf "mkdir -p \"%s\"" machine_dir in
    let _ = Sys.command cmd in

    printf "Pulling NixOS configuration from %s@%s...\n" remote.user remote.host;

    let scp_config = sprintf "scp %s@%s:/etc/nixos/configuration.nix \"%s/configuration.nix\""
      remote.user remote.host machine_dir in
    printf "Running: %s\n" scp_config;
    let result = Sys.command scp_config in
    if result <> 0 then (
      printf "Error: Failed to pull configuration.nix\n";
      exit 1
    );

    let scp_hardware = sprintf "scp %s@%s:/etc/nixos/hardware-configuration.nix \"%s/hardware-configuration.nix\""
      remote.user remote.host machine_dir in
    printf "Running: %s\n" scp_hardware;
    let result = Sys.command scp_hardware in
    if result <> 0 then (
      printf "Warning: Failed to pull hardware-configuration.nix (may not exist)\n"
    );

    printf "Successfully pulled configuration to %s\n" machine_dir;
    printf "\nNext steps:\n";
    printf "  1. Review the configuration: nvim %s/configuration.nix\n" machine_dir;
    printf "  2. Commit to git: cd %s && git add . && git commit -m 'Initial config for %s'\n"
      (nixos_configs_root ()) name;
    printf "  3. Deploy changes: j remote deploy %s\n" name

let deploy name =
  match find name with
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

    let flake_path = "/etc/nixos/nixos-configs" in
    let clone_cmd = sprintf
      "ssh %s@%s 'if [ -d %s ]; then cd %s && git pull; else git clone git@github.com:jowi-dev/nixos-configs.git %s; fi'"
      remote.user remote.host flake_path flake_path flake_path in
    printf "Cloning/updating from GitHub: %s\n" clone_cmd;
    let result = Sys.command clone_cmd in
    if result <> 0 then (
      printf "Error: Failed to clone/update configuration from GitHub\n";
      exit 1
    );

    (* Check if github-nix-token exists and bootstrap NIX_CONFIG if needed *)
    let check_token_cmd = sprintf "ssh %s@%s '[ -f /etc/nixos/secrets/github-nix-token ]'" remote.user remote.host in
    let has_token = Sys.command check_token_cmd = 0 in

    let rebuild_cmd = if has_token then
      sprintf "ssh -t %s@%s 'cd %s && TOKEN=$(sudo cat /etc/nixos/secrets/github-nix-token | tr -d \"\\n\") && sudo NIX_CONFIG=\"access-tokens = $TOKEN\" nixos-rebuild switch --flake .#%s --impure'"
        remote.user remote.host flake_path name
    else
      sprintf "ssh -t %s@%s 'cd %s && sudo nixos-rebuild switch --flake .#%s --impure'"
        remote.user remote.host flake_path name
    in
    printf "\nRebuilding NixOS with flake: %s\n" (if has_token then "(with GitHub token bootstrap)" else rebuild_cmd);
    printf "This may take a few minutes (first build will download and compile Rust dependencies)...\n";
    flush stdout;
    let result = Sys.command rebuild_cmd in
    if result <> 0 then (
      printf "Error: NixOS rebuild failed\n";
      exit 1
    );

    let notify_cmd = sprintf
      "ssh %s@%s 'echo -e \"\\n\\n=== DEPLOYMENT SUCCESSFUL ===\\nHello from Alien!\\nSystem rebuilt via j remote deploy\\n\" | sudo tee /dev/tty1 > /dev/null'"
      remote.user remote.host in
    let _ = Sys.command notify_cmd in

    printf "Successfully deployed and rebuilt %s\n" name

let ssh name =
  match find name with
  | None ->
    printf "Error: Remote '%s' not found. Use 'j remote list' to see configured remotes.\n" name;
    exit 1
  | Some remote ->
    let ssh_cmd = sprintf "ssh %s@%s" remote.user remote.host in
    printf "Connecting to %s@%s...\n" remote.user remote.host;
    let result = Sys.command ssh_cmd in
    exit result

let pull_key name =
  match find name with
  | None ->
    printf "Error: Remote '%s' not found. Use 'j remote list' to see configured remotes.\n" name;
    exit 1
  | Some remote ->
    let configs_root = nixos_configs_root () in

    if not (file_exists configs_root) then (
      printf "Error: nixos-configs not found at %s\n" configs_root;
      exit 1
    );

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

    let github_key_dest = Filename.concat configs_root "github-key" in
    let scp_priv = sprintf "scp %s@%s:~/.ssh/id_ed25519 \"%s\""
      remote.user remote.host github_key_dest in
    printf "Pulling GitHub private key from %s@%s...\n" remote.user remote.host;
    let result = Sys.command scp_priv in
    if result <> 0 then (
      printf "Error: Failed to pull private key from remote\n";
      exit 1
    );

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

    let identity_path = Filename.concat configs_root "identity.nix" in
    let oc = open_out identity_path in
    fprintf oc "{\n";
    fprintf oc "  authorizedKey = \"%s\";\n" local_pubkey;
    fprintf oc "  githubPublicKey = \"%s\";\n" github_pubkey;
    fprintf oc "}\n";
    close_out oc;

    printf "Generated %s\n" identity_path;
    printf "Saved GitHub private key to %s\n" github_key_dest;
    printf "\nidentity.nix should be committed. github-key is gitignored and staged at build time.\n"

let flash builder_opt disk_opt =
  let configs_root = nixos_configs_root () in

  if not (file_exists configs_root) then (
    printf "Error: nixos-configs not found at %s\n" configs_root;
    printf "Clone it first: git clone git@github.com:jowi-dev/nixos-configs.git %s\n" configs_root;
    exit 1
  );

  let github_key_path = Filename.concat configs_root "github-key" in
  if not (file_exists github_key_path) then (
    printf "Warning: github-key not found in %s\n" configs_root;
    printf "   The ISO will be built without GitHub credentials.\n";
    printf "   Generate with: j remote pull-key <name>\n\n"
  );
  let wifi_networks_path = Filename.concat configs_root "wifi-networks.nix" in
  if not (file_exists wifi_networks_path) then (
    printf "Warning: wifi-networks.nix not found in %s\n" configs_root;
    printf "   WiFi will not auto-connect. See wifi-networks.nix.example\n\n"
  );
  let user_password_path = Filename.concat configs_root "user-password.nix" in
  if not (file_exists user_password_path) then (
    printf "Warning: user-password.nix not found in %s\n" configs_root;
    printf "   No console login password will be set.\n\n"
  );

  let _ = Sys.command "sudo -v" in

  printf "Building NixOS installer ISO...\n";
  let builder_args = match builder_opt with
    | None -> ""
    | Some name ->
      let remote = match find name with
        | Some r -> r
        | None ->
          printf "Error: Remote '%s' not found. Use 'j remote list' to see configured remotes.\n" name;
          exit 1
      in
      let home = Sys.getenv "HOME" in
      let key_path = sprintf "%s/.ssh/%s_builder_ed25519" home name in
      if not (file_exists key_path) then (
        printf "Error: Builder SSH key not found at %s\n" key_path;
        printf "Generate one with: ssh-keygen -t ed25519 -f %s\n" key_path;
        exit 1
      );
      printf "Using remote builder: %s@%s\n" remote.user remote.host;
      sprintf " -j0 --builders 'ssh-ng://%s@%s x86_64-linux %s 4' --builders-use-substitutes"
        remote.user remote.host key_path
  in
  let build_cmd = sprintf "cd %s && NIXOS_SECRETS_DIR=%s nix build .#packages.x86_64-linux.installer-iso --impure%s" configs_root configs_root builder_args in
  let result = Sys.command build_cmd in

  if result <> 0 then (
    printf "Error: Failed to build ISO\n";
    exit 1
  );

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

  printf "\nISO built: %s\n\n" iso_file;

  let device = match disk_opt with
    | Some d -> d
    | None ->
      printf "Available USB drives:\n";
      let _ = Sys.command "diskutil list | grep -E '(external|removable)' -B 5" in
      printf "\n";
      printf "Enter USB device (e.g., /dev/disk4): ";
      flush stdout;
      read_line ()
  in

  if disk_opt = None then (
    let confirm_msg = sprintf "This will ERASE ALL DATA on %s. Continue?" device in
    let confirm_cmd = sprintf "gum confirm \"%s\"" confirm_msg in
    let result = Sys.command confirm_cmd in
    if result <> 0 then (
      printf "Cancelled.\n";
      exit 0
    )
  );

  printf "\nUnmounting %s...\n" device;
  let unmount_cmd = sprintf "diskutil unmountDisk %s" device in
  let _ = Sys.command unmount_cmd in

  printf "\nFlashing ISO to %s...\n" device;
  printf "This may take several minutes...\n\n";
  let raw_device = if String.starts_with ~prefix:"/dev/disk" device
    then "/dev/rdisk" ^ String.sub device 9 (String.length device - 9)
    else device in
  let flash_cmd = sprintf "sudo cp %s %s && sync" iso_file raw_device in
  let result = Sys.command flash_cmd in
  if result <> 0 then (
    printf "Error: Failed to flash ISO\n";
    exit 1
  );

  printf "\nEjecting USB drive...\n";
  let eject_cmd = sprintf "diskutil eject %s" device in
  let _ = Sys.command eject_cmd in

  printf "\nUSB drive ready! You can now:\n";
  printf "  1. Boot from this USB on any machine\n";
  printf "  2. It will auto-connect to WiFi and enable SSH\n";
  printf "  3. Deploy with: j remote add <name> <ip> root && j remote deploy <name>\n"

let setup build_name remote_name =
  let init_host = "init.local" in
  let user = "root" in

  printf "Setting up new machine...\n";
  printf "  Build config: %s\n" build_name;
  printf "  Remote name:  %s\n" remote_name;
  printf "  Init host:    %s@%s\n" user init_host;
  printf "\n";

  let configs_root = nixos_configs_root () in
  if not (file_exists configs_root) then (
    printf "Error: nixos-configs not found at %s\n" configs_root;
    exit 1
  );

  let check_cmd = sprintf "nix flake show %s --json 2>/dev/null | grep -q '\"%s\"'"
    configs_root build_name in
  let result = Sys.command check_cmd in
  if result <> 0 then (
    printf "Warning: Could not verify that '%s' exists as a flake config in %s\n" build_name configs_root;
    printf "Continuing anyway...\n\n"
  );

  let remotes = read_remotes () in
  if List.exists (fun r -> r.name = remote_name) remotes then (
    printf "Error: Remote '%s' already exists. Use 'j remote list' to see configured remotes.\n" remote_name;
    exit 1
  );

  printf "Detecting disk on %s...\n" init_host;
  flush stdout;
  let disk_script = String.concat "\n"
    [ "set -euo pipefail";
      "DISK=$(lsblk -d -o NAME,SIZE,TYPE,TRAN,RM -n -b | awk '$3==\"disk\" && $5==\"0\" && $4!=\"usb\" {print $1, $2}' | sort -k2 -n -r | head -1 | awk '{print $1}')";
      "if [ -z \"$DISK\" ]; then echo 'ERROR: No suitable disk found' >&2; exit 1; fi";
      "echo \"/dev/$DISK\"" ] in
  let detect_cmd = sprintf "ssh %s@%s bash <<'NIXSCRIPT'\n%s\nNIXSCRIPT" user init_host disk_script in
  let ic = Unix.open_process_in detect_cmd in
  let disk_dev = (try String.trim (input_line ic) with End_of_file -> "") in
  let _ = Unix.close_process_in ic in
  if disk_dev = "" then (
    printf "Error: No suitable disk found on %s\n" init_host;
    exit 1
  );
  printf "  Selected disk: %s\n" disk_dev;

  let boot_mode_cmd = sprintf "ssh %s@%s '[ -d /sys/firmware/efi ] && echo UEFI || echo BIOS'" user init_host in
  let ic_boot = Unix.open_process_in boot_mode_cmd in
  let boot_mode = (try String.trim (input_line ic_boot) with End_of_file -> "BIOS") in
  let _ = Unix.close_process_in ic_boot in
  printf "  Boot mode: %s\n" boot_mode;

  printf "Partitioning and formatting %s...\n" disk_dev;
  flush stdout;
  let part_script = if boot_mode = "UEFI" then
    String.concat "\n"
      [ "set -euo pipefail";
        sprintf "DISK=%s" disk_dev;
        "case \"$DISK\" in *nvme*|*mmcblk*) PART=\"${DISK}p\" ;; *) PART=\"$DISK\" ;; esac";
        "parted -s \"$DISK\" -- mklabel gpt";
        "parted -s \"$DISK\" -- mkpart ESP fat32 1MiB 513MiB";
        "parted -s \"$DISK\" -- set 1 esp on";
        "parted -s \"$DISK\" -- mkpart swap linux-swap 513MiB 8705MiB";
        "parted -s \"$DISK\" -- mkpart root ext4 8705MiB 100%";
        "sleep 1";
        "mkfs.fat -F 32 \"${PART}1\"";
        "mkswap \"${PART}2\"";
        "mkfs.ext4 -F \"${PART}3\"";
        "mount \"${PART}3\" /mnt";
        "mkdir -p /mnt/boot";
        "mount \"${PART}1\" /mnt/boot";
        "swapon \"${PART}2\"";
        "echo Done" ]
  else
    String.concat "\n"
      [ "set -euo pipefail";
        sprintf "DISK=%s" disk_dev;
        "case \"$DISK\" in *nvme*|*mmcblk*) PART=\"${DISK}p\" ;; *) PART=\"$DISK\" ;; esac";
        "parted -s \"$DISK\" -- mklabel msdos";
        "parted -s \"$DISK\" -- mkpart primary linux-swap 1MiB 8193MiB";
        "parted -s \"$DISK\" -- mkpart primary ext4 8193MiB 100%";
        "parted -s \"$DISK\" -- set 2 boot on";
        "sleep 1";
        "mkswap \"${PART}1\"";
        "mkfs.ext4 -F \"${PART}2\"";
        "mount \"${PART}2\" /mnt";
        "swapon \"${PART}1\"";
        "echo Done" ] in
  let fmt_cmd = sprintf "ssh %s@%s bash <<'NIXSCRIPT'\n%s\nNIXSCRIPT" user init_host part_script in
  let result = Sys.command fmt_cmd in
  if result <> 0 then (
    printf "Error: Disk partitioning/formatting failed\n";
    exit 1
  );

  printf "Generating hardware configuration...\n";
  flush stdout;
  let hwcfg_cmd = sprintf
    "ssh %s@%s 'nixos-generate-config --root /mnt && cp /mnt/etc/nixos/hardware-configuration.nix /etc/nixos/hardware-configuration.nix'"
    user init_host in
  let result = Sys.command hwcfg_cmd in
  if result <> 0 then (
    printf "Error: Failed to generate hardware configuration\n";
    exit 1
  );

  let flake_path = "/etc/nixos/nixos-configs" in
  let clone_cmd = sprintf
    "ssh %s@%s 'if [ -d %s ]; then cd %s && git pull; else git clone git@github.com:jowi-dev/nixos-configs.git %s; fi'"
    user init_host flake_path flake_path flake_path in
  printf "Cloning/updating nixos-configs on %s...\n" init_host;
  let result = Sys.command clone_cmd in
  if result <> 0 then (
    printf "Error: Failed to clone/update configuration on %s\n" init_host;
    exit 1
  );

  printf "Pushing secrets to new machine...\n";
  flush stdout;
  (match find_live_remote () with
  | Some source ->
    printf "Using %s (%s@%s) as secrets source...\n" source.name source.user source.host;
    let push_cmd = sprintf
      "ssh -A %s@%s 'nixos-secrets push %s@%s'"
      source.user source.host user init_host in
    let result = Sys.command push_cmd in
    if result <> 0 then
      printf "Warning: Secret push from %s failed, secrets may be incomplete\n" source.name
  | None ->
    printf "Warning: No live remotes found to source secrets from.\n";
    printf "Falling back to local SCP...\n";
    let mkdir_cmd = sprintf "ssh %s@%s 'mkdir -p /etc/nixos/secrets'" user init_host in
    let _ = Sys.command mkdir_cmd in
    let secret_files = ["github-key"; "github-nix-token"; "wifi-networks.nix"; "user-password.nix"] in
    List.iter (fun filename ->
      let path = Filename.concat (nixos_configs_root ()) filename in
      if file_exists path then (
        let scp_cmd = sprintf "scp %s %s@%s:/etc/nixos/secrets/"
          path user init_host in
        printf "Copying %s to remote...\n" filename;
        let _ = Sys.command scp_cmd in ()
      ) else
        printf "Warning: %s not found, skipping\n" filename
    ) secret_files
  );

  let install_cmd = sprintf
    "ssh -t %s@%s 'nixos-install --root /mnt --flake %s#%s --impure --no-root-passwd'"
    user init_host flake_path build_name in
  printf "\nInstalling NixOS with flake config '%s'...\n" build_name;
  printf "This may take a while...\n";
  flush stdout;
  let result = Sys.command install_cmd in
  if result <> 0 then (
    printf "Error: nixos-install failed\n";
    exit 1
  );

  printf "\nInstallation complete. Rebooting...\n";
  printf "** Remove the USB drive now! **\n";
  flush stdout;
  let _ = Sys.command (sprintf "ssh %s@%s 'reboot' 2>/dev/null" user init_host) in

  let _ = Sys.command (sprintf "ssh-keygen -R %s 2>/dev/null" init_host) in

  let final_host = remote_name ^ ".local" in
  let remote_user = "jowi" in
  let new_remote = { name = remote_name; host = final_host; user = remote_user } in
  write_remotes (new_remote :: remotes);

  printf "\nNixOS installed with '%s' config\n" build_name;
  printf "Registered remote '%s' at %s@%s\n" remote_name remote_user final_host;
  printf "\nAfter reboot, you can:\n";
  printf "  j remote ssh %s\n" remote_name;
  printf "  j remote deploy %s\n" remote_name

let discover () =
  printf "Scanning for devices on the local network (3 seconds)...\n\n";
  flush stdout;

  let tmpfile = Filename.temp_file "j-discover" ".txt" in
  let cmd = sprintf "dns-sd -B _workstation._tcp . > \"%s\" 2>/dev/null & PID=$!; sleep 3; kill $PID 2>/dev/null; wait $PID 2>/dev/null" tmpfile in
  let _ = Sys.command cmd in

  let ic = open_in tmpfile in
  let devices = ref [] in
  (try while true do
    let line = input_line ic in
    if String.length line > 0 then
      let parts = String.split_on_char ' ' line in
      let non_empty = List.filter (fun s -> String.length s > 0) parts in
      if List.mem "Add" non_empty then
        let rec find_after_service = function
          | [] -> None
          | x :: rest when String.length x > 0 && String.get x 0 = '_' ->
            (match rest with
            | [] -> None
            | _ -> Some (String.concat " " rest))
          | _ :: rest -> find_after_service rest
        in
        match find_after_service (List.rev (List.rev non_empty)) with
        | Some name ->
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
      printf "  %s  ->  %s.local\n" name name
    ) found
  )

let screen_off name =
  match find name with
  | None ->
    printf "Error: Remote '%s' not found. Use 'j remote list' to see configured remotes.\n" name;
    exit 1
  | Some remote ->
    printf "Turning off screen on %s...\n" remote.host;
    flush stdout;
    let cmd = sprintf "ssh -t %s@%s 'for bl in /sys/class/backlight/*/brightness; do echo 0 | sudo tee $bl > /dev/null; done'" remote.user remote.host in
    let _ = Sys.command cmd in
    printf "Screen off on %s\n" name

let screen_on name =
  match find name with
  | None ->
    printf "Error: Remote '%s' not found. Use 'j remote list' to see configured remotes.\n" name;
    exit 1
  | Some remote ->
    printf "Turning on screen on %s...\n" remote.host;
    flush stdout;
    let cmd = sprintf "ssh -t %s@%s 'for bl in /sys/class/backlight/*/brightness; do cat $(dirname $bl)/max_brightness | sudo tee $bl > /dev/null; done'" remote.user remote.host in
    let _ = Sys.command cmd in
    printf "Screen on on %s\n" name

let secret_refresh name =
  match find name with
  | None ->
    printf "Error: Remote '%s' not found. Use 'j remote list' to see configured remotes.\n" name;
    exit 1
  | Some target ->
    printf "Finding a live remote to source secrets from...\n";
    flush stdout;
    (match find_live_remote ~exclude:name () with
    | None ->
      printf "Error: No other live remotes found to source secrets from.\n";
      exit 1
    | Some source ->
      printf "Pushing secrets from %s to %s...\n" source.name target.name;
      let cmd = sprintf "ssh -A %s@%s 'nixos-secrets push %s@%s'"
        source.user source.host target.user target.host in
      let result = Sys.command cmd in
      if result <> 0 then (
        printf "Error: Secret push failed\n";
        exit 1
      );
      printf "Secrets refreshed on %s (sourced from %s)\n" target.name source.name)

let push_secret filename =
  let local_path = Filename.concat (nixos_configs_root ()) filename in
  if not (file_exists local_path) then (
    printf "Error: %s not found in %s\n" filename (nixos_configs_root ());
    exit 1
  );
  let remotes = read_remotes () in
  if List.length remotes = 0 then (
    printf "Error: No remotes configured.\n";
    exit 1
  );
  let failed = ref false in
  List.iter (fun r ->
    printf "Pushing %s to %s (%s@%s)...\n" filename r.name r.user r.host;
    flush stdout;
    let mkdir_cmd = sprintf "ssh -o ConnectTimeout=3 -o BatchMode=yes %s@%s 'mkdir -p /etc/nixos/secrets' 2>/dev/null"
      r.user r.host in
    if Sys.command mkdir_cmd <> 0 then (
      printf "  Warning: %s unreachable, skipping\n" r.name;
      failed := true
    ) else (
      let scp_cmd = sprintf "scp %s %s@%s:/etc/nixos/secrets/%s"
        local_path r.user r.host filename in
      if Sys.command scp_cmd <> 0 then (
        printf "  Error: Failed to push to %s\n" r.name;
        failed := true
      ) else
        printf "  OK\n"
    )
  ) remotes;
  if !failed then (
    printf "\nSome hosts failed. Re-run or use secret-refresh later.\n";
    exit 1
  ) else
    printf "\n%s pushed to all hosts.\n" filename

let handle_command args =
  match args with
  | ["add"; name; host] -> add name host "root"
  | ["add"; name; host; user] -> add name host user
  | ["list"] -> list ()
  | ["pull"; name] -> pull name
  | ["deploy"; name] -> deploy name
  | ["ssh"; name] -> ssh name
  | ["flash"] -> flash None None
  | ["flash"; "--disk"; disk] -> flash None (Some disk)
  | ["flash"; "--builder"; name] -> flash (Some name) None
  | ["flash"; "--builder"; name; "--disk"; disk] -> flash (Some name) (Some disk)
  | ["flash"; "--disk"; disk; "--builder"; name] -> flash (Some name) (Some disk)
  | ["pull-key"; name] -> pull_key name
  | ["discover"] -> discover ()
  | ["setup"; build] -> setup build build
  | ["setup"; build; "--name"; name] -> setup build name
  | ["screen-off"; name] -> screen_off name
  | ["screen-on"; name] -> screen_on name
  | ["secret-refresh"; name] -> secret_refresh name
  | ["push-secret"; filename] -> push_secret filename
  | _ ->
    print_endline "Error: Invalid remote command";
    print_endline "Usage: j remote <add|list|pull|deploy|ssh|flash|pull-key|discover|setup|screen-off|screen-on|secret-refresh|push-secret> [args]";
    exit 1
