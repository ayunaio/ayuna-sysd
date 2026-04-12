#!/usr/bin/env python3

import shutil
import sys
from pathlib import Path

import yaml
from jinja2 import Environment, FileSystemLoader


def main():
    script_dir = Path(__file__).parent.resolve()

    env_targets = {
        "ayuna-sysd.env.j2": "ayuna-sysd.env",
        "nats.conf.j2": "nats.conf",
        "seaweed-s3.json.j2": "seaweed-s3.json",
        "valkey.conf.j2": "valkey.conf",
        "temporal.env.j2": "temporal.env",
    }

    for file in env_targets:
        tmpl_path = script_dir / "tmpl" / file
        if not tmpl_path.exists():
            print(f"Error: {tmpl_path} not found.")
            sys.exit(1)

    print("All template files found. Proceeding with generation.")

    ## Find the template data file either in script_dir or from commandline argument
    data_file = None

    if len(sys.argv) > 1:
        data_file = Path(sys.argv[1])
        if not data_file.exists():
            print(f"Error: Data file {data_file} not found.")
            sys.exit(1)
    else:
        data_file = script_dir / ".env_data.yaml"
        if not data_file.exists():
            print(f"Error: Data file {data_file} not found.")
            sys.exit(1)

    print(f"Using data file: {data_file}")

    with open(data_file, "r") as f:
        data = yaml.safe_load(f)

    # Setup jinja2
    j2env = Environment(
        loader=FileSystemLoader(script_dir / "tmpl"),
        autoescape=False,
        trim_blocks=True,
        lstrip_blocks=True,
    )

    env_dir = script_dir / "env"

    if env_dir.exists():
        shutil.rmtree(env_dir)

    env_dir.mkdir(exist_ok=True)

    for tmpl_name, output_name in env_targets.items():
        tmpl = j2env.get_template(tmpl_name)
        output_path = env_dir / output_name

        with open(output_path, "w") as f:
            f.write(tmpl.render(data))

        print(f"Generated {output_path}")


if __name__ == "__main__":
    main()
