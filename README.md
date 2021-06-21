# CascableCore Demo

CascableCore is a commercial SDK for communicating with Wi-Fi enabled cameras from Canon, Fujifilm, Nikon, Olympus, Panasonic, and Sony. It provides a powerful yet easy-to-use API that supports all cameras — write code once, and you support over 200 different camera models!

This project is a demonstration of some of the basic features of CascableCore, including:

- Camera discovery and connection.
- Handling on-camera pairing prompts and unexpected disconnects.
- Showing the camera's viewfinder image stream, taking shots and displaying shot previews.
- Working with camera properties.
- Iterating the camera's filesystem, loading image metadata and thumbnails.

![CascableCore Demo App Screenshots](Documentation%20Images/Screenshots.jpg?raw=true)

For a more thorough example of what CascableCore can do, see our apps at [http://cascable.se](http://cascable.se) — they're built with the same CascableCore available here.

For a more detailed overview of the CascableCore APIs, see the documentation in the [CascableCore Distribution](https://github.com/cascable/cascablecore-distribution) and [CascableCoreSwift](https://github.com/cascable/cascablecore-swift) repositories.

### Getting Started

- First, clone this repo to your local machine.

- Next, open the project in Xcode 12.5 or later. If Xcode doesn't update the CascableCore packages automatically, choose File -> Swift Packages -> Resolve Package Versions.

- Build and run the project.

### Getting a Trial License

If you're interested in licensing CascableCore, head over to our [developer site](http://developer.cascable.se) and sign up for an account. From there you can fill out a request for an evaluation license — if we think CascableCore is a good fit for you, we'll send you an evaluation license.

Once you have your evaluation license, replace the `CascableCoreLicense.h` and `CascableCoreLicense.m` files with it and the project will compile.


### Additional Resources

- Our [Getting Started With CascableCore](https://github.com/Cascable/cascablecore-demo/blob/master/Getting%20Started%20With%20CascableCore.md) document contains discussion about the CascableCore APIs and concepts in the order in which you're likely to encounter them. These APIs and concepts are equally important for both Objective-C and Swift developers.

- API reference documentation for CascableCore can be found [here](https://cascable.github.io).

- If you're using CascableCore with Swift, we recommend that you use [CascableCoreSwift](https://github.com/Cascable/cascablecore-swift), which adds a number of Swift-only APIs to CascableCore that make working with it easier.


### License 

This sample project is licensed under the MIT open source license, which means you can use the code in your own projects as long you provide attribution back to Cascable AB. 

This license does _not_ extend to the CascableCore framework itself, which will be covered under a separate license.

