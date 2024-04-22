//
//  AssetLoader.swift
//
//
//  Created by Raman Singh on 2024-04-20.
//

import Foundation

protocol AssetLoader {
    func loadAsset<T: Savable>(of type: T.Type, named name: String) throws -> T
    func loadAsset<T: Decodable>(from url: URL) throws -> T
}

struct DefaultAssetLoader: AssetLoader {
    
    let fileSystem: FileSystem
    let savableURLCreator: SavableURLCreator
    let decoder: JSONDecoder
    
    init(savableURLCreator: SavableURLCreator, decoder: JSONDecoder, fileSystem: FileSystem) {
        self.savableURLCreator = savableURLCreator
        self.decoder = decoder
        self.fileSystem = fileSystem
    }
    
    func loadAsset<T: Savable>(of type: T.Type, named name: String) throws -> T {
        let itemUrl = savableURLCreator.localURL(for: type, named: name)
        return try loadAsset(from: itemUrl)
    }
    
    func loadAsset<T: Decodable>(from url: URL) throws -> T {
        let data = try fileSystem.contents(of: url)
        return try decoder.decode(T.self, from: data)
    }
}



