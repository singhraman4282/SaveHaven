//
//  SaveHavenRepository.swift
//
//
//  Created by Raman Singh on 2024-04-19.
//

import Foundation

/// Typealias representing an object that is both Codable and Identifiable
public typealias Savable = Codable & Identifiable

/// Structure representing the result of loading assets
public struct LoadResult<T> {
    
    /// Structure representing a failure during loading
    public struct Failure {
        /// URL of the failed asset
        let url: URL
        /// Error encountered during loading
        let error: Error
    }
    
    /// Structure representing a successfully loaded asset
    public struct Item {
        /// Loaded element
        let element: T
        /// URL of the loaded asset
        let url: URL
    }

    /// Array of successfully loaded elements
    let loaded: [T]
    /// Array of failed loading attempts
    let failed: [Failure]
}

/// Structure representing the result of saving assets
public struct SaveResult<T> {
    
    /// Structure representing a failure during saving
    public struct Failure {
        /// Element that failed to save
        public let element: T
        /// URL where the saving was attempted
        public let url: URL
        /// Error encountered during saving
        public let error: Error
    }
    
    /// Structure representing a successfully saved asset
    public struct Success {
        /// Successfully saved element
        public let element: T
        /// URL where the element was saved
        public let url: URL
    }
    
    /// Array of successfully saved assets
    public let successes: [Success]
    /// Array of failed saving attempts
    public let failures: [Failure]
}

public struct DeleteResult {
    
    /// Structure representing a failure during loading
    public struct Failure {
        /// URL of the failed asset
        let url: URL
        /// Error encountered during loading
        let error: Error
    }
    
    /// URLs of deleted items
    let deleted: [URL]
    /// Array of failed loading attempts
    let failed: [Failure]
}

/// Protocol defining methods for saving and loading assets
public protocol SaveHavenRepository {
    
    var root: URL { get }
    
    // MARK: Saving
    
    /// Saves a single asset and returns the URL where it was saved
    @discardableResult func save<T: Savable>(_ asset: T) throws -> URL
    
    /// Saves multiple assets and returns an array of URLs where they were saved
    @discardableResult func save<T: Savable>(_ assets: [T]) throws -> [URL]
    
    /// Saves multiple assets and returns a SaveResult containing successes and failures
    @discardableResult func save<T: Savable>(_ assets: [T]) -> SaveResult<T>
    
    // MARK: Loading
    
    /// Loads names of saved assets of a specific type
    func loadSavedAssetNames<T: Savable>(of type: T.Type) throws -> [String]
    
    /// Loads URLs of saved assets of a specific type
    func loadSavedAssetURLs<T: Savable>(of type: T.Type) throws -> [URL]
    
    /// Loads a single saved asset of a specific type by its name
    func loadSavedAsset<T: Savable>(of type: T.Type, named name: String) throws -> T
    
    /// Loads all saved assets of a specific type
    func loadSavedAssets<T: Savable>(of type: T.Type) throws -> [T]
    
    /// Loads all saved assets of a specific type atomically (all or none)
    func loadSavedAssetsAtomically<T: Savable>(of type: T.Type) throws -> [T]
    
    /// Loads all saved assets of a specific type, optionally atomically
    func loadSavedAssets<T: Savable>(of type: T.Type, atomic: Bool) throws -> [T]
    
    /// Loads all saved assets of a specific type and returns a LoadResult
    func loadSavedAssets<T: Savable>(of type: T.Type) throws -> LoadResult<T>
    
    // MARK: Deleting
    
    /// Deletes saved asset
    @discardableResult func delete<T: Savable>(_ asset: T) throws -> URL
    
    /// Deletes all items of given type
    @discardableResult func deleteAllItems<T: Savable>(ofType type: T.Type) throws -> [URL]
    
    /// Deletes all items in the given array
    @discardableResult func delete<T: Savable>(_ assets: [T]) throws -> [URL]
    
    /// Deletes all items with `DeleteResult`
    @discardableResult func deleteWithResult<T: Savable>(_ assets: [T]) -> DeleteResult
}

/// Default implementation of SaveHavenRepository
public struct DefaultSaveHavenRepository: SaveHavenRepository {
    
    private static let decoder: JSONDecoder = {
       JSONDecoder()
    }()
    
    private static let prettyEncoder: JSONEncoder = {
        var encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }()
    
