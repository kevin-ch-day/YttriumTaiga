#!/usr/bin/env python3
"""
preconfig_tools.py
Phase 0 - Tool preconfiguration for Kali (CCDC Red Team)

- No CLI args (by design)
- Logs + outputs written next to this script:
  ./logs/preconfig_tools.log
  ./output/preconfig_tools.summary.txt
- Idempotent: safe to run multiple times
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import List, Tuple


# =========================
# Tunables (edit here only)
# =========================
DRY_RUN = False  # True = print actions but don't change system
APT_ASSUME_YES = True
APT_NO_RECOMMENDS = True  # smaller installs (good for CCDC)

# If you prefer these under your repo instead of ~/
USE_PROJECT_DIRS = True

# If running from your Phase 0 folder, this will create:
#   <Phase0>/output/workspace/{notes,evidence,tmp}
PROJECT_DIR_NAMES = [
    "workspace/notes",
    "workspace/evidence",
    "workspace/tmp",
]

# Add aliases safely under a marker block
BASHRC_MARKER_BEGIN = "# >>> CCDC_REDTEAM_ALIASES BEGIN >>>"
BASHRC_MARKER_END = "# <<< CCDC_REDTEAM_ALIASES END <<<"

ALIASES = [
    "alias ll='ls -lah'",
    "alias ..='cd ..'",
    "alias ...='cd ../..'",
    "alias nmap_fast='nmap -T4 -Pn'",
    "alias nmap_deep='nmap -A -T4 -Pn'",
]

# “Tool name” (binary) -> apt packages to install
TOOLS = [
    ("nmap", ["nmap"]),
    ("curl", ["curl"]),
    ("jq", ["jq"]),
    ("git", ["git"]),
    ("tmux", ["tmux"]),
    ("wireshark", ["wireshark"]),
    ("sqlmap", ["sqlmap"]),
    ("gobuster", ["gobuster"]),
    ("hydra", ["hydra"]),
    ("bloodhound", ["bloodhound"]),
    ("neo4j", ["neo4j"]),  # for BloodHound
    ("impacket-smbclient", ["impacket-scripts", "python3-impacket"]),  # best-effort
    ("john", ["john"]),
    ("hashcat", ["hashcat"]),
    ("proxychains4", ["proxychains4"]),
    ("masscan", ["masscan"]),
    ("burpsuite", ["burpsuite"]),
    ("msfconsole", ["metasploit-framework"]),  # metasploit via apt on Kali
]


# =========================
# Global log file (set in main)
# =========================
LOG_FILE: Path = Path("/tmp/preconfig_tools.log")


# =========================
# Helpers
# =========================
def log(msg: str) -> None:
    print(msg)
    try:
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(msg + "\n")
    except Exception:
        # If logging fails, still print to console
        pass


def run(cmd: List[str] | str, *, check: bool = True) -> subprocess.CompletedProcess:
    """Run a command (safe wrapper) with captured output."""
    if DRY_RUN:
        log(f"[DRY-RUN] Would run: {cmd}")
        return subprocess.CompletedProcess(args=cmd, returncode=0, stdout=b"", stderr=b"")

    try:
        if isinstance(cmd, str):
            return subprocess.run(cmd, shell=True, check=check, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return subprocess.run(cmd, check=check, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except subprocess.CalledProcessError as e:
        # Log useful debugging without dumping huge output
        stdout = (e.stdout or b"")[-2000:].decode(errors="ignore")
        stderr = (e.stderr or b"")[-2000:].decode(errors="ignore")
        log("[!] Command failed")
        log(f"    cmd: {cmd}")
        log(f"    rc : {e.returncode}")
        if stdout.strip():
            log("    --- stdout (tail) ---")
            log(stdout)
        if stderr.strip():
            log("    --- stderr (tail) ---")
            log(stderr)
        raise


def require_sudo() -> None:
    """
    Ensure the script is running as root (via sudo).
    Prints an accurate re-run command and exits with code 1 if not root.
    """
    if not hasattr(os, "geteuid"):
        raise SystemExit("ERROR: This script must be run on Linux/macOS with sudo (os.geteuid unavailable).")

    if os.geteuid() == 0:
        return

    script_path = Path(sys.argv[0]).resolve()
    python_exe = sys.executable or "python3"

    msg = (
        "ERROR: This script must be run with sudo/root.\n"
        "Re-run exactly as:\n"
        f"  sudo {python_exe} {script_path}\n"
    )
    raise SystemExit(msg)


def which(binary: str) -> bool:
    return shutil.which(binary) is not None


def detect_kali() -> bool:
    try:
        data = Path("/etc/os-release").read_text(encoding="utf-8", errors="ignore").lower()
        return "kali" in data
    except Exception:
        return False


def ensure_dirs(paths: List[Path]) -> None:
    for p in paths:
        if not p.exists():
            log(f"[*] Creating directory: {p}")
            if not DRY_RUN:
                p.mkdir(parents=True, exist_ok=True)
        else:
            log(f"[*] Directory exists: {p}")


def apt_update_upgrade() -> None:
    log("[*] apt-get update")
    run(["apt-get", "update"], check=True)

    log("[*] apt-get full-upgrade")
    cmd = ["apt-get"]
    if APT_ASSUME_YES:
        cmd.append("-y")
    cmd.extend(["full-upgrade"])
    run(cmd, check=True)


def apt_install(packages: List[str]) -> None:
    pkgs = sorted(set(packages))
    if not pkgs:
        return

    cmd = ["apt-get", "install"]
    if APT_ASSUME_YES:
        cmd.append("-y")
    if APT_NO_RECOMMENDS:
        cmd.append("--no-install-recommends")
    cmd.extend(pkgs)

    log(f"[*] Installing via apt-get ({len(pkgs)} pkgs)")
    log(f"    pkgs: {' '.join(pkgs)}")
    run(cmd, check=True)


def install_missing_tools() -> Tuple[int, int, List[str]]:
    """
    Returns:
      (present_after_count, already_present_before_count, still_missing_binaries)
    """
    missing_pkgs: List[str] = []
    already_before = 0

    for binary, pkgs in TOOLS:
        if which(binary):
            log(f"[OK]   {binary} present")
            already_before += 1
        else:
            log(f"[MISS] {binary} missing -> will install: {pkgs}")
            missing_pkgs.extend(pkgs)

    if missing_pkgs:
        # Use noninteractive installs
        os.environ["DEBIAN_FRONTEND"] = "noninteractive"
        apt_install(missing_pkgs)

    # Re-check after install
    present_after = 0
    still_missing: List[str] = []
    for binary, _ in TOOLS:
        if which(binary):
            present_after += 1
        else:
            still_missing.append(binary)

    return present_after, already_before, still_missing


def update_bashrc_aliases() -> None:
    bashrc = Path.home() / ".bashrc"
    content = bashrc.read_text(encoding="utf-8", errors="ignore") if bashrc.exists() else ""

    block = "\n".join([BASHRC_MARKER_BEGIN, *ALIASES, BASHRC_MARKER_END]) + "\n"

    if BASHRC_MARKER_BEGIN in content and BASHRC_MARKER_END in content:
        pre = content.split(BASHRC_MARKER_BEGIN, 1)[0]
        post = content.split(BASHRC_MARKER_END, 1)[1]
        new_content = pre.rstrip() + "\n" + block + post.lstrip()
        action = "Updated alias block in ~/.bashrc"
    else:
        new_content = content.rstrip() + "\n\n" + block
        action = "Appended alias block to ~/.bashrc"

    log(f"[*] {action}")
    if not DRY_RUN:
        bashrc.write_text(new_content, encoding="utf-8")


def write_summary(lines: List[str], out_file: Path) -> None:
    text = "\n".join(lines) + "\n"
    if not DRY_RUN:
        out_file.write_text(text, encoding="utf-8")
    log(f"[*] Wrote summary: {out_file}")


def main() -> None:
    # Paths next to script
    script_dir = Path(__file__).resolve().parent
    log_dir = script_dir / "logs"
    out_dir = script_dir / "output"
    log_dir.mkdir(parents=True, exist_ok=True)
    out_dir.mkdir(parents=True, exist_ok=True)

    global LOG_FILE
    LOG_FILE = log_dir / "preconfig_tools.log"
    if not DRY_RUN:
        LOG_FILE.write_text("", encoding="utf-8")  # overwrite each run

    summary_file = out_dir / "preconfig_tools.summary.txt"
    if not DRY_RUN:
        summary_file.write_text("", encoding="utf-8")

    # Require sudo AFTER log is ready (so message is captured too)
    require_sudo()

    log("======== CCDC Red Team Tool Preconfiguration (Phase 0) ========")
    log(f"Start: {datetime.now().isoformat(sep=' ', timespec='seconds')}")
    log(f"Script Dir: {script_dir}")
    log(f"Dry Run: {DRY_RUN}")
    log("")

    if not detect_kali():
        raise SystemExit("ERROR: Not Kali (based on /etc/os-release). Refusing to run.")

    # Directories
    log("[*] Ensuring directories...")
    if USE_PROJECT_DIRS:
        dirs = [out_dir / name for name in PROJECT_DIR_NAMES]
    else:
        dirs = [Path.home() / n for n in ["wordlists", "tools", "payloads", "scripts", "reports", "logs"]]
    ensure_dirs(dirs)

    # Update + upgrade
    log("[*] Updating system packages...")
    os.environ["DEBIAN_FRONTEND"] = "noninteractive"
    apt_update_upgrade()

    # Install missing tools in one batch
    log("[*] Verifying/installing toolchain...")
    present_after, already_before, still_missing = install_missing_tools()

    # Aliases
    log("[*] Updating ~/.bashrc aliases (idempotent block)...")
    update_bashrc_aliases()

    # Summary
    result = "OK" if not still_missing else "WARN"
    summary_lines = [
        "CCDC Red Team Phase 0 - Tool Preconfig Summary",
        f"End: {datetime.now().isoformat(sep=' ', timespec='seconds')}",
        "",
        f"Tools present after run: {present_after} / {len(TOOLS)}",
        f"Tools already present before run: {already_before}",
        "",
        "Directories ensured:",
        *[f" - {d}" for d in dirs],
        "",
    ]

    if still_missing:
        summary_lines.extend([
            "WARN: Some tool binaries are still missing after install attempts:",
            *[f" - {b}" for b in still_missing],
            "",
            "Tip: Some tools may have different binary names on your image, or repos may be restricted.",
            "",
        ])

    summary_lines.extend([
        "NOTE: Aliases were written to ~/.bashrc. Open a new shell to use them.",
        f"RESULT: {result}",
    ])

    write_summary(summary_lines, summary_file)
    log("[*] Done.")


if __name__ == "__main__":
    main()
