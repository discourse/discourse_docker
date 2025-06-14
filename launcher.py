#!/usr/bin/env python3

import os
import sys
import subprocess
from typing import Dict, List
import yaml
from pathlib import Path
import argparse
import re

# The published base image.
BASE_IMAGE = "discourse/base:2.0.20250226-0128"

# The path to the locally-built Dockerfile
DKR_PATH = "dkr"

# The name of the container to build locally.
CONTAINER_NAME = "local_discourse"

# Used by `pups` to delineate files.
# https://github.com/discourse/pups/blob/078edb64074f86738d975db372fe7ddfef18b303/lib/pups/cli.rb#L54
MAGIC_SEPARATOR = "\n_FILE_SEPERATOR_\n"

def load_config(config_file: Path, template_paths: List[str]) -> List[str]:
    """Load the configuration file and associated templates."""
    # Read config file
    try:
        with open(config_file, "r") as f:
            config_data = f.read()
            config_yml = yaml.safe_load(config_data)
    except Exception as e:
        print(f"Error reading config file: {e}")
        sys.exit(1)

    templates = config_yml.get("templates", [])

    # Build combined input
    input_parts = ["hack: true"]

    # Add template files
    for template in templates:
        template_found = False
        
        # Try each template path until we find the template file
        for template_path in template_paths:
            full_template_path = os.path.join(template_path, template)
            
            if os.path.exists(full_template_path):
                try:
                    with open(full_template_path, "r") as f:
                        input_parts.append(f.read())
                    template_found = True
                    break
                except Exception as e:
                    print(f"Error reading template {full_template_path}: {e}")
                    continue
        
        if not template_found:
            print(f"Error: template '{template}' not found in any of the template paths: {template_paths}")
            sys.exit(1)

    # Add config file last (highest priority)
    input_parts.append(config_data)

    return input_parts

def substitute(params: Dict[str, str], s: str) -> str:
    """Substitute variables in string s with values from params dict.
    
    Variables are in the format $variable_name and will be replaced
    with params['variable_name'] if it exists.
    """
    
    # Find all variables that start with $ followed by word characters
    pattern = r'\$(\w+)'
    
    def replacer(match) -> str:
        var_name = match.group(1)
        # Return the value from params if it exists, otherwise keep original
        if var_name in params:
            return params.get(var_name)
        else:
            print(f"WARN: found parameter ${var_name} but could not substitute it!")
            return match.group(0)
    
    return re.sub(pattern, replacer, s)

def main():
    parser = argparse.ArgumentParser(description="Discourse Application Builder")
    parser.add_argument("action", help="The action to take", choices=("enter","build","rebuild","start","stop","restart","start-cmd"))
    parser.add_argument("config_name", help="The name of the configuration file")
    parser.add_argument(
        "--template-root",
        nargs='+',
        default=[".", "./discourse_docker"],
        help="Root directories for templates (can specify multiple paths)",
    )
    args = parser.parse_args()

    config_file = Path(args.config_name)
    config_name = config_file.stem

    input_parts = load_config(config_file, args.template_root)
    build_parts = []
    
    # Find an existing instance, if there is one.
    cid = subprocess.check_output(["docker", "ps", "-q", "-f", f"name={config_name}"]).strip().decode()

    if args.action in ("build", "rebuild", "start", "start-cmd"):
        if args.action in ("rebuild",):
            if cid:
              subprocess.check_call(["docker", "stop", cid])

        # Parse out docker parameters from the templates.
        # The first two will substitute the string `{config}` for the configuration file's name (i.e. "app.yaml" -> "app").
        #
        # - environment variables (`env:`) -> `-e <k>=<v>`
        # - labels (`labels:`) -> `-l <k>=<v>`
        # - ports (`expose:`) -> either `-p <port>` or `--expose <host>:<cont>` depending on input format
        # - user args (`docker_args:`)
        dkrargs = []

        # build_cmds = []
        params = {}
        base_image = BASE_IMAGE
        for part in input_parts:
            yml = yaml.safe_load(part)
            if "params" in yml:
                params.update(yml["params"])

            # EXTENSION: Collect a list of commands to run during container build.
            # These can be specified under a `build` block.
            if "build" in yml:
                # Do a little switcharoo and swap out `build` with `run`.
                byml = yml.copy()
                byml["run"] = yml["build"]
                del byml["build"]
                build_parts.append(yaml.dump(byml))

            if "env" in yml:
                for k, v in yml["env"].items():
                    v = str(v or '').replace("{config}", config_name)
                    dkrargs.extend(["-e", f"{k}={v}"])

            if "labels" in yml:
                for k, v in yml["labels"].items():
                    v = str(v or '').replace("{config}", config_name)
                    dkrargs.extend(["-l", f"{k}={v}"])

            if "expose" in yml:
                for port in yml["expose"]:
                    if "=" in port:
                        host, container = port.split("=", 1)
                        dkrargs.extend(["--expose", f"{host}:{container}"])
                    else:
                        dkrargs.extend(["-p", f"{port}"])

            if "volumes" in yml:
                for volume in yml.get("volumes", []):
                    volume = volume["volume"]
                    dkrargs.extend(["-v", f"{volume['host']}:{volume['guest']}"])

            # TODO: links

            if "docker_args" in yml:
                dkrargs.extend(yml["docker_args"])

            if "base_image" in yml:
                base_image = yml["base_image"]

        # Save startup commands to app/init (ran during startup)
        with open(os.path.join(DKR_PATH, "init"), "w", newline='\n') as f:
            f.write(MAGIC_SEPARATOR.join(input_parts))
        # Save build commands to app/build (ran during container build)
        with open(os.path.join(DKR_PATH, "build"), "w", newline='\n') as f:
            f.write(MAGIC_SEPARATOR.join(build_parts))

        if args.action in ("build", "rebuild"):
            subprocess.check_call(["docker", "build", "-t", f"{CONTAINER_NAME}/{config_name}", "--build-arg", f"BASE_IMAGE={base_image}", DKR_PATH])
        elif args.action == "start-cmd":
            print(" ".join(["docker", "run", "--rm", "-i", "--name", config_name, *dkrargs, f"{CONTAINER_NAME}/{config_name}"]))

        # Start the container back up if requested.
        if args.action in ("start", "rebuild"):
            subprocess.check_call(["docker", "run", "--rm", "-d", "-i", "--name", config_name, *dkrargs, f"{CONTAINER_NAME}/{config_name}"])
    elif args.action == "restart":
        if cid:
            subprocess.check_call(["docker", "restart", cid])
    elif args.action == "stop":
        if cid:
            subprocess.check_call(["docker", "stop", cid])
    elif args.action == "enter":
        subprocess.check_call(["docker", "exec", "-it", config_name, "/bin/bash", "--login"])
    elif args.action == "logs":
        subprocess.check_call(["docker", "logs", config_name])



if __name__ == "__main__":
    main()
