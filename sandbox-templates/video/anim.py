#!/usr/bin/env python3
"""Terminal animations for the demo recording.

  anim.py intro          the title card, with a request travelling the path
  anim.py load [count]   creates sandboxes and draws live Agent Substrate stats

The numbers in `load` are real. Actor counts come from kagent's
SystemService/GetSubstrateSummary, read with grpcurl. Timings are the wall
clock of each `kagent sandbox create` call, measured here.
"""
import json
import shutil
import subprocess
import sys
import time
import uuid

M, C, G, Y, DIM, B, OFF = "\033[1;35m", "\033[36m", "\033[32m", "\033[33m", "\033[2m", "\033[1m", "\033[0m"
COLS, ROWS = shutil.get_terminal_size((120, 36))
out = sys.stdout.write


def center(text, visible=None):
    return " " * max(0, (COLS - (visible or len(text))) // 2) + text


def frame(lines):
    out("\033[H")
    for line in lines:
        out(line + "\033[K\n")
    out("\033[J")
    sys.stdout.flush()


def intro():
    boxes = [
        ("my laptop", "Pi · Claude Code", "the model thinks here"),
        ("kagent", "MCP on :8083", "the rules live here"),
        ("sandbox", "gVisor · no network", "the code runs here"),
    ]
    width, gap = 24, 11
    title = "Give your coding agent a sandbox"
    sub = "kagent sandbox templates on Agent Substrate"
    total = 3 * width + 2 * gap
    left = " " * max(0, (COLS - total) // 2)
    top_pad = max(1, (ROWS - 13) // 2)
    out("\033[?25l\033[2J")
    steps = 2 * gap
    try:
        for tick in range(steps * 2 + 14):
            pos = tick % (steps + 6)          # where the dot is along both arrows
            lit = 0 if pos < gap else (1 if pos < steps else 2)
            lines = [""] * top_pad
            shown = title[: min(len(title), tick * 2)]
            lines.append(center(f"{M}{shown}{OFF}", len(shown)))
            lines.append("")
            lines.append(center(f"{DIM}{sub}{OFF}", len(sub)) if tick > 16 else "")
            lines += ["", ""]
            rows = ["", "", "", "", ""]
            for i, (name, detail, _) in enumerate(boxes):
                color = G if i <= lit and tick > 4 else DIM
                rows[0] += f"{color}┌{'─' * (width - 2)}┐{OFF}"
                rows[1] += f"{color}│{OFF}{B}{name:^{width - 2}}{OFF}{color}│{OFF}"
                rows[2] += f"{color}│{OFF}{detail:^{width - 2}}{color}│{OFF}"
                rows[3] += f"{color}└{'─' * (width - 2)}┘{OFF}"
                rows[4] += f"{DIM}{boxes[i][2]:^{width}}{OFF}"
                if i < 2:
                    arrow = list("─" * (gap - 3) + "▶")
                    at = pos - i * gap
                    if 0 <= at < len(arrow):
                        arrow[at] = f"{Y}●{OFF}{DIM}"
                    rows[0] += " " * gap
                    rows[1] += f" {DIM}{''.join(arrow)}{OFF} "
                    rows[2] += " " * gap
                    rows[3] += " " * gap
                    rows[4] += " " * gap
            lines += [left + r for r in rows]
            frame(lines)
            time.sleep(0.11)
        time.sleep(1.5)
    finally:
        out("\033[?25h\033[2J\033[H")


def summary():
    raw = subprocess.run(
        ["grpcurl", "-plaintext", "-max-time", "8", "-d", '{"namespace":"kagent","atespace":"kagent"}',
         "localhost:8083", "kagent.api.v1.SystemService/GetSubstrateSummary"],
        capture_output=True, text=True).stdout
    data = json.loads(raw or "{}")
    counts = {c["state"].replace("ACTOR_STATE_", "").lower(): int(c["count"])
              for c in data.get("actorStatusCounts", [])}
    return counts, int(data.get("workerCount", 0) or 0)


def bar(value, scale, color, width=40):
    filled = min(width, round(width * value / max(1, scale)))
    return f"{color}{'█' * filled}{OFF}{DIM}{'░' * (width - filled)}{OFF}"


def spark(values):
    if not values:
        return ""
    ticks = "▁▂▃▄▅▆▇█"
    lo, hi = min(values), max(values)
    return "".join(ticks[int((v - lo) / max(1, hi - lo) * (len(ticks) - 1))] for v in values)


def load(count):
    ids, timings, log = [], [], []
    spin = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    state = {"tick": 0}

    def draw(status):
        counts, workers = summary()
        running, suspended = counts.get("running", 0), counts.get("suspended", 0)
        state["tick"] += 1
        lines = [
            "",
            f"  {M}AGENT SUBSTRATE{OFF}  {DIM}worker pool kagent-default · {workers} worker · live from GetSubstrateSummary{OFF}",
            f"  {DIM}{'─' * (COLS - 4)}{OFF}",
            "",
            f"  {B}running  {OFF}  {bar(running, count, G)}  {B}{running}{OFF}",
            f"  {B}suspended{OFF}  {bar(suspended, count, C)}  {B}{suspended}{OFF}   {DIM}idle agent sessions, holding no compute{OFF}",
            "",
            f"  {B}create call{OFF}  {Y}{spark(timings)}{OFF}  "
            + (f"last {timings[-1]} ms · fastest {min(timings)} ms · average {sum(timings) // len(timings)} ms" if timings else ""),
            "",
            f"  {C}{spin[state['tick'] % len(spin)]}{OFF} {status}",
            "",
        ]
        lines += [f"  {DIM}{entry}{OFF}" for entry in log[-10:]]
        frame(lines)

    out("\033[?25l\033[2J")
    try:
        draw("starting")
        time.sleep(1.5)
        for n in range(1, count + 1):
            draw(f"creating sandbox {n} of {count} from the python template")
            start = time.time()
            res = subprocess.run(
                ["kagent", "sandbox", "create", "python", "--request-id", f"load-{uuid.uuid4()}",
                 "--ttl", "5m", "-o", "json"], capture_output=True, text=True)
            ms = int((time.time() - start) * 1000)
            try:
                sid = json.loads(res.stdout)["id"]
            except (ValueError, KeyError):
                log.append(f"sandbox {n} failed: {(res.stderr or res.stdout).strip()[:90]}")
                continue
            ids.append(sid)
            timings.append(ms)
            log.append(f"+ {sid}  ready in {ms} ms")
            draw(f"sandbox {n} is ready")
            time.sleep(0.5)
        draw(f"{len(ids)} sandboxes running, each in its own gVisor sandbox")
        time.sleep(4)
        for n, sid in enumerate(ids, 1):
            draw(f"deleting sandbox {n} of {len(ids)}")
            subprocess.run(["kagent", "sandbox", "delete", sid], capture_output=True)
            log.append(f"- {sid}  deleted")
        draw("all sandboxes deleted, compute released")
        time.sleep(4)
    finally:
        for sid in ids:  # idempotent safety net if the run is interrupted
            subprocess.run(["kagent", "sandbox", "delete", sid], capture_output=True)
        out("\033[?25h\n")


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "intro"
    if mode == "intro":
        intro()
    else:
        load(int(sys.argv[2]) if len(sys.argv) > 2 else 6)
