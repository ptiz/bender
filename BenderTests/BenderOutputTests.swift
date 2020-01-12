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
import Bender

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


class AtomicTypes {
    var i: Int?
    var i8: Int8?
    var i16: Int16?
    var i32: Int32?
    var i64: Int64?
    var ui: UInt?
    var ui8: UInt8?
    var ui16: UInt16?
    var ui32: UInt32?
    var ui64: UInt64?
    var flt: Float?
    var dbl: Double?
    var b: Bool?
    var s: String?
    
    init(i: Int = 0, i8: Int8 = 0, i16: Int16 = 0, i32: Int32 = 0, i64: Int64 = 0,
         ui: UInt = 0, ui8: UInt8 = 0, ui16: UInt16 = 0, ui32: UInt32 = 0, ui64: UInt64 = 0,
         flt: Float = 0, dbl: Double = 0,
         b: Bool = false,
         s: String = "") {
        self.i = i
        self.i8 = i8
        self.i16 = i16
        self.i32 = i32
        self.i64 = i64
        self.ui = ui
        self.ui8 = ui8
        self.ui16 = ui16
        self.ui32 = ui32
        self.ui64 = ui64
        self.flt = flt
        self.dbl = dbl
        self.b = b
        self.s = s
    }
}

class BenderOutTests: QuickSpec {
        
