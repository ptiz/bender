//
//  BenderOutputTests.swift
//  Bender
//
//  Created by Evgenii Kamyshanov on 24.01.16.
//  Copyright © 2016 Evgenii Kamyshanov.
//
//  The MIT License (MIT)
//
//  Permission is hereby granted, free of charge, to any person obtaining
//  a copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included
//  in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import XCTest
import Quick
import Nimble

@testable import Bender

class BenderOutTests: QuickSpec {
    
    struct Folder {
        var name: String
        var size: Int64
        var folders: [Folder]?
    }
    
    override func spec() {
        
        describe("Basic struct output") {
            it("should perform nested struct output to dict") {
                
                let folderRule = StructRule(ref(Folder(name: "", size: 0, folders: nil)))
                    .expect("name", StringRule, { $0.value.name = $1 }) { $0.name }
                    .expect("size", Int64Rule, { $0.value.size = $1 }) { $0.size }
        
                folderRule
                    .optional("folders", ArrayRule(itemRule: folderRule), { $0.value.folders = $1 }) { $0.folders }
                
                let f = Folder(name: "Folder 1", size: 10, folders: [
                        Folder(name: "Folder 21", size: 11, folders: nil),
                        Folder(name: "Folder 22", size: 12, folders: nil)
                    ])
                
                let d = folderRule.dump(f)
                let newF = try! folderRule.validate(d)
                
                expect(newF.name).to(equal("Folder 1"))
                expect(newF.size).to(equal(10))
                expect(newF.folders!.count).to(equal(2))
            }
        }
    }

}
