import argparse
import subprocess
import os
import sys
import re
from importlib.metadata import version, PackageNotFoundError

def list_available_commands(script_dir):
    commands = []

    for filename in os.listdir(script_dir):
        m = re.match(r"^cdc-(.+?)\.(\d+)\.desc$",filename)
        if m:
            command, order = m.groups()
            order = int(order)
            desc_path = os.path.join(script_dir, filename)
            try:
                with open(desc_path, "r", encoding="utf-8") as f:
                    description = f.read().strip()
            except Exception:
                description = "(error reading description)"
            commands.append((order, command, description))

    return sorted(commands, key=lambda x: (x[0], x[1]))

def main():

    try:
        ver = version("cdc")
    except PackageNotFoundError:
        ver = "(unknown)"

    exit_code = 0
    script_dir = os.path.join(os.path.dirname(__file__), "bin")

    parser = argparse.ArgumentParser(
        prog="cdc",
        usage="cdc <command> [args]",
        description="CDC Command Dispatcher"
    )
    parser.add_argument("command", nargs="?", help="Command to run (e.g., fetch, push)")
    parser.add_argument("args", nargs=argparse.REMAINDER, help="Arguments to pass to the command")
    parser.add_argument("-v", action="version", version=f"cdc {ver}")

    args = parser.parse_args()

    handle_autocomplete(args.command, script_dir)

    if args.command and args.command != "help":
        script_path = os.path.join(script_dir, f"cdc-{args.command}")
        if not os.path.isfile(script_path):
            print(f"Unknown command: {args.command}\n")
            exit_code = 1
    else:
        print(f"Compose desktop containers (cdc) version {ver}\n")
        print(f"Helpers to handle launcher and desktop integration for containers using docker/podman compose declaration files.")

        args.command = None

    if exit_code != 0 or not args.command:
        print("Available commands:\n")
        for order, command, desc in list_available_commands(script_dir):
            print(f"  {command:<25} {desc}")
        print("\nUse `cdc <command> -h` for command-specific help.\n")
        print(f"When you 'setup' an app, a directory with launcher links is created, and maintenance tasks under setup/.")
        print(f"Start the app by executing one of the launchers.\n")
        print(f"Depending on the compose yaml file, XDG desktop launchers may also have been created (which you then can launch from your desktop menus).\n")

        if "CDC_AUTOCOMPLETE" not in os.environ:
            shell = os.environ.get("SHELL","")
            if "bash" in shell:
                print("Hint: You can enable cdc tab completion in bash by running (or put in your .bashrc):\n    eval \"$(cdc bash_completion)\"\n")
            elif "fish" in shell:
                print("Hint: You can enable cdc tab completion in fish by running (or put in your ~/.config/fish/config.fish):\n    cdc fish_completion | source\n")
            elif "zsh" in shell:
                print("Hint: You can enable cdc tab completion by zsh running (or put in your ~/.zshrc):\n    eval \"$(cdc zsh_completion)\"\n")

        sys.exit(exit_code)

    script_name = f"cdc-{args.command}"
    script_path = os.path.join(script_dir, script_name)

    try:
        os.environ["CDC_CLI_NAME"] = "cdc "+str(args.command)
        subprocess.run(["bash", script_path] + args.args, check=True)
    except subprocess.CalledProcessError as e:
        sys.exit(e.returncode)

def handle_autocomplete(command, script_dir):

    if command == "__complete":
        for _, cmd, desc in list_available_commands(script_dir):
            print(f"{cmd}\t{desc}")
        sys.exit(0)

    if command == "bash_completion":
        print("""_cdc_completions() {{ local cur="${{COMP_WORDS[COMP_CWORD]}}"; if [[ $COMP_CWORD -eq 1 ]]; then COMPREPLY=( $(compgen -W "$({} __complete)" -- "$cur") ); fi }}; complete -F _cdc_completions cdc; export CDC_AUTOCOMPLETE=1""".strip().format(sys.argv[0]))
        sys.exit(0)

    if command == "fish_completion":
        print(r'''
        function __fish_cdc_complete
            set -l tokens (commandline -opc)
            set -l last_token (commandline -ct)
            set -l args $tokens
            for line in (cdc __complete $args)
                echo $line
            end
        end
        complete -c cdc -f -a '(__fish_cdc_complete)'
        export CDC_AUTOCOMPLETE=1'''.strip())
        sys.exit(0)

    if command == "zsh_completion":
        print(f'''
        _cdc_completions() {{
          local -a completions
          completions=("${{(@f)$( {sys.argv[0]} __complete | sed 's/\\t/:/')}}")
          _describe 'cdc command' completions
        }}
        compdef _cdc_completions cdc
        export CDC_AUTOCOMPLETE=1'''.strip())
        sys.exit(0)