    /// Root directory for saving assets
    public let root: URL
    
    private let savableURLCreator: SavableURLCreator
    private let assetWriter: AssetWriter
    private let assetLoader: AssetLoader
    private let fileSystem: FileSystem
    
    // MARK: Initialization
    
    init(savableURLCreator: SavableURLCreator, fileSystem: FileSystem, encoder: JSONEncoder, decoder: JSONDecoder) {
        self.savableURLCreator = savableURLCreator
        self.fileSystem = fileSystem
        self.assetWriter = DefaultAssetWriter(savableURLCreator: savableURLCreator, encoder: encoder, fileSystem: fileSystem)
        self.assetLoader = DefaultAssetLoader(savableURLCreator: savableURLCreator, decoder: decoder, fileSystem: fileSystem)
        self.root = savableURLCreator.root
    }
    
    public init(root: URL? = nil, encoder: JSONEncoder? = nil, decoder: JSONDecoder? = nil) {
        self.init(
            savableURLCreator: DefaultSavableURLCreator(root: root),
            fileSystem: FileManager.default,
            encoder: encoder ?? Self.prettyEncoder,
            decoder: decoder ?? Self.decoder)
    }
    
    public init(directory: String, encoder: JSONEncoder? = nil, decoder: JSONDecoder? = nil) {
        self.init(
            savableURLCreator: DefaultSavableURLCreator(directory: directory),
            fileSystem: FileManager.default,
            encoder: encoder ?? Self.prettyEncoder,
            decoder: decoder ?? Self.decoder)
    }
}

// MARK: - Saving Single Asset

public extension DefaultSaveHavenRepository {
    /// Saves a single asset and returns the URL where it was saved
    @discardableResult
    func save<T: Savable>(_ asset: T) throws -> URL {
        try assetWriter.saveAsset(asset)
    }
}

// MARK: - Saving Multiple Assets

public extension DefaultSaveHavenRepository {
    
    /// Saves multiple assets and returns an array of URLs where they were saved
    @discardableResult
    func save<T: Savable>(_ assets: [T]) throws -> [URL] {
        var assetURLs: [URL] = []
        for asset in assets {
            let url = try assetWriter.saveAsset(asset)
            assetURLs.append(url)
        }
        
        return assetURLs
    }
    
    /// Saves multiple assets and returns a SaveResult containing successes and failures
    @discardableResult
    func save<T: Savable>(_ assets: [T]) -> SaveResult<T> {
        var failures: [SaveResult<T>.Failure] = []
        var successes: [SaveResult<T>.Success] = []
        
        for asset in assets {
            do {
                let url = try assetWriter.saveAsset(asset)
                successes.append(SaveResult.Success(element: asset, url: url))
            } catch {
                let url = savableURLCreator.localURL(for: asset)
                failures.append(SaveResult.Failure(element: asset, url: url, error: error))
            }
        }
        
        return SaveResult(successes: successes, failures: failures)
    }
}

// MARK: - Loading Saved Asset Names

public extension DefaultSaveHavenRepository {
    /// Loads names of saved assets of a specific type
    func loadSavedAssetNames<T: Savable>(of type: T.Type) throws -> [String] {
        let directory = savableURLCreator.root.appending(path: savableURLCreator.folderName(for: type))
        return try loadAssetNames(in: directory)
    }
    
    private func loadAssetNames(in directory: URL) throws -> [String] {
        try fileSystem.contentsOfDirectory(atPath: directory.path)
    }
}

// MARK: - Loading Saved Asset URLs

public extension DefaultSaveHavenRepository {
    /// Loads URLs of saved assets of a specific type
    func loadSavedAssetURLs<T: Savable>(of type: T.Type) throws -> [URL] {
        let directory = savableURLCreator.root.appending(path: savableURLCreator.folderName(for: type))
        return try loadSavedAssetURLs(in: directory)
    }
    
    private func loadSavedAssetURLs(in directory: URL) throws -> [URL] {
        try loadAssetNames(in: directory).map { directory.appending(path: $0) }
    }
}

// MARK: - Loading Saved Assets

public extension DefaultSaveHavenRepository {
    
    /// Loads all saved assets of a specific type atomically (all or none)
    func loadSavedAssetsAtomically<T: Savable>(of type: T.Type) throws -> [T] {
        try loadSavedAssets(of: type, atomic: true)
    }
    
