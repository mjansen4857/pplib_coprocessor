# Run PPLib's pathfinding on a coprocessor

### Warning: I am unable to support this project at the same level as PPLib itself. Feel free to open issues for bug reports, but, I will not be able to provide general setup and usage support beyond what is in the README below:

## Usage
`./pplib_coprocessor.exe --server <SERVER ADDRESS>`

Even though the file ends with the .exe extension, the macOS and Linux versions are still executables for their respective platforms.

`<SERVER ADDRESS>` should be the IP address of the robot or simulator. For example, `10.30.15.2`, `10.TE.AM.2`, or `127.0.0.1` for localhost.

## Windows/Driver Station setup example
Create a .bat file in the same folder as the pplib_coprocessor executable, i.e. `pplib_coprocessor.bat` with the following contents:
```
./pplib_coprocessor.exe --server <SERVER ADDRESS>
```

Replace `<SERVER ADDRESS>` with the robot IP as described above.

Run the .bat file when connected to the robot.

## Debian coprocessor setup example (Raspberry Pi, Orange Pi, etc.)
TODO