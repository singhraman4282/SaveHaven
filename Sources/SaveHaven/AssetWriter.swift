//
//  AssetWriter.swift
//
//
//  Created by Raman Singh on 2024-04-19.
//

import Foundation

protocol AssetWriter {
    @discardableResult func saveAsset<T: Savable>(_ asset: T) throws -> URL
    @discardableResult func saveAsset<T: Encodable>(_ asset: T, at url: URL) throws -> URL
    func delete(at url: URL) throws
}

struct DefaultAssetWriter: AssetWriter {
    
    let savableURLCreator: SavableURLCreator
    let fileSystem: FileSystem
    let encoder: JSONEncoder
    
    init(savableURLCreator: SavableURLCreator, encoder: JSONEncoder, fileSystem: FileSystem) {
        self.savableURLCreator = savableURLCreator
        self.encoder = encoder
        self.fileSystem = fileSystem
    }
    
    @discardableResult
    func saveAsset<T: Savable>(_ asset: T) throws -> URL {
        try saveAsset(asset, at: savableURLCreator.localURL(for: asset))
    }
    
    @discardableResult
    func saveAsset<T: Encodable>(_ asset: T, at url: URL) throws -> URL {
        let directoryUrl = url.deletingLastPathComponent()
        
        if fileSystem.fileExists(atPath: directoryUrl.path()).isFalse {
            try fileSystem.createDirectory(at: directoryUrl)
        }
        
        let data = try encoder.encode(asset)
        try fileSystem.write(data, to: url)
        return url
    }
    
    func delete(at url: URL) throws {
        if fileSystem.fileExists(atPath: url.path()) {
            try fileSystem.removeItem(at: url)
        }
    }
}

extension Bool {
    var isFalse: Bool {
        !self
    }
}
