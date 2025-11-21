import argparse
import fileinput
import sys
from os import system
from os.path import abspath, dirname
from pathlib import Path

import tomli

BASE_DIR = Path(__file__).resolve().parent.parent


def get_config() -> dict:
    with open(BASE_DIR / "config/project.toml", "rb") as fp:
        return tomli.load(fp)


env = get_config()
server_env = env["server"]

parser = argparse.ArgumentParser()


def _get_sshpass_prefix(p):
    return f"sshpass -p {p} " if p else ""


def _get_server_info(live, root=False):
    user_key = "User" if not root else "Root_User"
    pass_key = "Pass" if not root else "Root_Pass"

    ip = server_env["IP"]

    u = server_env.get(user_key)
    p = server_env.get(pass_key)

    project_dir = server_env["PROJECT_DIR"]

    dev_env = server_env.get("dev")

    if not live and dev_env:
        ip = dev_env["IP"]

        u = dev_env.get(user_key)
        p = dev_env.get(pass_key)

        project_dir = dev_env["PROJECT_DIR"]

    return ip, u, p, project_dir


def build_client(*Args):
    client_dir = "code/client/frontend"

    system("cd ./dashboard && git pull origin client && npm run build")
    system(f"mkdir -p {client_dir} && rm -rf {client_dir}/*")
    system(f"cp -r ./dashboard/dist/assets ./{client_dir}")
    system(f"cp -r ./dashboard/dist/static/* ./{client_dir}")
    system(f"cp ./dashboard/dist/.vite/manifest.json ./{client_dir}/assets")

    extensions_to_process = (".js", ".css")

    js_replace = '"assets/'
    css_replace = "/assets/"

    for filepath in (BASE_DIR / f"{client_dir}/assets").iterdir():
        if filepath.is_file() and filepath.suffix in extensions_to_process:
            with fileinput.FileInput(filepath, inplace=True) as file:
                for line in file:
                    if filepath.suffix == ".js":
                        line = line.replace(js_replace, '"static/assets/')
                    elif filepath.suffix == ".css":
                        line = line.replace(css_replace, "/static/assets/")
                    print(line, end="")


def upload(*Args):
    parser.add_argument("-l", "--live", action="store_true")
    parser.add_argument("--no-build", action="store_true")

    args = parser.parse_args(Args)
    live = args.live
    no_build = args.no_build

    ip, u, p, project_dir = _get_server_info(live)

    sshpass_prefix = _get_sshpass_prefix(p)

    if not no_build:
        build_client(*Args)

    pycmd_prefix = "docker compose exec app python manage.py"

    commands = [
        f"cd {project_dir}",
        "git pull origin main",
        f"{pycmd_prefix} collectstatic --no-input --clear --no-post-process",
        f"{pycmd_prefix} migrate --no-input",
    ]

    cmd_prefix = f'{sshpass_prefix}ssh {u}@{ip} "'

    system(cmd_prefix + ";".join(commands) + '"')


def ssh(*Args):
    parser.add_argument("-l", "--live", action="store_true")
    parser.add_argument("-r", "--root", action="store_true")

    args = parser.parse_args(Args)

    live = args.live
    root = args.root

    ip, u, p, _ = _get_server_info(live, root)

    sshpass_prefix = _get_sshpass_prefix(p)

    command = f"{sshpass_prefix}ssh {u}@{ip}"

    print(command)
    system(command)


def push(*Args):
    system("git push origin $(git rev-parse --abbrev-ref HEAD)")


def pull(*Args):
    system("git pull origin $(git rev-parse --abbrev-ref HEAD)")


def tmp_upload(*Args):
    parser.add_argument("-l", "--live", action="store_true")
    parser.add_argument("-d", "--download", action="store_true")
    args = parser.parse_args(Args)
    live = args.live
    download = args.download

    ip, u, p, project_dir = _get_server_info(live)

    sshpass_prefix = _get_sshpass_prefix(p)

    if download:
        system(f"{sshpass_prefix}scp -r {u}@{ip}:{project_dir}/tmp/* tmp/")
    else:
        system(f"{sshpass_prefix}scp -r tmp/* {u}@{ip}:{project_dir}/tmp")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("not enough arguments")
    else:
        g = globals()

        _, command, *Args = sys.argv

        if command in g:
            g[command](*Args)
