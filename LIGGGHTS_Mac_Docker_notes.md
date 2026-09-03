# LIGGGHTS Simulation Quick-Start Guide

A copy-pasteable cheat sheet to run your LIGGGHTS simulation on your Mac via Docker — **without reinstalling LIGGGHTS every time**.

---

### How this works

1. **LIGGGHTS stays installed** — you build a custom Docker *image* once. Closing the container does not wipe that install.
2. **Your files live on the Mac** — the `-v` flag mounts a host folder into the container. Edit on Mac, run inside Docker; results appear on Mac immediately. No `docker cp` needed for anything under the mount.

---

### Prerequisites (One-Time)
Ensure **Docker Desktop** is open and running.

---

### Step 1: Build the image (ONE TIME ONLY)

From your project folder on the Mac:

```bash
cd ~/Documents_Local/GitHub/LIGGGHTS_projects
docker build --platform linux/amd64 -t liggghts:local .
```

This installs LIGGGHTS into the image. Takes a few minutes the first time. You only need to rebuild if you change the `Dockerfile`.

---

### Step 2: Start a container (every session)

Mount any Mac folder you want to work in. Examples:

```bash
# Your git project folder
docker run -it --rm --platform linux/amd64 \
  -v ~/Documents_Local/GitHub/LIGGGHTS_projects:/simulation \
  liggghts:local

# Or any other folder on your Mac
docker run -it --rm --platform linux/amd64 \
  -v ~/LIGGGHTS_projects:/simulation \
  liggghts:local
```

- `--rm` removes the *container* when you exit (keeps things tidy). The *image* still has LIGGGHTS.
- `-v host_path:/simulation` = Mac folder ↔ `/simulation` inside Docker (same files).
- You can mount other paths too, e.g. `-v ~/Desktop/my_run:/simulation`.

*(Your terminal prompt changes — you are inside Linux.)*

---

### Step 3: Run the simulation

No install step. Just:

```bash
cd /simulation
liggghts -in in.chute
```

Output files (e.g. under `post/`) appear on your Mac in the mounted folder right away.

---

### Step 4: Exit

```bash
exit
```

Back to your Mac prompt. Next time: only Step 2 — no rebuild, no `apt-get install`.

---

## Optional: reuse one named container instead of `--rm`

If you prefer keeping a long-lived container (packages + history):

```bash
# Create once
docker run -it --name liggghts_work --platform linux/amd64 \
  -v ~/Documents_Local/GitHub/LIGGGHTS_projects:/simulation \
  liggghts:local

# Later sessions (after exit)
docker start -ai liggghts_work
```

---

## Convert dump files for ParaView (on Mac, outside Docker)

```bash
cd /path/to/your/post

python3 -c "
import os

with open('trajectory.dump', 'r') as f:
    lines = f.readlines()

current_time = 0
frame_data = []
columns_header = 'id,type,x,y,z,vx,vy,vz,radius\n'

i = 0
while i < len(lines):
    line = lines[i].strip()
    if 'ITEM: TIMESTEP' in line:
        if frame_data:
            with open(f'frame_{current_time}.csv', 'w') as out:
                out.write(columns_header + ''.join(frame_data))
            frame_data = []
        current_time = int(lines[i+1].strip())
        i += 2
        continue

    if 'ITEM:' in line:
        i += 1
        continue

    parts = line.split()
    if len(parts) == 9:
        try:
            int(parts[0])
            frame_data.append(','.join(parts) + '\n')
        except ValueError:
            pass
    i += 1

if frame_data:
    with open(f'frame_{current_time}.csv', 'w') as out:
        out.write(columns_header + ''.join(frame_data))

print('Success! Columns aligned and animation frames updated.')
"
```

---

## Tips

| Goal | Do this |
|------|---------|
| Work on Mac files | Always use `-v /path/on/mac:/simulation` |
| Never reinstall LIGGGHTS | Use image `liggghts:local` (built once) |
| Edit scripts | Use Cursor/Finder on Mac; container sees changes instantly |
| View results | Open `post/` on Mac (ParaView, etc.) |

---

## CFDEM (OpenFOAM + LIGGGHTS) for fluidized-bed

`liggghts:local` is **DEM-only**. For CFD–DEM cases such as `fluidized-bed/`, use **`cfdem:local`**.

### Build once

```bash
cd ~/Documents_Local/GitHub/LIGGGHTS_projects
docker pull --platform linux/amd64 edoyango/cfdem:3.8.1
docker build --platform linux/amd64 -f Dockerfile.cfdem -t cfdem:local .
```

### Run

```bash
docker run -it --rm --platform linux/amd64 \
  -v ~/Documents_Local/GitHub/LIGGGHTS_projects:/simulation \
  cfdem:local
```

Inside the container:

```bash
cd /simulation/fluidized-bed
./Allrun.sh
```

Includes OpenFOAM-5.x (`blockMesh`, …), LIGGGHTS (`liggghts` / `lmp_auto`), and CFDEM (`cfdemSolverPiso`).
