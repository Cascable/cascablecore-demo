##  CascableCore Demo Projects

This Xcode project contains two demo projects: one in Objective-C, and one in Swift. Both projects implement exactly the same app.
In fact, they share their main storyboard file!

The Objective-C implements the demo app using "plain" CascableCore and UIKit/Foundation APIs.

The Swift app uses the add-on [CascableCoreSwift](https://github.com/cascable/cascablecore-swift) library and Apple's
[Combine](https://developer.apple.com/documentation/combine) framework to make a more modern approach to the same task.

If you'd prefer not to use Combine with your Swift project, take a look at the Objective-C project — the APIs used there translate 
directly over to Swift too.