    override func spec() {
        
        describe("Atomic types dump") {
            it("Should support all the types listed in AtomicTypes struct") {
                var atomicRule = ClassRule(AtomicTypes())
                    .optional("i", IntRule) { $0.i }
                    .optional("i8", Int8Rule) { $0.i8 }
                    .optional("i16", Int16Rule) { $0.i16 }
                    .optional("i32", Int32Rule) { $0.i32 }
                    .optional("i64", Int64Rule) { $0.i64 }
                    .optional("ui", UIntRule) { $0.ui }
                    .optional("ui8", UInt8Rule) { $0.ui8 }
                
                //Compiler goes mad trying to parse all the expression, so we just split it into two
                atomicRule = atomicRule
                    .optional("ui16", UInt16Rule) { $0.ui16 }
                    .optional("ui32", UInt32Rule) { $0.ui32 }
                    .optional("ui64", UInt64Rule) { $0.ui64 }
                    .optional("flt", FloatRule) { $0.flt }
                    .optional("dbl", DoubleRule) { $0.dbl }
                    .optional("b", BoolRule) { $0.b }
                    .optional("s", StringRule) { $0.s }
                
                let a = AtomicTypes(i: -1, i8: -2, i16: -3, i32: -4, i64: -5, ui: 6, ui8: 7, ui16: 8, ui32: 9, ui64: 10, flt: 11.1, dbl: 12121212.1212121212, b: true, s: "the string")
                
                let passString = try! StringifiedJSONRule(nestedRule: atomicRule).dump(a) as! String
                
                expect(passString).to(contain("\"i\":-1"))
                expect(passString).to(contain("\"i8\":-2"))
                expect(passString).to(contain("\"i16\":-3"))
                expect(passString).to(contain("\"i32\":-4"))
                expect(passString).to(contain("\"i64\":-5"))
                expect(passString).to(contain("\"ui\":6"))
                expect(passString).to(contain("\"ui8\":7"))
                expect(passString).to(contain("\"ui16\":8"))
                expect(passString).to(contain("\"ui32\":9"))
                expect(passString).to(contain("\"ui64\":10"))
                expect(passString).to(contain("\"flt\":11.1"))
                expect(passString).to(contain("\"dbl\":12121212.12121212"))
                expect(passString).to(contain("\"b\":true"))
                expect(passString).to(contain("\"s\":\"the string\""))
                
            }
        }
        
        describe("Basic struct dump") {
            it("should perform nested struct output to dict") {
                
                let folderRule = StructRule(ref(Folder(name: "", size: 0, folders: nil)))
                    .expect("name", StringRule, { $0.value.name = $1 }) { $0.name }
                    .expect("size", Int64Rule, { $0.value.size = $1 }) { $0.size }
        
                let _ = folderRule
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
                
                let _ = folderRule
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
            
            it("should be able to dump 'null' values with expect") {
                let passportRule = ClassRule(Passport())
                    .expect("issuedBy", StringRule) { $0.issuedBy }
                    .expect("number", IntRule) { $0.number }
                    .expect("valid", BoolRule) { $0.valid }
                
                let pass = Passport(number: nil, issuedBy: "One", valid: false)
                
                let passJson = try! passportRule.dump(pass) as! [String: AnyObject]
                expect(passJson["issuedBy"] as? String).to(equal("One"))
                expect(passJson["number"] as? NSNull).toNot(beNil())
            
                let passString = try! StringifiedJSONRule(nestedRule: passportRule).dump(pass) as! String
                
                expect(passString).to(contain("\"number\":null"))
            }
            
            it("should be able to dump 'null' values with forceOptional") {
                let passportRule = ClassRule(Passport())
                    .expect("issuedBy", StringRule) { $0.issuedBy }
                    .forceOptional("number", IntRule) { $0.number }
                    .expect("valid", BoolRule) { $0.valid }
                
                let pass = Passport(number: nil, issuedBy: "One", valid: false)
                            
                do {
                    let passJson = try passportRule.dump(pass) as! [String: Any]
                    expect(passJson["issuedBy"] as? String).to(equal("One"))
                    expect(passJson["number"] as? NSNull).toNot(beNil())

                    let passString = try StringifiedJSONRule(nestedRule: passportRule).dump(pass) as! String
                    expect(passString).to(contain("\"number\":null"))
                } catch {
                    expect(error).to(beNil())
                }

            }
            
            it("should be able to work with tuples") {
                let rule = StructRule(ref(("", 0)))
                    .expect("name", StringRule) { $0.0 }
                    .expect("number", IntRule) { $0.1 }
                
                do {
                    let str = try StringifiedJSONRule(nestedRule: rule).dump(("Test13", 13)) as! String
                    expect(str).to(contain("\"number\":13"))
                    expect(str).to(contain("\"name\":\"Test13\""))
                } catch {
                    expect(error).to(beNil())
                }
            }
            
            it("should be able to dump value at JSON path") {
                let userStruct = User(id: "123456", name: nil)
                
                let m = StructRule(ref(User(id: nil, name: nil)))
                    .expect("message"/"payload"/"createdBy"/"user"/"id", StringRule, { $0.value.id = $1 }) { $0.id }
                    .optional("message"/"payload"/"createdBy"/"user"/"login", StringRule) { $0.value.name = $1 }
    
                do {
                    let data = try m.dump(userStruct)
                    let user = try m.validate(data)
                    expect(user).toNot(beNil())
                    expect(user.id).to(equal(userStruct.id))
                } catch {
                    expect(error).to(beNil())
                }
                
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
        }
     
        describe("Enum dump") {
            it("should performs enum dump of any internal type") {
                
                let enumRule = EnumRule<IssuedBy>()
                    .option("FMS", .fms)
                    .option("SMS", .sms)
                    .option("OPG", .opg)
                    .option(0, .unknown)
                
                let intEnumRule = EnumRule<Active>()
                    .option(0, .inactive)
                    .option(1, .active)
                
                let testRule = StructRule(ref(Pass()))
                    .expect("issuedBy", enumRule, { $0.value.issuedBy = $1 }) { $0.issuedBy }
                    .expect("active", intEnumRule, { $0.value.active = $1 }) { $0.active }
                
                let testRules = ArrayRule(itemRule: testRule)
                
                let rules = [
                    Pass(issuedBy: .fms, active: .active),
                    Pass(issuedBy: .opg, active: .inactive),
                    Pass(issuedBy: .unknown, active: .inactive)
                ]
                
                let d = try! testRules.dump(rules)
                let newRules = try! testRules.validate(d)
                
                expect(newRules.count).to(equal(3))
                expect(newRules[2].issuedBy).to(equal(IssuedBy.unknown))
                expect(newRules[2].active).to(equal(Active.inactive))
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
