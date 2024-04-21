//
//  SaveHavenRepository.swift
//
//
//  Created by Raman Singh on 2024-04-19.
//

import Foundation

public typealias Savable = Codable & Identifiable

public struct LoadResult<T> {
    public struct Failure {
        let url: URL
        let error: Error
    }
    
    public struct Item {
        let element: T
        let url: URL
    }

    let loaded: [T]
    let failed: [Failure]
}

public struct SaveResult<T> {
    public struct Failure {
        public let element: T
        public let url: URL
        public let error: Error
    }
    
    public struct Success {
        public let element: T
        public let url: URL
    }
    
    public let successes: [Success]
    public let failures: [Failure]
}

public protocol SaveHavenRepository {
    
    @discardableResult func save<T: Savable>(_ asset: T) throws -> URL
    @discardableResult func save<T: Savable>(_ assets: [T]) throws -> [URL]
    @discardableResult func save<T: Savable>(_ assets: [T]) -> SaveResult<T>
    
    func loadSavedAssetNames<T: Savable>(of type: T.Type) throws -> [String]
    func loadSavedAssetURLs<T: Savable>(of type: T.Type) throws -> [URL]
    
    func loadSavedAssets<T: Savable>(of type: T.Type) throws -> [T]
    func loadSavedAssetsAtomically<T: Savable>(of type: T.Type) throws -> [T]
    func loadSavedAssets<T: Savable>(of type: T.Type, atomic: Bool) throws -> [T]
    func loadSavedAsset<T: Savable>(of type: T.Type, named name: String) throws -> T
    func loadSavedAssets<T: Savable>(of type: T.Type) throws -> LoadResult<T>
}

public struct DefaultSaveHavenRepository: SaveHavenRepository {
    
    private static let decoder: JSONDecoder = {
       JSONDecoder()
    }()
    
    private static let prettyEncoder: JSONEncoder = {
        var encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }()
    
    public let root: URL
    
    private let savableURLCreator: SavableURLCreator
    private let assetWriter: AssetWriter
    private let assetLoader: AssetLoader
    private let fileSystem: FileSystem
    
    init(savableURLCreator: SavableURLCreator, fileSystem: FileSystem, encoder: JSONEncoder, decoder: JSONDecoder) {
        self.savableURLCreator = savableURLCreator
        self.fileSystem = fileSystem
        self.assetWriter = DefaultAssetWriter(savableURLCreator: savableURLCreator, encoder: encoder, fileSystem: fileSystem)
        self.assetLoader = DefaultAssetLoader(savableURLCreator: savableURLCreator, decoder: decoder, fileSystem: fileSystem)
        self.root = savableURLCreator.root
    }
    
    public init(root: URL, encoder: JSONEncoder? = nil, decoder: JSONDecoder? = nil) {
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
    @discardableResult
    func save<T: Savable>(_ asset: T) throws -> URL {
        try assetWriter.saveAsset(asset)
    }
}

// MARK: - Saving Multiple Assets

public extension DefaultSaveHavenRepository {
    @discardableResult
    func save<T: Savable>(_ assets: [T]) throws -> [URL] {
        var assetURLs: [URL] = []
        for asset in assets {
            let url = try assetWriter.saveAsset(asset)
            assetURLs.append(url)
        }
        
        return assetURLs
    }
    
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
    func loadSavedAssetNames<T: Savable>(of type: T.Type) throws -> [String] {
        let directory = savableURLCreator.root.appending(path: savableURLCreator.folderName(for: type))
        return try loadAssetNames(in: directory)
    }
    
    private func loadAssetNames(in directory: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path)
    }
}

// MARK: - Loading Saved Asset URLs

public extension DefaultSaveHavenRepository {
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
    
    func loadSavedAssetsAtomically<T: Savable>(of type: T.Type) throws -> [T] {
        try loadSavedAssets(of: type, atomic: true)
    }
    
    func loadSavedAssets<T: Savable>(of type: T.Type) throws -> [T] {
        try loadSavedAssets(of: type, atomic: false)
    }
    
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
    func loadSavedAsset<T: Savable>(of type: T.Type, named name: String) throws -> T {
        try assetLoader.loadAsset(of: type, named: name)
    }
}
