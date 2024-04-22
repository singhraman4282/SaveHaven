//
//  SaveHavenRepositoryTests.swift
//
//
//  Created by Raman Singh on 2024-04-21.
//

import Foundation
import XCTest
@testable import SaveHaven

final class SaveHavenRepositoryTests: XCTestCase {
    
    private var fileSystem: MockFileSystem!
    private var sut: DefaultSaveHavenRepository!
    private var savableURLCreator: SavableURLCreator!
    private var objects: [DummyObject]!
    
    override func setUp() {
        fileSystem = MockFileSystem()
        savableURLCreator = DefaultSavableURLCreator()
        objects = (1...5).map { DummyObject(id: "\($0)", title: "\($0)")}
        
        sut = DefaultSaveHavenRepository(
            savableURLCreator: savableURLCreator,
            fileSystem: fileSystem,
            encoder: JSONEncoder(),
            decoder: JSONDecoder())
    }
    
    override func tearDown() {
        savableURLCreator = nil
        fileSystem = nil
        sut = nil
        objects = nil
    }
    
    // MARK: - Saving Single Asset
    
    func testSavingSingleAsset_whenCreatingDirectoryFails() {
        let item = DummyObject(id: "1", title: "1")
        let url = savableURLCreator.localURL(for: item)
        
        fileSystem
            .fileShouldExist(at: url.path(), false)
            .throwsWhenCreatingDirectory()
        
        XCTAssertThrowsError(try sut.save(item), "should fail when creating directory fails")
    }
    
    func testSavingSingleAsset_whenWritingDataFails() {
        let item = DummyObject(id: "1", title: "1")
        let url = savableURLCreator.localURL(for: item)
        
        fileSystem
            .fileShouldExist(at: url.path(), false)
            .throwsWhenCreatingDirectory(false)
            .throwsWhenWriting()
        
        XCTAssertThrowsError(try sut.save(item), "should fail when writing data fails")
    }
    
    func testSavingSingleAsset_happyPath() throws {
        let item = DummyObject(id: "1", title: "1")
        let url = savableURLCreator.localURL(for: item)
        
        fileSystem
            .fileShouldExist(at: url.path(), false)
            .throwsWhenCreatingDirectory(false)
            .throwsWhenWriting(false)
        
        let expectation = self.expectation(description: "Should write data")
        
        fileSystem.didWriteData = { _ in
            expectation.fulfill()
        }
        
        try sut.save(item)
        
        waitForExpectations(timeout: 1)
    }
    
    // MARK: - Saving Multiple Items
    
