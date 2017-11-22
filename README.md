# CascableCore Demo

CascableCore is a commercial SDK for communicating with Wi-Fi enabled cameras from Canon, Fujifilm, Nikon, Olympus, Panasonic, and Sony. It provides a powerful yet easy-to-use API that supports all cameras — write code once, and you support over 100 different camera models!

This project is a demonstration of some of the basic features of CascableCore, including:

- Camera discovery and connection.
- Handling on-camera pairing prompts and unexpected disconnects.
- Showing the camera's viewfinder image stream, taking shots and displaying shot previews.
- Working with camera properties.
- Iterating the camera's filesystem, loading image metadata and thumbnails.

![CascableCore Demo App Screenshots](Documentation%20Images/Screenshots.jpg?raw=true)

For a more thorough example of what CascableCore can do, see our apps at [http://cascable.se](http://cascable.se) — they're built with the same CascableCore available here.

For a more detailed overview of the CascableCore APIs, see the documentation in the [CascableCore Binaries](http://github.com/cascable/cascablecore-binaries/) repository.

### Getting Started

- First, close this repo to your local machine.
- Next, run `git submodule update --init --recursive` inside the project directory. This will check out the CascableCore binary. 

**Note:** You need `git-lfs` installed and configured on your development machine in order to check out CascableCore.

### Getting a Trial License

If you're interested in licensing CascableCore, head over to our [developer site](http://developer.cascable.se) and sign up for an account. From there you can fill out a request for an evaluation license — if we think CascableCore is a good fit for you, we'll send you an evaluation license.

Once you have your evaluation license, replace the `CascableCoreLicense.h` and `CascableCoreLicense.m` files with it and the project will compile.

### License 

This sample project is licensed under the MIT open source license, which means you can use the code in your own projects as long you provide attribution back to Cascable AB. 

This license does _not_ extend to the CascableCore framework itself, which will be covered under a separate license.

