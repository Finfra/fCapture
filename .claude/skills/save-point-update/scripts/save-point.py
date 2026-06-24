import argparse
import datetime
import sys
import os

def parse_arguments():
    parser = argparse.ArgumentParser(description="Save Point Update Tool")
    parser.add_argument("--hash", required=True, help="Commit hash")
    parser.add_argument("--msg", default="", help="Brief description (optional)")
    parser.add_argument("--file", default="Issue.md", help="Target issue file")
    return parser.parse_args()

def read_file(filepath):
    if not os.path.exists(filepath):
        print(f"Error: File not found: {filepath}")
        sys.exit(1)
    with open(filepath, 'r', encoding='utf-8') as f:
        return f.readlines()

def write_file(filepath, lines):
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(lines)

def update_save_point(args):
    lines = read_file(args.file)
    today = datetime.datetime.now().strftime("%Y-%m-%d")

    # Find "* Save Point:" line
    header_idx = -1
    for i, line in enumerate(lines):
        if line.strip().startswith("* Save Point:"):
            header_idx = i
            break

    if header_idx == -1:
        print(f"Error: '* Save Point:' section not found in {args.file}.")
        sys.exit(1)

    # Format: "  - {hash} ({YYYY-MM-DD}) - {msg}" or "  - {hash} ({YYYY-MM-DD})"
    if args.msg:
        new_line = f"  - {args.hash} ({today}) - {args.msg}\n"
    else:
        new_line = f"  - {args.hash} ({today})\n"

    lines.insert(header_idx + 1, new_line)
    write_file(args.file, lines)
    print(f"Save Point 추가: {new_line.strip()}")

if __name__ == "__main__":
    args = parse_arguments()
    update_save_point(args)
