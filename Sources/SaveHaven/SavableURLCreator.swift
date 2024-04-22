//
//  SavableURLCreator.swift
//
//
//  Created by Raman Singh on 2024-04-19.
//

import Foundation

protocol SavableURLCreator {
    var root: URL { get }
    func folderName<T>(for item: T.Type) -> String
    func localURL<T: Savable>(for item: T) -> URL
    func localURL<T>(for type: T.Type, named name: String) -> URL
}

struct DefaultSavableURLCreator: SavableURLCreator {
    
    static private let documentsDirectoryURL: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }()
    
    let root: URL
    
    init(root: URL? = nil) {
        self.root = root ?? Self.documentsDirectoryURL
    }
    
    init(directory: String) {
        self.root = Self.documentsDirectoryURL.appending(path: directory)
    }
    
    func localURL<T: Savable>(for item: T) -> URL {
        localURL(for: T.self, named: String(describing: item.id))
    }
    
    func localURL<T>(for type: T.Type, named name: String) -> URL {
        root
            .appending(path: folderName(for: T.self))
            .appending(path: name)
            .appendingPathExtension("json")
    }
    
    func folderName<T>(for item: T.Type) -> String {
        String(describing: type(of: item))
    }
}
