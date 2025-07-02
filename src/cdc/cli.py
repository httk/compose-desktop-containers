import argparse
import subprocess
import os
import sys

def list_available_commands(script_dir):
    scripts = []
    for filename in os.listdir(script_dir):
        if filename.startswith("cdc-"):
            command_name = filename[4:]  # Strip "cdc-" prefix and ".sh" suffix
            scripts.append(command_name)
    return sorted(scripts)

def main():
    script_dir = os.path.join(os.path.dirname(__file__), "bin")

    parser = argparse.ArgumentParser(
        prog="cdc",
        usage="cdc <command> [args]",
        description="CDC Command Dispatcher"
    )
    parser.add_argument("command", nargs="?", help="Command to run (e.g., fetch, push)")
    parser.add_argument("args", nargs=argparse.REMAINDER, help="Arguments to pass to the command")

    args = parser.parse_args()

    if not args.command or args.command == "help":
        # No command provided: show help and list available commands
        print("Available commands:\n")
        for cmd in list_available_commands(script_dir):
            print(f"  {cmd}")
        print("\nUse `cdc <command> -h` for command-specific help.")
        sys.exit(0)

    # Determine script path
    script_name = f"cdc-{args.command}.sh"
    script_path = os.path.join(script_dir, script_name)

    if not os.path.isfile(script_path):
        print(f"Unknown command: {args.command}\n")
        print("Available commands:")
        for cmd in list_available_commands(script_dir):
            print(f"  {cmd}")
        sys.exit(1)

    # Run the command, forwarding args
    try:
        subprocess.run(["bash", script_path] + args.args, check=True)
    except subprocess.CalledProcessError as e:
        sys.exit(e.returncode)