    func testSavingItemsAtomically_when1ItemFails() {
        let urls = objects.map { savableURLCreator.localURL(for: $0) }
        
        fileSystem
            .throwsWhenCreatingDirectory(false)
            .throwsWhenWriting(false)
            .throwsWhenWriting(to: urls[4])
        
        let expectation = self.expectation(description: "Should fail when saving one item fails")
        
        do {
            let urls: [URL] = try sut.save(objects)
        } catch {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
    
    func testSavingItemsAtomically_happyPath() throws {
        let urls = objects.map { savableURLCreator.localURL(for: $0) }
        
        fileSystem
            .throwsWhenCreatingDirectory(false)
            .throwsWhenWriting(false)
        
        let savedItemUrls: [URL] = try sut.save(objects)
        
        XCTAssertEqual(savedItemUrls, urls, "should save multiple items")
    }
    
    // MARK: Saving with SaveResult
    
    func testSavingItemsWithSaveResult_when1ItemFails() {
        let urls = objects.map { savableURLCreator.localURL(for: $0) }
        
        fileSystem
            .throwsWhenCreatingDirectory(false)
            .throwsWhenWriting(false)
            .throwsWhenWriting(to: urls[4])
        
        let saveResult: SaveResult<DummyObject> = sut.save(objects)
        
        XCTAssertEqual(
            Array(objects.prefix(4)),
            saveResult.successes.map(\.element),
            "Should return correct save result"
        )
        
        XCTAssertEqual(
            Array(objects.suffix(1)),
            saveResult.failures.map(\.element),
            "Should return correct save result"
        )
    }
    
    // MARK: - Loading single asset
    
    func testLoadingSingleAsset_whenfails() {
        objects.forEach {
            fileSystem.returns($0, for: savableURLCreator.localURL(for: $0) )
        }
        
        let urls = objects.map { savableURLCreator.localURL(for: $0) }
        
        let directoryUrl = savableURLCreator.root.appending(path: savableURLCreator.folderName(for: DummyObject.self))
        
        let empty: DummyObject? = nil
        fileSystem.returns(empty, for: urls[0])
        
        fileSystem.returnsContentsOfDirectory(objects.map { $0.id + ".json" }, atPath: directoryUrl.path())
        
        XCTAssertThrowsError(try sut.loadSavedAsset(of: DummyObject.self, named: "1"), "should throw error")
    }
    
    func testLoadingSingleAsset_happyPath() throws {
        objects.forEach {
            fileSystem.returns($0, for: savableURLCreator.localURL(for: $0) )
        }
        
        let urls = objects.map { savableURLCreator.localURL(for: $0) }
        
        let directoryUrl = savableURLCreator.root.appending(path: savableURLCreator.folderName(for: DummyObject.self))
        
        fileSystem.returnsContentsOfDirectory(objects.map { $0.id + ".json" }, atPath: directoryUrl.path())
        
        XCTAssertEqual(try sut.loadSavedAsset(of: DummyObject.self, named: "1"), objects[0])
    }
    
    // MARK: - Loading multiple assets
    
    func testLoadingSavedAssetsAtomically_whenLoading1AssetFails() {
        objects.forEach {
            fileSystem.returns($0, for: savableURLCreator.localURL(for: $0) )
        }
        
        let urls = objects.map { savableURLCreator.localURL(for: $0) }
        let empty: DummyObject? = nil
        fileSystem.returns(empty, for: urls[4])
        
        let directoryUrl = savableURLCreator.root.appending(path: savableURLCreator.folderName(for: DummyObject.self))
        
        fileSystem.returnsContentsOfDirectory(objects.map { $0.id + ".json" }, atPath: directoryUrl.path())
        
        do {
            let result: [DummyObject] = try sut.loadSavedAssetsAtomically(of: DummyObject.self)
            print(result)
            XCTFail("Should fail when loading 1 asset fails")
        } catch {}
    }
    
    func testLoadingSavedAssetsAtomically_happyPath() throws {
        objects.forEach {
            fileSystem.returns($0, for: savableURLCreator.localURL(for: $0) )
        }
        
        let urls = objects.map { savableURLCreator.localURL(for: $0) }
        
        let directoryUrl = savableURLCreator.root.appending(path: savableURLCreator.folderName(for: DummyObject.self))
        
        fileSystem.returnsContentsOfDirectory(objects.map { $0.id + ".json" }, atPath: directoryUrl.path())
        
        let result: [DummyObject] = try sut.loadSavedAssets(of: DummyObject.self)
        XCTAssertEqual(Set(result), Set(objects), "Should return saved assets array")
    }
    
    func testLoadingSavedAssets_whenLoading1AssetFails() throws {
        objects.forEach {
            fileSystem.returns($0, for: savableURLCreator.localURL(for: $0) )
        }
        
        let urls = objects.map { savableURLCreator.localURL(for: $0) }
        let empty: DummyObject? = nil
        fileSystem.returns(empty, for: urls[4])
        
        let directoryUrl = savableURLCreator.root.appending(path: savableURLCreator.folderName(for: DummyObject.self))
        
        fileSystem.returnsContentsOfDirectory(objects.map { $0.id + ".json" }, atPath: directoryUrl.path())
        
        let result: [DummyObject] = try sut.loadSavedAssets(of: DummyObject.self)
        
        XCTAssertEqual(Set(result), Set(objects.prefix(4)), "Should not fail when loading some assets fails")
    }
    
    func testLoadingSavedAssets_happyPath() throws {
        objects.forEach {
            fileSystem.returns($0, for: savableURLCreator.localURL(for: $0) )
        }
        
        let urls = objects.map { savableURLCreator.localURL(for: $0) }
        
        let directoryUrl = savableURLCreator.root.appending(path: savableURLCreator.folderName(for: DummyObject.self))
        
        fileSystem.returnsContentsOfDirectory(objects.map { $0.id + ".json" }, atPath: directoryUrl.path())
        
        let result: [DummyObject] = try sut.loadSavedAssets(of: DummyObject.self)
        XCTAssertEqual(Set(result), Set(objects), "Should return saved assets array")
    }
    
    // MARK: Loading saved assets with result
    
    func testLoadingSavedAssetsWithResult_whenLoading1AssetFails() throws {
        objects.forEach {
            fileSystem.returns($0, for: savableURLCreator.localURL(for: $0) )
        }
        
        let urls = objects.map { savableURLCreator.localURL(for: $0) }
        let empty: DummyObject? = nil
        fileSystem.returns(empty, for: urls[4])
        
        let directoryUrl = savableURLCreator.root.appending(path: savableURLCreator.folderName(for: DummyObject.self))
        
        fileSystem.returnsContentsOfDirectory(objects.map { $0.id + ".json" }, atPath: directoryUrl.path())
        
        let result: LoadResult<DummyObject> = try sut.loadSavedAssets(of: DummyObject.self)
        
        XCTAssertEqual(Set(result.loaded), Set(objects.prefix(4)), "should return loaded")
        XCTAssertEqual(Set(result.failed.map(\.url)), Set([urls[4]]), "should return failed")
    }
    
    // MARK: - Loading Saved Asset Names
    
    func testLoadingSavedAssetNames() {
        fileSystem
            .throwsWhenLoadingContentsOfDirectory()

        XCTAssertThrowsError(try sut.loadSavedAssetNames(of: DummyObject.self), "Should throw error")
    }
    
    func testLoadingSavedAssetNames_happyPath() throws {
        let directoryUrl = savableURLCreator.root.appending(path: savableURLCreator.folderName(for: DummyObject.self))
        
        fileSystem
            .throwsWhenLoadingContentsOfDirectory(false)
            .returnsContentsOfDirectory(["1", "2"], atPath: directoryUrl.path())
        
        let assetNames = try sut.loadSavedAssetNames(of: DummyObject.self)
        
        XCTAssertEqual(["1", "2"], assetNames, "Should load saved asset names")
    }
    
    // MARK: - Loading Saved Asset URLs
    
    func testLoadingSavedAssetURLs() {
        fileSystem
            .throwsWhenLoadingContentsOfDirectory()
        
        XCTAssertThrowsError(try sut.loadSavedAssetURLs(of: DummyObject.self), "Should throw error")
    }
    
    func testLoadingSavedAssetURLs_happyPath() throws {
        let directoryUrl = savableURLCreator.root.appending(path: savableURLCreator.folderName(for: DummyObject.self))
        
        let fileNames = ["1.json", "2.json"]
        
        fileSystem
            .throwsWhenLoadingContentsOfDirectory(false)
            .returnsContentsOfDirectory(fileNames, atPath: directoryUrl.path())
        
        let assetUrls = try sut.loadSavedAssetURLs(of: DummyObject.self)
        let expected = fileNames.map { directoryUrl.appending(path: $0) }
        
        XCTAssertEqual(Set(assetUrls), Set(expected), "Should load asset URLs")
    }
    
}


private struct DummyObject: Savable, Equatable, Hashable {
    let id: String
    let title: String
}

final class MockFileSystem: FileSystem {
    
    enum MockError: Error {
        case noContent
        case failedLoadingContentOfURL
        case failedWriting
        case failedLoadingContentsOfDirectory
        case failedCreatingDirectory
    }
    
    var didWriteData: (Data) -> Void = { _ in }
    private var shouldThrowWhenWriting: Bool = false
    private var dataMappedToURL: [URL: Data] = [:]
    private var shouldThrowWhenLoadingContentsOfUrl: Bool = false
    private var filenamesMappedToPath: [String: [String]] = [:]
    private var shouldThrowWhenLoadingContentsOfDirectory: Bool = false
    private var shouldThrowWhenCreatingDirectory: Bool = false
    
    private var existingFiles: Set<String> = []
    private var throwingURLs: Set<URL> = []
    
    func fileExists(atPath path: String) -> Bool {
        existingFiles.contains(path)
    }
    
    @discardableResult
    func fileShouldExist(at path: String, _ flag: Bool = true) -> MockFileSystem {
        if flag {
            existingFiles.insert(path)
        } else {
            existingFiles.remove(path)
        }
        
        return self
    }
    
    func createDirectory(at url: URL) throws {
        if shouldThrowWhenCreatingDirectory {
            throw MockError.failedCreatingDirectory
        }
    }
    
    @discardableResult
    func throwsWhenCreatingDirectory(_ flag: Bool = true) -> MockFileSystem {
        shouldThrowWhenCreatingDirectory = flag
        return self
    }
    
    func contentsOfDirectory(atPath path: String) throws -> [String] {
        if shouldThrowWhenLoadingContentsOfDirectory {
            throw MockError.failedLoadingContentsOfDirectory
        }
        
        return filenamesMappedToPath[path] ?? []
    }
    
    @discardableResult
    func returnsContentsOfDirectory(_ names: [String], atPath path: String) -> MockFileSystem {
        filenamesMappedToPath[path] = names
        return self
    }

    @discardableResult
    func throwsWhenLoadingContentsOfDirectory(_ flag: Bool = true) -> MockFileSystem {
        shouldThrowWhenLoadingContentsOfDirectory = flag
        return self
    }
    
    func contents(of url: URL) throws -> Data {
        if shouldThrowWhenLoadingContentsOfUrl {
            throw MockError.failedLoadingContentOfURL
        }
        
        if let data = dataMappedToURL[url] {
            return data
        }
        
        throw MockError.noContent
    }
    
    @discardableResult
    func returns<T: Codable>(_ item: T?, for url: URL) -> MockFileSystem {
        if let item {
            dataMappedToURL[url] = try? JSONEncoder().encode(item)
        } else {
            dataMappedToURL[url] = nil
        }
        
        return self
    }
    
    @discardableResult
    func throwsWhenLoadingContentsOfURL(_ flag: Bool = true) -> MockFileSystem {
        shouldThrowWhenLoadingContentsOfUrl = flag
        return self
    }
    
    func write(_ data: Data, to url: URL) throws {
        if shouldThrowWhenWriting {
            throw MockError.failedWriting
        } else if throwingURLs.contains(url) {
            throw MockError.failedWriting
        }
        
        didWriteData(data)
    }
    
    @discardableResult
    func throwsWhenWriting(_ flag: Bool = true) -> MockFileSystem {
        shouldThrowWhenWriting = flag
        return self
    }
    
    @discardableResult
    func throwsWhenWriting(to url: URL) -> MockFileSystem {
        throwingURLs.insert(url)
        return self
    }
}
