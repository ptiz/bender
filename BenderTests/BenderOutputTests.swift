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

extension Passports {
    convenience init(numbers: [Int], items: [Passport]) {
        self.init()
        self.items = items
        self.numbers = numbers
    }
}

extension Passport {
    convenience init(number: Int, issuedBy: String, valid: Bool) {
        self.init()
        self.issuedBy = issuedBy
        self.number = number
        self.valid = valid
    }
}

extension Person {
    convenience init(passport: Passport) {
        self.init()
        self.passport = passport
    }
}

class BenderOutTests: QuickSpec {
        
    override func spec() {
        
        describe("Basic struct dump") {
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
        
        describe("Array dump") {
            it("should perform array dump as field in struct") {
                
                let passportRule = ClassRule(Passport())
                    .expect("issuedBy", StringRule, { $0.issuedBy = $1 }) { $0.issuedBy }
                    .optional("number", IntRule, { $0.number = $1 }) { $0.number }
                    .expect("valid", BoolRule, { $0.valid = $1 }) { $0.valid }
                
                let passportArrayRule = ArrayRule(itemRule: passportRule)
                
                let passportsRule = ClassRule(Passports())
                    .expect("passports", passportArrayRule, { $0.items = $1 }) { $0.items }
                    .expect("numbers", ArrayRule(itemRule: IntRule), { $0.numbers = $1 }) { $0.numbers }
                
                
                let passports = Passports(numbers: [1, 2, 3, 14], items: [
                        Passport(number: 1, issuedBy: "One", valid: false),
                        Passport(number: 2, issuedBy: "Two", valid: true),
                        Passport(number: 13, issuedBy: "Nobody", valid: true)
                    ])
                
                let d = passportsRule.dump(passports)
                let newP = try! passportsRule.validate(d)
                
                expect(newP.numbers.count).to(equal(4))
                expect(newP.items.count).to(equal(3))
                
                expect(newP.items[2].number).to(equal(13))
                expect(newP.items[2].issuedBy).to(equal("Nobody"))
                expect(newP.items[2].valid).to(equal(true))
            }
        }
     
        describe("Enum dump") {
            it("should performs enum dump of any internal type") {
                
                let enumRule = EnumRule<IssuedBy>()
                    .option("FMS", .FMS)
                    .option("SMS", .SMS)
                    .option("OPG", .OPG)
                    .option(0, .Unknown)
                
                let intEnumRule = EnumRule<Active>()
                    .option(0, .Inactive)
                    .option(1, .Active)
                
                let testRule = StructRule(ref(Pass()))
                    .expect("issuedBy", enumRule, { $0.value.issuedBy = $1 }) { $0.issuedBy }
                    .expect("active", intEnumRule, { $0.value.active = $1 }) { $0.active }
                
                let testRules = ArrayRule(itemRule: testRule)
                
                let rules = [
                    Pass(issuedBy: .FMS, active: .Active),
                    Pass(issuedBy: .OPG, active: .Inactive),
                    Pass(issuedBy: .Unknown, active: .Inactive)
                ]
                
                let d = testRules.dump(rules)
                let newRules = try! testRules.validate(d)
                
                expect(newRules.count).to(equal(3))
                expect(newRules[2].issuedBy).to(equal(IssuedBy.Unknown))
                expect(newRules[2].active).to(equal(Active.Inactive))
            }
        }
    
    }

}
