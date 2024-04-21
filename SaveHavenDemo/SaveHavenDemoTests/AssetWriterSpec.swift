//
//  AssetWriterSpec.swift
//  SaveHavenDemoTests
//
//  Created by Raman Singh on 2024-04-19.
//

import XCTest
import Quick
import Nimble
@testable import SaveHaven

final class AssetWriterSpec: QuickSpec {
    override class func spec() {
        describe("An AssetWriter") {
            var urlCreator: SavableURLCreator!
            var sut: DefaultAssetWriter!
            
            beforeEach {
                urlCreator = DefaultSavableURLCreator(directory: "test")
                sut = DefaultAssetWriter(savableURLCreator: urlCreator, encoder: JSONEncoder(), fileSystem: FileManager.default)
            }
            
            afterEach {
                try FileManager.default.removeItem(at: urlCreator.root)
                urlCreator = nil
                sut = nil
            }
            
            it("should save data if folder does not exist") {
                let item = DummyObject(id: "1", title: "Some title")
                let saveUrl = try sut.saveAsset(item)
                
                expect(FileManager.default.fileExists(atPath: saveUrl.path)) == true
            }
            
            it("should overwrite data if file already exists") {
                let existingItemURL = urlCreator.root.appending(path: "DummyObject/1.json")
                
                try FileManager.default.createDirectory(
                    at: urlCreator.root.appending(path: "DummyObject"),
                    withIntermediateDirectories: true)
                
                let data = try XCTUnwrap("Some data".data(using: .utf8))
                try data.write(to: existingItemURL)
                
                let savedData = try Data(contentsOf: existingItemURL)
                
                expect(FileManager.default.fileExists(atPath: existingItemURL.path)) == true
                
                let item = DummyObject(id: "1", title: "Some title")
                let newItemUrl = try sut.saveAsset(item)
                let newData = try Data(contentsOf: newItemUrl)
                
                expect(newData).toNot(equal(savedData))
            }
        }
    }
}

private struct DummyObject: Savable {
    let id: String
    let title: String
}
