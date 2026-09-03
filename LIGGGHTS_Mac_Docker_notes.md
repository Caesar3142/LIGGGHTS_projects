# LIGGGHTS Simulation Quick-Start Guide

A copy-pasteable cheat sheet to run your LIGGGHTS simulation anytime you open a fresh terminal window on your Mac.

---

### 📋 Prerequisites (One-Time Setup)
Ensure **Docker Desktop** is open and running in the background of your Mac.

---

### Step 1: Open a Fresh Mac Terminal
Navigate directly to your simulation folder on your Mac:
```bash
cd ~/liggghts_test
```

### Step 2: Start the Docker Container
Launch the container while mounting your current folder (`pwd`) into the Linux environment:
```bash
docker run -it --platform linux/amd64 -v "$(pwd)":/simulation ubuntu:20.04

(example: docker run -it --platform linux/amd64 -v ~/liggghts_test:/simulation ubuntu:20.04)
```
*(Your terminal prompt will change, indicating you are now successfully inside the Linux container).*

### Step 3: Install LIGGGHTS (Inside the Container)
Since Docker containers reset their temporary system memory when closed, run this quick installation script:
```bash
apt-get update && apt-get install -y liggghts
```

### Step 4: Run the Simulation
Move into the shared folder where your `in.chute` script lives, and execute the run command:
```bash
cd /simulation
liggghts -in in.chute
```

### Step 5: Exit the Container
Once the log files stop scrolling and the simulation hits 100,000 steps, safely close the container by typing:
```bash
exit
```
*(You will be returned back to your regular Mac terminal prompt, and your new `.vtk` files will be sitting safely in `~/liggghts_test/post/`).*


## Copy the results out from docker container:
docker cp 7229e7ee30b1:/simulation/post /Users/caesarwiratama/Documents_Local/projects/LIGGGHTS-run/

## convert post files
cd /Users/caesarwiratama/Documents_Local/projects/LIGGGHTS-run/post
for f in *.dump; do mv "$f" "${f%.dump}.csv"; done

## Convert to make it paraview-readable
cd /Users/caesarwiratama/Documents_Local/projects/LIGGGHTS-run/post

python3 -c "
import os

with open('trajectory.dump', 'r') as f:
    lines = f.readlines()

current_time = 0
frame_data = []
columns_header = 'id,type,x,y,z,vx,vy,vz,radius\n' # Standard order

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
    
    # Safely skip the variable metadata header lines
    if 'ITEM:' in line:
        i += 1
        continue
        
    parts = line.split()
    # Ensure it only captures the rows containing the 9 numerical atom parameters
    if len(parts) == 9:
        try:
            # Test if the line starts with a valid integer ID
            int(parts[0])
            frame_data.append(','.join(parts) + '\n')
        except ValueError:
            pass
    i += 1

# Write out the final lingering frame boundary
if frame_data:
    with open(f'frame_{current_time}.csv', 'w') as out:
        out.write(columns_header + ''.join(frame_data))

print('Success! Columns aligned and animation frames updated.')
"
