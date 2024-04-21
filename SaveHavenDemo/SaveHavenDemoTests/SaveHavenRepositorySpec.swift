//
//  SaveHavenRepositorySpec.swift
//  SaveHavenDemoTests
//
//  Created by Raman Singh on 2024-04-20.
//

import Foundation
import Quick
import Nimble
@testable import SaveHaven

final class SaveHavenRepositorySpec: QuickSpec {
    override class func spec() {
        describe("A SaveHavenRepository") {
            var fileSystem: MockFileSystem!
            var sut: DefaultSaveHavenRepository!
            var savableURLCreator: SavableURLCreator!
            
            beforeEach {
                fileSystem = MockFileSystem()
                savableURLCreator = DefaultSavableURLCreator()
                
                sut = DefaultSaveHavenRepository(
                    savableURLCreator: savableURLCreator,
                    fileSystem: fileSystem,
                    encoder: JSONEncoder(),
                    decoder: JSONDecoder())
            }
            
            afterEach {
                savableURLCreator = nil
                fileSystem = nil
                sut = nil
            }
            
            context("When saving single asset") {
                it("should fail when creating directory fails") {
                    let item = DummyObject(id: "1", title: "1")
                    let url = savableURLCreator.localURL(for: item)
                    
                    fileSystem
                        .fileShouldExist(at: url.path(), false)
                        .throwsWhenCreatingDirectory()
                    
                    expect(try sut.save(item)).to(throwError(MockFileSystem.MockError.failedCreatingDirectory))
                }
                
                it("should fail when writing data fails") {
                    let item = DummyObject(id: "1", title: "1")
                    let url = savableURLCreator.localURL(for: item)
                    
                    fileSystem
                        .fileShouldExist(at: url.path(), false)
                        .throwsWhenCreatingDirectory(false)
                        .throwsWhenWriting()
                    
                    expect(try sut.save(item)).to(throwError(MockFileSystem.MockError.failedWriting))
                }
                
                it("should write asset") {
                    let item = DummyObject(id: "1", title: "1")
                    let url = savableURLCreator.localURL(for: item)
                    
                    fileSystem
                        .fileShouldExist(at: url.path(), false)
                        .throwsWhenCreatingDirectory(false)
                        .throwsWhenWriting(false)
                    
                    let saveUrl = try sut.save(item)
                    expect(saveUrl) == url
                }
            }
            
            context("When saving multiple items") {
                
                var objects: [DummyObject]!
                
                beforeEach {
                    objects = (1...5).map { DummyObject(id: "\($0)", title: "\($0)")}
                }
                
                afterEach {
                    objects = nil
                }
                
                context("when saving") {
                    it("should fail if saving 1 item fails") {
                        let urls = objects.map { savableURLCreator.localURL(for: $0) }
                        
                        fileSystem
                            .throwsWhenCreatingDirectory(false)
                            .throwsWhenWriting(false)
                            .throwsWhenWriting(to: urls[4])
                        
                        do {
                            let saveUrls: [URL] = try sut.save(objects)
                            fail("should not save")
                        } catch {
                            expect(error as? MockFileSystem.MockError) == MockFileSystem.MockError.failedWriting
                        }
                    }
                    
                    it("should succeed") {
                        let urls = objects.map { savableURLCreator.localURL(for: $0) }
                        
                        fileSystem
                            .throwsWhenCreatingDirectory(false)
                            .throwsWhenWriting(false)
                        
                        do {
                            let saveUrls: [URL] = try sut.save(objects)
                            expect(saveUrls) == urls
                        } catch {
                            fail("should not fail")
                        }
                    }
                }
                
                context("when saving with save result") {
                    it("should return correct save result with 1 item failing") {
                        let urls = objects.map { savableURLCreator.localURL(for: $0) }
                        
                        fileSystem
                            .throwsWhenCreatingDirectory(false)
                            .throwsWhenWriting(false)
                            .throwsWhenWriting(to: urls[4])
                        
                        let saveResult: SaveResult<DummyObject> = sut.save(objects)
                        
                        expect(saveResult.successes.map(\.url)) == Array(urls.prefix(4))
                        expect(saveResult.failures.map(\.url)) == Array(urls.suffix(1))
                    }
                }
            }
            
            context("When loading") {
                
            }
            

        }
    }
}

private struct DummyObject: Savable, Equatable {
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
    
    var willWriteData: (Data) -> Void = { _ in }
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
    func throwsWhenLoadingContentsOfDirectory(_ flag: Bool) -> MockFileSystem {
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
    func throwsWhenLoadingContentsOfURL(_ flag: Bool = true) -> MockFileSystem {
        shouldThrowWhenLoadingContentsOfUrl = flag
        return self
    }
    
    func write(_ data: Data, to url: URL) throws {
        willWriteData(data)
        if shouldThrowWhenWriting {
            throw MockError.failedWriting
        } else if throwingURLs.contains(url) {
            throw MockError.failedWriting
        }
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
