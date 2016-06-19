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
                
                let d = try! folderRule.dumpData(f)
                let newF = try! folderRule.validateData(d)
                
                expect(newF.name).to(equal("Folder 1"))
                expect(newF.size).to(equal(10))
                expect(newF.folders!.count).to(equal(2))
            }
            
            it("should allow only dump structs") {
                let folderRule = StructRule(ref(Folder(name: "", size: 0, folders: nil)))
                    .expect("name", StringRule) { $0.name }
                    .expect("size", Int64Rule) { $0.size }
                
                folderRule
                    .optional("folders", ArrayRule(itemRule: folderRule)) { $0.folders }
                
                let f = Folder(name: "Folder 1", size: 10, folders: [
                    Folder(name: "Folder 21", size: 11, folders: nil),
                    Folder(name: "Folder 22", size: 12, folders: nil)
                    ])
                
                let d = try! folderRule.dump(f) as! [String: AnyObject]
                let name = d["name"] as! String
                
                expect(name).to(equal("Folder 1"))
                
                let folders = d["folders"] as! [AnyObject]
                expect(folders.count).to(equal(2))
            }
            
            it("should be able to dump 'null' values") {
                let passportRule = ClassRule(Passport())
                    .expect("issuedBy", StringRule) { $0.issuedBy }
                    .expect("number", IntRule) { $0.number }
                    .expect("valid", BoolRule) { $0.valid }
                
                let pass = Passport(number: nil, issuedBy: "One", valid: false)
                
                let passJson = try! passportRule.dump(pass)
                
                expect(passJson["issuedBy"]).to(equal("One"))
                expect(passJson["number"]).to(beAKindOf(NSNull.self))
            
                let passString = try! StringifiedJSONRule(nestedRule: passportRule).dump(pass) as! String
                
                expect(passString).to(contain("\"number\":null"))
            }
            
            it("should be able to work with tuples") {
                let rule = StructRule(ref(("", 0)))
                    .expect("name", StringRule) { $0.0 }
                    .expect("number", IntRule) { $0.1 }
                
                let str = try! StringifiedJSONRule(nestedRule: rule).dump(("Test13", 13)) as! String
                expect(str).to(contain("\"number\":13"))
                expect(str).to(contain("\"name\":\"Test13\""))
            }
            
            it("should be able to dump value at JSON path") {
                let userStruct = User(id: "123456", name: nil)
                
                let m = StructRule(ref(User(id: nil, name: nil)))
                    .expect("message"/"payload"/"createdBy"/"user"/"id", StringRule, { $0.value.id = $1 }) { $0.id }
                    .optional("message"/"payload"/"createdBy"/"user"/"login", StringRule) { $0.value.name = $1 }
                
                let data = try? m.dump(userStruct) as! [String: AnyObject]
                let user = try? m.validate(data!)
                
                expect(user).toNot(beNil())
                expect(user?.id).to(equal(userStruct.id))
            }
            
        }
        
        describe("Array dump") {
            it("should perform array dump as field in struct") {
                
                let passportRule = ClassRule(Passport())
                    .expect("issuedBy", StringRule, { $0.issuedBy = $1 }) { $0.issuedBy }
                    .optional("number", IntRule) { $0.number = $1 }
                    .expect("number", IntRule) { $0.number }
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
                
                let d = try! passportsRule.dump(passports)
                let newP = try! passportsRule.validate(d)
                
                expect(newP.numbers.count).to(equal(4))
                expect(newP.items.count).to(equal(3))
                
                expect(newP.items[2].number).to(equal(13))
                expect(newP.items[2].issuedBy).to(equal("Nobody"))
                expect(newP.items[2].valid).to(equal(true))
            }
            
            it("should be able to dump array with polymorphic members") {
                let c = ClassRule(Circle())
                    .optional("type", StringRule) { _ in "circle" }
                    .expect("name", StringRule) { $0.name }
                    .expect("radius", FloatRule) { $0.radius }
                
                let s = ClassRule(Square())
                    .optional("type", StringRule) { _ in "square" }
                    .expect("name", StringRule) { $0.name }
                    .expect("size", FloatRule) { $0.size }
                
                let check = StructRule(ref(""))
                    .expect("type", StringRule) { $0.value = $1 }
                
                let r = PolyClassRule<Figure>()
                    .type({ try! check.validate($0) == "circle" }, rule: c)
                    .type({ try! check.validate($0) == "square" }, rule: s)
                
                let a = ArrayRule(itemRule: r)
                
                let figures = [makeSquare("the square", size: 13.0), makeCircle("the circle", radius: 14.0)]
                
                let json = try! a.dump(figures)

                expect(json).toNot(beNil())
                expect(json.count).to(equal(2))
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
                
                let d = try! testRules.dump(rules)
                let newRules = try! testRules.validate(d)
                
                expect(newRules.count).to(equal(3))
                expect(newRules[2].issuedBy).to(equal(IssuedBy.Unknown))
                expect(newRules[2].active).to(equal(Active.Inactive))
            }
        }
    
        describe("Stringified JSON dump") {
            it("should perform dump in accordance with the nested rule") {
                
                let passportRule = ClassRule(Passport())
                    .expect("issuedBy", StringRule, { $0.issuedBy = $1 }) { $0.issuedBy }
                    .optional("number", IntRule, { $0.number = $1 }) { $0.number }
                    .expect("valid", BoolRule, { $0.valid = $1 }) { $0.valid }
                
                let personRule = ClassRule(Person())
                    .expect("passport", StringifiedJSONRule(nestedRule: passportRule), { $0.passport = $1 }) { $0.passport }
                    .optional("passports", StringifiedJSONRule(nestedRule: ArrayRule(itemRule: passportRule)), { $0.nested = $1 }) { $0.nested }
                
                let person = Person(passport: Passport(number: 101, issuedBy: "FMSS", valid: true))
                
                let d = try! personRule.dump(person)
                let newP = try! personRule.validate(d)
             
                expect(newP.passport.number).to(equal(101))
                expect(newP.passport.issuedBy).to(equal("FMSS"))
            }
        }
    }

}

extension Passports {
    convenience init(numbers: [Int], items: [Passport]) {
        self.init()
        self.items = items
        self.numbers = numbers
    }
}

extension Passport {
    convenience init(number: Int?, issuedBy: String, valid: Bool) {
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

