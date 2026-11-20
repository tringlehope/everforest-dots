#!/usr/bin/env python3
import sys, os, json, subprocess, shutil, glob, configparser

AUTOSTART_FILE = os.path.expanduser("~/.config/hypr/autostart.lua")

def find_desktop_files():
    dirs = [
        os.path.expanduser("~/.local/share/applications"),
        "/usr/local/share/applications",
        "/usr/share/applications",
        os.path.expanduser("~/.local/share/flatpak/exports/share/applications"),
        "/var/lib/flatpak/exports/share/applications",
    ]
    seen = {}
    for d in dirs:
        if not os.path.isdir(d):
            continue
        for f in glob.glob(os.path.join(d, "*.desktop")):
            aid = os.path.basename(f)
            if aid not in seen:
                seen[aid] = f
    return seen

def parse_desktop(path):
    cp = configparser.ConfigParser(interpolation=None)
    try:
        cp.read(path, encoding="utf-8")
    except Exception:
        return None
    if "Desktop Entry" not in cp:
        return None
    de = cp["Desktop Entry"]
    if de.get("Type", "") != "Application":
        return None
    name = de.get("Name[ru]") or de.get("Name") or os.path.basename(path)
    icon = de.get("Icon", "application-x-executable")
    exe = de.get("Exec", "").split("%")[0].strip()
    nodisp = de.get("NoDisplay", "false").lower() == "true" or de.get("Hidden", "false").lower() == "true"
    return {
        "id": os.path.basename(path),
        "path": path,
        "name": name,
        "icon": icon,
        "exec": exe,
        "noDisplay": nodisp,
    }

def detect_source(desktop_path, exe_cmd):
    if "flatpak" in desktop_path:
        app_id = os.path.basename(desktop_path).replace(".desktop", "")
        return {"source": "Flatpak", "pkg": app_id}
    target = desktop_path
    if not os.path.exists(target) and exe_cmd:
        target = shutil.which(exe_cmd.split()[0]) or ""
    if target:
        try:
            out = subprocess.check_output(["pacman", "-Qoq", target], stderr=subprocess.DEVNULL).decode().strip()
            if out:
                pkg = out.splitlines()[0]
                is_aur = subprocess.run(["pacman", "-Qm", pkg], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
                return {"source": "AUR" if is_aur else "Pacman", "pkg": pkg}
        except Exception:
            pass
    return {"source": "Система / Локально", "pkg": ""}

def read_autostart():
    if not os.path.exists(AUTOSTART_FILE):
        return []
    cmds = []
    with open(AUTOSTART_FILE, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith('hl.exec_cmd("') and line.endswith('")'):
                cmds.append(line[13:-2])
    return cmds

def write_autostart(cmds):
    lines = ["hl.on(\"hyprland.start\", function ()"]
    for c in cmds:
        esc = c.replace("\\", "\\\\").replace('"', '\\"')
        lines.append(f'    hl.exec_cmd("{esc}")')
    lines.append("end)\n")
    with open(AUTOSTART_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

def cmd_apps(show_sys):
    files = find_desktop_files()
    enabled_cmds = set(read_autostart())
    res = []
    for aid, path in files.items():
        info = parse_desktop(path)
        if not info:
            continue
        if not show_sys and info["noDisplay"]:
            continue
        info["autostart"] = info["exec"] in enabled_cmds
        res.append(info)
    res.sort(key=lambda x: x["name"].lower())
    print(json.dumps(res, ensure_ascii=False))

def cmd_autostart_list(show_sys):
    files = find_desktop_files()
    enabled_cmds = set(read_autostart())
    res = []
    for aid, path in files.items():
        info = parse_desktop(path)
        if not info or not info["exec"]:
            continue
        if not show_sys and info["noDisplay"] and info["exec"] not in enabled_cmds:
            continue
        info["autostart"] = info["exec"] in enabled_cmds
        res.append(info)
    res.sort(key=lambda x: (not x["autostart"], x["name"].lower()))
    print(json.dumps(res, ensure_ascii=False))

def cmd_toggle_autostart(exe_cmd):
    cmds = read_autostart()
    if exe_cmd in cmds:
        cmds = [c for c in cmds if c != exe_cmd]
    else:
        cmds.append(exe_cmd)
    write_autostart(cmds)
    print("ok")

def parse_ss_output(out, force_repo=None):
    res = []
    cur = None
    for line in out.splitlines():
        if not line.startswith(" ") and "/" in line:
            if cur:
                res.append(cur)
            parts = line.strip().split()
            repo_pkg = parts[0]
            ver = parts[1] if len(parts) > 1 else ""
            inst = "[installed]" in line or "[установлено]" in line
            repo, pkg = repo_pkg.split("/", 1)
            cur = {"pkg": pkg, "repo": force_repo or repo, "ver": ver, "desc": "", "installed": inst}
        elif cur and line.strip():
            cur["desc"] = (cur["desc"] + " " + line.strip()).strip()
    if cur:
        res.append(cur)
    return res

def cmd_search(src, query):
    res = []
    if not query.strip():
        print("[]")
        return
    if src == "pacman":
        try:
            out = subprocess.check_output(["pacman", "-Ss", query], stderr=subprocess.DEVNULL).decode()
            res = parse_ss_output(out)
        except Exception:
            pass
    elif src == "aur":
        try:
            out = subprocess.check_output(["yay", "-Ssa", "--topdown", query], stderr=subprocess.DEVNULL).decode()
            res = parse_ss_output(out, force_repo="AUR")
        except Exception:
            pass
    elif src == "flatpak":
        if shutil.which("flatpak"):
            try:
                out = subprocess.check_output(["flatpak", "search", "--columns=application,name,description", query], stderr=subprocess.DEVNULL).decode()
                for line in out.splitlines():
                    cols = line.split("\t")
                    if len(cols) >= 2:
                        res.append({"pkg": cols[0].strip(), "repo": "Flatpak", "ver": cols[1].strip(), "desc": cols[2].strip() if len(cols) > 2 else "", "installed": False})
            except Exception:
                pass
    print(json.dumps(res[:40], ensure_ascii=False))

if __name__ == "__main__":
    action = sys.argv[1]
    if action == "apps":
        cmd_apps(sys.argv[2] == "1")
    elif action == "autostart":
        cmd_autostart_list(sys.argv[2] == "1")
    elif action == "toggle_autostart":
        cmd_toggle_autostart(sys.argv[2])
    elif action == "info":
        print(json.dumps(detect_source(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else ""), ensure_ascii=False))
    elif action == "search":
        cmd_search(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "")