    /// Loads all saved assets of a specific type
    func loadSavedAssets<T: Savable>(of type: T.Type) throws -> [T] {
        try loadSavedAssets(of: type, atomic: false)
    }
    
    /// Loads all saved assets of a specific type, optionally atomically/
    func loadSavedAssets<T: Savable>(of type: T.Type, atomic: Bool) throws -> [T] {
        atomic ? try parseSavedAssetsAtomically(of: type) : try parseSavedAssets(of: type)
    }
    
    private func parseSavedAssetsAtomically<T: Savable>(of type: T.Type) throws -> [T] {
        let urls = try getURLs(for: type)
        return try parseItemsAtomically(of: type, from: urls)
    }
    
    private func parseSavedAssets<T: Savable>(of type: T.Type) throws -> [T] {
        let urls = try getURLs(for: type)
        return parseItems(of: type, from: urls)
    }
    
    private func getURLs<T: Savable>(for type: T.Type) throws -> [URL] {
        let directory = savableURLCreator.root.appending(path: savableURLCreator.folderName(for: type))
        return try loadSavedAssetURLs(in: directory)
    }
    
    private func parseItemsAtomically<T: Decodable>(of type: T.Type, from urls: [URL]) throws -> [T] {
        var result: [T] = []
        for url in urls {
            result.append(try assetLoader.loadAsset(from: url))
        }
        
        return result
    }
    
    private func parseItems<T: Decodable>(of type: T.Type, from urls: [URL]) -> [T] {
        urls.compactMap { try? assetLoader.loadAsset(from: $0) }
    }
}

// MARK: - Loading Saved Assets with LoadResult

public extension DefaultSaveHavenRepository {
    
    /// Loads all saved assets of a specific type and returns a LoadResult
    func loadSavedAssets<T: Savable>(of type: T.Type) throws -> LoadResult<T> {
        let directory = savableURLCreator.root.appending(path: savableURLCreator.folderName(for: type))
        let urls = try loadSavedAssetURLs(in: directory)
        
        var loaded: [T] = []
        var failed: [LoadResult<T>.Failure] = []
        
        for url in urls {
            do {
                let item: T = try assetLoader.loadAsset(from: url)
                loaded.append(item)
            } catch {
                failed.append(.init(url: url, error: error))
            }
        }
        
        return LoadResult(loaded: loaded, failed: failed)
    }
}

// MARK: - Loading Saved Asset

public extension DefaultSaveHavenRepository {
    /// Loads a single saved asset of a specific type by its name
    func loadSavedAsset<T: Savable>(of type: T.Type, named name: String) throws -> T {
        try assetLoader.loadAsset(of: type, named: name)
    }
}

// MARK: - Delete Single Saved Asset

public extension DefaultSaveHavenRepository {
    /// Deletes saved asset
    func delete<T: Savable>(_ asset: T) throws -> URL {
        let url = savableURLCreator.localURL(for: asset)
        try assetWriter.delete(at: url)
        return url
    }
}

// MARK: - Delete Multiple Saved Assets

public extension DefaultSaveHavenRepository {
    /// Deletes all items of given type
    @discardableResult func deleteAllItems<T: Savable>(ofType type: T.Type) throws -> [URL] {
        let directoryURL = savableURLCreator.directoryURL(for: type)
        let itemURLs = try loadSavedAssetURLs(in: directoryURL)
        try assetWriter.delete(at: directoryURL)
        return itemURLs
    }
    
    /// Deletes all items in the given array
    @discardableResult func delete<T: Savable>(_ assets: [T]) throws -> [URL] {
        var urls: [URL] = []
        for asset in assets {
            let itemUrl = savableURLCreator.localURL(for: asset)
            try assetWriter.delete(at: itemUrl)
            urls.append(itemUrl)
        }
        
        return urls
    }
    
    /// Deletes all items with `DeleteResult`
    @discardableResult func deleteWithResult<T: Savable>(_ assets: [T]) -> DeleteResult {
        var failed: [DeleteResult.Failure] = []
        var deleted: [URL] = []
        
        for asset in assets {
            let itemURL = savableURLCreator.localURL(for: asset)
            do {
                try assetWriter.delete(at: itemURL)
                deleted.append(itemURL)
            } catch {
                failed.append(DeleteResult.Failure(url: itemURL, error: error))
            }
        }
        
        return DeleteResult(deleted: deleted, failed: failed)
    }
}
