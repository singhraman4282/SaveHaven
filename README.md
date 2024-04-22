# SaveHaven

SaveHaven is a Swift Package Manager (SPM) package designed to simplify the process of saving and loading Codable objects in a structured manner. It provides a repository pattern for saving and loading assets, with support for handling successes and failures during these operations.

## Features

- **Save and Load Assets**: SaveHaven allows you to easily save and load Codable objects to and from the file system.
- **Structured Result Types**: It provides structured result types (`LoadResult` and `SaveResult`) to capture successes and failures during saving and loading operations.
- **Customizable Configuration**: You can customize the repository with your own file system implementation, URL creator, JSON encoder, and decoder.

## Installation

### Swift Package Manager (SPM)

You can use Swift Package Manager to integrate SaveHaven into your Xcode project. Follow these steps:

1. In Xcode, select "File" > "Swift Packages" > "Add Package Dependency..."
2. Enter the repository URL: `https://github.com/your/repository`
3. Select the SaveHaven package from the list.
4. Follow the prompts to complete the installation.

## Usage

Here's how you can use SaveHaven in your Swift code:

```swift
import SaveHaven

// Initialize a SaveHaven repository
let repository = DefaultSaveHavenRepository(root: saveDirectoryURL)

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
