//
//  SavableURLCreatorSpec.swift
//  SaveHavenDemoTests
//
//  Created by Raman Singh on 2024-04-19.
//

import Foundation
import Quick
import Nimble
@testable import SaveHaven

final class SavableURLCreatorSpec: QuickSpec {

    override class func spec() {
        var sut: DefaultSavableURLCreator!
        var root: URL!
        
        beforeEach {
            root = URL(string: "root")
            sut = DefaultSavableURLCreator(root: root)
        }
        
        afterEach {
            root = nil
            sut = nil
        }
        
        it("should return correct url for String") {
            let item = DummyObject(id: "R", title: "String")
            let url = sut.localURL(for: item)
            
            expect(url) == URL(string: "root/DummyObject<String>.Type/R.json")
        }
        
        it("should return correct url for Int") {
            let item = DummyObject(id: 1, title: "String")
            let url = sut.localURL(for: item)
            
            expect(url) == URL(string: "root/DummyObject<Int>.Type/1.json")
        }
        
        it("should return correct url for a protocol") {
            let item: any Savable = DummyObject(id: "R", title: "String")
            let url = sut.localURL(for: item)
            
            expect(url) == URL(string: "root/DummyObject<String>.Type/R.json")
            
            let folderName = sut.folderName(for: DummyObject<String>.self)
            expect(folderName) == "DummyObject<String>.Type"
        }
    }

}

private struct DummyObject<T: Hashable & Codable>: Savable {
    let id: T
    let title: String
}
