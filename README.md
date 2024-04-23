# SaveHaven

SaveHaven is a Swift Package Manager (SPM) package designed to simplify the process of saving, loading, and deleting Codable objects in a structured manner. It provides a repository pattern for handling these operations, along with structured result types to capture successes and failures.

## Features

- **Save, Load, and Delete Assets**: SaveHaven allows you to easily save, load, and delete Codable objects to and from the file system.
- **Structured Result Types**: It provides structured result types (`LoadResult`, `SaveResult`, `DeleteResult`) to capture successes and failures during saving, loading, and deleting operations.
- **Customizable Configuration**: You can customize the repository with your own root directory, JSON encoder, and decoder.

## Installation

### Swift Package Manager (SPM)

You can use Swift Package Manager to integrate SaveHaven into your Xcode project. Follow these steps:

1. In Xcode, select "File" > "Swift Packages" > "Add Package Dependency..."
2. Enter the repository URL: `https://github.com/singhraman4282/SaveHaven`
3. Select the SaveHaven package from the list.
4. Follow the prompts to complete the installation.

## Usage

Here's how you can use SaveHaven in your Swift code:

```swift
import SaveHaven

// Initialize a SaveHaven repository
let repository = DefaultSaveHavenRepository()

struct MyAsset: Savable {
    let id: String
    let title: String
}

let myAsset = MyAsset(id: "some_id", title: "Some title")

// Save a single asset
do {
    let assetURL = try repository.save(myAsset)
} catch {
    print("Failed to save asset:", error)
}

// Save multiple assets
let results: SaveResult<MyAsset> = repository.save([asset1, asset2])

// Load saved assets
do {
    let loadedAssets: LoadResult<MyAsset> = try repository.loadSavedAssets(of: MyAsset.self)
    for item in loadedAssets.loaded {
        print("Loaded asset:", item)
    }
    for failure in loadedAssets.failed {
        print("Failed to load asset at \(failure.url): \(failure.error)")
    }
} catch {
    print("Failed to load assets:", error)
}

// Delete saved asset
do {
    let deletedURL = try repository.delete(myAsset)
    print("Deleted asset at:", deletedURL)
} catch {
    print("Failed to delete asset:", error)
}
