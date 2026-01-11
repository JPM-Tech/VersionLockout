# VersionLockout

Easily stop users from keeping old versions of your app around for a while.

## Mobile is different

Remember the days when you got software on a disk and installed it to your computer manually? Mobile, unfortunately, is still a little like that. Once the code is out there… it's out there. You can't simply revert the branch and redeploy a pipeline. Apple needs to review and approve the changes, then you need to get the user to download it!

## How does this package help?

If the root view is wrapped by the `VersionLockoutView`, you don't have to think about version lockout. This will take care of it for you including giving you built in views for when the user should update their app.

## How does it work?

First things first, you'll need an endpoint, a JSON file in an S3 bucket, or even a JSON file on GitHub — that returns the lockout information for your app. The shape of that data will look like the following:

```json
{
    "recommendedVersion": "2022.08.25",
    "requiredVersion": "2022.08.25",
    "updateUrl" : "https://apps.apple.com/the-link-to-your-app",
    "eol": false,
    "message": "this message is optional and is only used for the end of life for the app"
}
```

Next, you will add the package to your app using Swift Package Manager (SPM).

### Add the package to your app

To add this package to your app, use [Swift Package Manager](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app). Be sure to add VersionLockout to your app target when you add the dependency.

### Add it to your view

Once the dependency has been added to your project, you can `import VersionLockout`.
Then wrap your outter most view with the VersionLockoutView and pass in the link to the settings file like in the following example:

```swift
import SwiftUI
import VersionLockout // ADD: this import

@main
struct ExampleApp: App {
    // ADD: the link to your version lockout data
    let linkToMyVersionData = URL(string: "https://github.com/link-to-my-version-data.json")!
    
    var body: some Scene {
        WindowGroup {
            // WRAP: your main view with VersionLockoutView and pass the link to fetch the data
            VersionLockoutView(linkToMyVersionData) {
                ContentView()
            }
        }
    }
}
```
