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
    // ADD: VersionLockoutViewModel to your view
    @State var versionLockoutVM = VersionLockoutViewModel(URL(string: "https://github.com/link-to-my-version-data.json")!)
    
    var body: some Scene {
        WindowGroup {
            // WRAP: your main view with VersionLockoutView and pass the view model
            VersionLockoutView(viewModel: versionLockoutVM) {
                ContentView()
            }
        }
    }
}
```

### Uses for each screen

* Recommended update: Gives the user the ability to skip updating their app for a short time (uses the task modifier to check for updates and reminds them).
* Required update: Prevents the user from interacting with the app until the update has been completed.
* EOL Update: Currently, the End Of Life (EOL) option is only useful on the Android side (since the App Store allows you to remove apps from a users device and the Play Store does not). The message parameter is currently only used for this screen.

## Built-in Views

Recommended update (gives the user the ability to skip these updates for a short time):

![Recommended update screen](Docs/Images/Recommended-Update-Example.png)

Required update:

![Required update screen](Docs/Images/Required-Update-Example.png)

End of Life (Android Only):

![End of life screen](Docs/Images/EOL-Example.png)

### Displaying your own custom views

If you want to display your own view for any status, then the code would look like the following example:

```swift
import SwiftUI
import VersionLockout // ADD: this import

@main
struct ExampleApp: App {
    // ADD: VersionLockoutViewModel to your view
    @State var versionLockoutVM = VersionLockoutViewModel(URL(string: "https://github.com/link-to-my-version-data.json")!)

    var body: some Scene {
        WindowGroup {
            // Example of completely custom views for every status
            VersionLockoutView(viewModel: versionLockoutVM) {
                Text("I'm Loading")
            } updateRecommended: { _, _ in
                Text("Recomend")
            } updateRequred: { _ in
                Text("Required")
            } endOfLife: { _ in
                Text("I'm EOL")
            } upToDate: {
                // Your normal app view goes here
                Text("I'm up to date")
            }
        }
    }
}
```

### Closure parameters explained

Each custom view closure receives parameters that you can use to build your UI:

| Closure | Parameters | Description |
|---------|------------|-------------|
| `ifLoading` | None | Shown while fetching version data |
| `updateRecommended` | `updateUrl: URL`, `skip: () -> Void` | The `updateUrl` is the App Store link from your JSON. Call `skip()` to let the user dismiss the recommendation temporarily. |
| `updateRequred` | `updateUrl: URL` | The `updateUrl` is the App Store link from your JSON. No skip option since the update is mandatory. |
| `endOfLife` | `message: String?` | The optional message from your JSON to display to the user. |
| `upToDate` | None | Your main app content goes here |

### Using the closure parameters

Here's an example showing how to use these parameters in your custom views:

```swift
struct MyCustomUpdateRecommendedView: View {
    let updateUrl: URL
    let skip: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack {
            Text("A new version is available!")
            Button("Update Now") {
                openURL(updateUrl)
            }
            Button("Remind Me Later") {
                skip() // Dismisses this view and shows the main content
            }
        }
    }
}

struct MyCustomUpdateRequiredView: View {
    let updateUrl: URL
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack {
            Text("Please update to continue using the app")
            Button("Update Now") {
                openURL(updateUrl)
            }
            // No skip option - update is required
        }
    }
}

struct MyCustomEOLView: View {
    let message: String?

    var body: some View {
        VStack {
            Text("This app is no longer supported")
            if let message = message {
                Text(message)
            }
        }
    }
}
```

Then use your custom views in the `VersionLockoutView`:

```swift
VersionLockoutView(viewModel: versionLockoutVM) {
    // Loading - no parameters
    ProgressView("Checking for updates...")

} updateRecommended: { updateUrl, skip in
    MyCustomUpdateRecommendedView(updateUrl: updateUrl, skip: skip)

} updateRequred: { updateUrl in
    MyCustomUpdateRequiredView(updateUrl: updateUrl)

} endOfLife: { message in
    MyCustomEOLView(message: message)

} upToDate: {
    // No parameters - your main app content
    ContentView()
}
```
