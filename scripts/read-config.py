"""Print named string fields from a JSON configuration, one value per line."""
import argparse
import json
from pathlib import Path


def read_values(path, keys):
    data = json.loads(Path(path).read_text())
    values = [data[key] for key in keys]
    if not all(isinstance(value, str) and "\n" not in value and "\r" not in value for value in values):
        raise ValueError("Configuration fields must be single-line strings")
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path)
    parser.add_argument("keys", nargs="+")
    args = parser.parse_args()
    print("\n".join(read_values(args.path, args.keys)))


if __name__ == "__main__":
    main()
