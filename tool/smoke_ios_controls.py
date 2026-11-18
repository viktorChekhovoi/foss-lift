import json
from pathlib import Path
import sqlite3
import subprocess
import time

def sim(*args):
    return subprocess.check_output(["xcrun", "simctl", *args], text=True).strip()

devices = json.loads(sim("list", "devices", "available", "--json"))["devices"]
candidates = [(runtime, device) for runtime, group in devices.items() if "iOS-" in runtime
              for device in group if device["name"].startswith("iPhone") and "Pro" in device["name"]]
runtime, device = max(candidates, key=lambda entry: (entry[1]["state"] == "Booted", entry[0], entry[1]["name"]))
udid = device["udid"]
print(f"Testing on {device['name']} ({runtime})", flush=True)
if device["state"] != "Booted":
    sim("boot", udid)
sim("bootstatus", udid, "-b")
app = "com.fosslift.fosslift"
sim("install", udid, "build/ios/iphonesimulator/Runner.app")
sim("launch", udid, app)
docs = Path(sim("get_app_container", udid, app, "data")) / "Documents"
db = docs / "foss_lift.sqlite"
for _ in range(75):
    if db.exists():
        with sqlite3.connect(db) as conn:
            if conn.execute("SELECT 1 FROM sqlite_master WHERE name='live_sessions'").fetchone():
                break
    time.sleep(1)
else:
    raise RuntimeError("The installed iPhone app did not initialize its workout database")
sim("terminate", udid, app)
stamp = int(time.time() * 1000)
def exercise(name, paired):
    return dict(name=name, muscle="Back", mode="reps", weightType="none", restSeconds=75,
                supersetWithPrevious=paired, warmupCount=0, warmupBarKg=20, warmupRestSeconds=30,
                warmupLadder=[], warmups=[], sets=[dict(goal=8, timed=False, weight=0)])
session = dict(name="Island control check", startedAt=stamp, elapsed=0, unit="kg", plates=[],
               restLeft=0, exercises=[exercise("Press", False), exercise("Rows", True)])
with sqlite3.connect(db) as conn:
    conn.execute("INSERT OR REPLACE INTO live_sessions (id,payload,saved_at) VALUES (1,?,?)", (json.dumps(session), stamp//1000))
(docs / "control-smoke-session").write_text(str(stamp))
subprocess.run(["xcodebuild", "test", "-workspace", "ios/Runner.xcworkspace", "-scheme", "Runner",
                "-configuration", "Debug", "-destination", f"platform=iOS Simulator,id={udid}", "-parallel-testing-enabled", "NO",
                "-only-testing:RunnerTests/RunnerTests/testIslandLogsOnlyTheDisplayedSet", "CODE_SIGNING_ALLOWED=NO"], check=True)
