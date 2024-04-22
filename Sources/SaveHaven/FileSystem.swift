//
//  FileSystem.swift
//
//
//  Created by Raman Singh on 2024-04-20.
//

import Foundation

protocol FileSystem {
    func fileExists(atPath path: String) -> Bool
    func createDirectory(at url: URL) throws
    func contentsOfDirectory(atPath path: String) throws -> [String]
    func contents(of url: URL) throws -> Data
    func write(_ data: Data, to url: URL) throws
}

extension FileManager: FileSystem {
    func createDirectory(at url: URL) throws {
        try createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }
    
    func contents(of url: URL) throws -> Data {
        try Data(contentsOf: url)
    }
    
    func write(_ data: Data, to url: URL) throws {
        try data.write(to: url)
    }
}
