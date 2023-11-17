# Run PPLib's pathfinding on a coprocessor

### Warning: I am unable to support this project at the same level as PPLib itself. Feel free to open issues for bug reports, but, I will not be able to provide general setup and usage support beyond what is in the README below:

## Usage
`./pplib_coprocessor.exe --server <SERVER ADDRESS>`

Even though the file ends with the .exe extension, the macOS and Linux versions are still executables for their respective platforms.

`<SERVER ADDRESS>` should be the IP address of the robot or simulator. For example, `10.30.15.2`, `10.TE.AM.2`, or `127.0.0.1` for localhost.

## PPLib Usage
You must change the pathfinder implementation to `RemoteADStar` for the coprocessor based pathfinding to be used. This should be done early in your robot initialization, before any pathfinding commands are created. The easiest way to do this is to just have it as your first call in `robotInit`.

### Java
```java
Pathfinding.setPathfinder(new RemoteADStar());
```

### C++
```c++
#include <pathplanner/lib/pathfinding/Pathfinding.h>
#include <pathplanner/lib/pathfinding/RemoteADStar.h>

using namespace pathplanner;

Pathfinding::setPathfinder(std::make_unique<RemoteADStar>());
```

### NOTE FOR ADVANTAGEKIT USERS:
You must use the AdvantageKit compatible version of `RemoteADStar` for it to work in log replay. This is provided as a file you can add to your project [here](https://gist.github.com/mjansen4857/f77f1c3c1a0875625120e941b09d5ea8).

Then, configure the pathfinder with this implementation.

```java
Pathfinding.setPathfinder(new RemoteADStarAK());
```

## Windows/Driver Station setup example
Create a .bat file in the same folder as the pplib_coprocessor executable, i.e. `pplib_coprocessor.bat` with the following contents:
```
pplib_coprocessor.exe --server <SERVER ADDRESS>
```

Replace `<SERVER ADDRESS>` with the robot IP as described above.

Run the .bat file when connected to the robot.

## Debian coprocessor setup example (Raspberry Pi, Orange Pi, etc.)

1. Put pplib_coprocessor.exe where you want it. i.e. `/home/pi/pplib_coprocessor.exe`
2. Make executable with `chmod +x pplib_coprocessor.exe`
3. Create a `/lib/systemd/system/pplib_coprocessor.service` file with the following content:
    ```
    [Unit]
    Description=Service that runs pplib_coprocessor

    [Service]
    # Run pplib_coprocessor at "nice" -10, which is higher priority than standard
    Nice=-10
    ExecStart=/home/pi/pplib_coprocessor.exe --server <ROBOT IP>
    ExecStop=/bin/systemctl kill pplib_coprocessor
    Type=simple
    Restart=on-failure
    RestartSec=1

    [Install]
    WantedBy=multi-user.target
    ```

    Change `<ROBOT IP>` to the IP of your robot.
    Change the path to the executable to match where you placed the file
4. `sudo systemctl daemon-reload`
5. `sudo systemctl enable pplib_coprocessor.service`
6. Reboot