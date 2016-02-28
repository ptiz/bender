//
//  BenderTests.swift
//  BenderTests
//
//  Created by Evgenii Kamyshanov on 04.01.16.
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

class BenderInTests: QuickSpec {
    
    override func spec() {
        
        describe("Basic struct validation") {
            it("should perform nested struct validating and binding") {
                
                let jsonData = dataFromFile("basic_test")
                
                let passportRule = ClassRule(Passport())
                    .expect("issuedBy", StringRule, { $0.issuedBy = $1 })
                    .optional("number", IntRule, { $0.number = $1 })
                    .expect("valid", BoolRule, { $0.valid = $1 })
                
                let personRule = ClassRule(Person())
                    .expect("name", StringRule) { $0.name = $1 }
                    .expect("age", FloatRule) { $0.age = $1 }
                    .expect("passport", passportRule, { $0.passport = $1 })
                    .optional("oldPass", passportRule, { $0.oldPass = $1 })

                do {
                    let person = try personRule.validateData(jsonData)
                    
                    expect(person).toNot(beNil())
                    
                    expect(person.age).to(equal(37.5))
                    
                    expect(person.passport).toNot(beNil())
                    expect(person.passport.number).to(equal(123))
                    expect(person.passport.valid).to(equal(true))
                    
                    expect(person.oldPass).to(beNil())
                    
                } catch let err {
                    expect(false).to(equal(true), description: "\(err)")
                }
            }
            
            it("should handle recurisively nested structs") {
                
                let jsonObject = jsonFromFile("recursive_test")
                
                let folderRule = StructRule(ref(Folder(name: "", size: 0, folders: nil)))
                    .expect("name", StringRule) { $0.value.name = $1 }
                    .expect("size", Int64Rule) { $0.value.size = $1 }
                
                folderRule
                    .optional("folders", ArrayRule(itemRule: folderRule)) { $0.value.folders = $1 }
                
                do {
                    let folder = try folderRule.validate(jsonObject)
                    
                    expect(folder).toNot(beNil())
                    expect(folder.folders!.count).to(equal(2))
                    expect(folder.folders![1].name).to(equal("nested 2"))
                    expect(folder.folders![1].folders!.count).to(equal(1))
                    expect(folder.folders![1].folders![0].name).to(equal("nested 21"))
                    
                } catch let err {
                    expect(false).to(equal(true), description: "\(err)")
                }
                
            }
            
            it("should throw if expected field does not exist") {
                
                let jsonObject = jsonFromFile("basic_test")
                
                let passportRule = ClassRule(Passport())
                    .expect("issued", StringRule) { $0.issuedBy = $1 }
                    .optional("number", IntRule) { $0.number = $1 }
                
                let personRule = ClassRule(Person())
                    .expect("passport", passportRule) { $0.passport = $1 }

                expect{ try personRule.validate(jsonObject) }.to(throwError(RuleError.InvalidJSONType("", nil)))
                expect{ try personRule.validate(jsonObject) }.to(throwError { (error: RuleError) in
                        let stack = error.unwindStack()
                        expect(stack.count).to(equal(2))
                        expect("\(stack[1])").to(contain("Mandatory field \"issued\" not found in struct."))
                    })
            }
            
            it("should throw if expected field is of wrong type") {
                
                let jsonObject = jsonFromFile("basic_test")
                
                let personRule = ClassRule(Person())
                    .expect("name", FloatRule) { $0.age = $1 }
                
                expect{ try personRule.validate(jsonObject) }.to(throwError(RuleError.InvalidJSONType("", nil)))
                expect{ try personRule.validate(jsonObject) }.to(throwError { (error: RuleError) in
                        expect(error.description).to(equal("Unable to validate mandatory field \"name\" for Person.\nValue of unexpected type found: \"John\". Expected Float."))
                    })
            }
            
            it("should throw if requirement was not met") {

                let jsonObject = jsonFromFile("basic_test")
                
                let personRule = ClassRule(Person())
                    .required("name", StringRule) { $0 == "John" }
                    .required("age", FloatRule) { $0 == 100.0 } //actual 37.5

                expect{ try personRule.validate(jsonObject) }.to(throwError(RuleError.UnmetRequirement("", nil)))
                expect{ try personRule.validate(jsonObject) }.to(throwError { (error: RuleError) in
                    expect(error.description).to(equal("Requirement was not met for field \"age\" with value \"37.5\""))
                    })                
            }
            
            it("should be able to provide default values for optionals") {

                let jsonObject = jsonFromFile("defaults_test")
                
                let defaultValue = 13.13
                
                let employeeRule = ClassRule(Employee())
                    .expect("name", StringRule) { $0.name = $1 }
                    .optional("age", DoubleRule, ifNotFound: defaultValue) { $0.age = $1 }
                
                let employee = try! ArrayRule(itemRule: employeeRule).validate(jsonObject)
                
                expect(employee[0].age).to(equal(defaultValue))
                expect(employee[1].age).to(equal(defaultValue))
                expect(employee[2].age).to(equal(37.8))
            }
            
        }
        
        describe("Advanced struct validation") {
            it("should be able to work with tuples") {
                
                let jsonObject = jsonFromFile("basic_test")
                
                let rule = StructRule(ref(("", 0)))
                    .expect("name", StringRule) { $0.value.0 = $1 }
                    .expect("age", IntRule) { $0.value.1 = $1 }
                
                let tuple = try! rule.validate(jsonObject)
                
                expect(tuple.0).to(equal("John"))
                expect(tuple.1).to(equal(37))
            }
            
            context("bind struct should not be created until the validation is complete") {
                it("should not allow an object creation if a validation throws") {

                    let jsonObject = jsonFromFile("basic_test")
                    
                    var creationCounter = 0
                    TraceableObject.traceObjectCreation = { creationCounter += 1 }
                    
                    let rule = ClassRule(TraceableObject())
                        .expect("name", StringRule) { $0.name = $1 }
                    
                    let obj = try? rule.validate(jsonObject)

                    expect(obj).toNot(beNil())
                    expect(creationCounter).to(equal(1))
                    
                    let ruleBreak = ClassRule(TraceableObject())
                        .expect("nameError", StringRule) { $0.name = $1 }
                    
                    let objBreak = try? ruleBreak.validate(jsonObject)
                    
                    expect(objBreak).to(beNil())
                    expect(creationCounter).to(equal(1))
                }
            }
            
            it("should be able to go through JSON by name path") {
                let jsonObject = jsonFromFile("path_test")
                
                let r = rule(StringRule, atPath: "message", "payload", "createdBy", "user", "id")
                let userID = try? r.validate(jsonObject)
                
                expect(userID).toNot(beNil())
                expect(userID).to(equal("123456"))
                
                let m = StructRule(ref(User(id: nil, name: nil)))
                    .expect("message", rule(StringRule, atPath: "payload", "createdBy", "user", "id")) { $0.value.id = $1 }
                    .expect("message", rule(StringRule, atPath: "payload", "createdBy", "user", "login")) { $0.value.name = $1 }
                
                let user = try? m.validate(jsonObject)
                
                expect(user).toNot(beNil())
                expect(user!.id).to(equal("123456"))
                
            }
        }
        
        describe("Array validation") {
            it("should perform array validation as field in struct") {
                
                let jsonObject = jsonFromFile("array_test")
                
                let passportRule = ClassRule(Passport())
                    .optional("issuedBy", StringRule, { $0.issuedBy = $1 })
                    .expect("number", IntRule, { $0.number = $1 })
                
                let passportArrayRule = ArrayRule(itemRule: passportRule)
                
                let passportsRule = ClassRule(Passports())
                    .expect("passports", passportArrayRule, { $0.items = $1 })
                    .expect("numbers", ArrayRule(itemRule: IntRule), { $0.numbers = $1 })
                
                do {
                    let passports = try passportsRule.validate(jsonObject)
                    
                    expect(passports.items.count).to(equal(3))
                    expect(passports.numbers.count).to(equal(7))
                    
                    expect(passports.items[2].number).to(equal(333))
                    expect(passports.numbers[6]).to(equal(27))
                    
                } catch let err {
                    expect(false).to(equal(true), description: "\(err)")
                }
                
            }
            
            it("should perform array validation as root object") {
                
                let jsonObject = jsonFromFile("natural_array_test")
                let arrayRule = ArrayRule(itemRule: IntRule)
                
                do {
                    let numbers = try arrayRule.validate(jsonObject)
                    
                    expect(numbers.count).to(equal(5))
                    expect(numbers[4]).to(equal(199))
                    
                } catch let err {
                    expect(false).to(equal(true), description: "\(err)")
                }
            }
            
            it("should throw if an item struct is of wrong type") {
                
                let jsonObject = jsonFromFile("array_test")
                
                let passportRule = ClassRule(Passport())
                    .optional("issuedBy", StringRule) { $0.issuedBy = $1 }
                    .expect("numberX", IntRule) { $0.number = $1 }
                
                let passportArrayRule = ArrayRule(itemRule: passportRule)
                
                let passportsRule = ClassRule(Passports())
                    .expect("passports", passportArrayRule, { $0.items = $1 })
                    .expect("numbers", ArrayRule(itemRule: IntRule), { $0.numbers = $1 })
                
                expect{ try passportsRule.validate(jsonObject) }.to(throwError(RuleError.InvalidJSONType("", nil)))
                expect{ try passportsRule.validate(jsonObject) }.to(throwError { (error: RuleError) in
                        let stack = error.unwindStack()
                        expect(stack.count).to(equal(3))
                        expect("\(stack[2])").to(contain("Mandatory field \"numberX\" not found in struct."))                    
                    })
            }
            
            it("should not throw if non-throwable invalidItemHandler is given") {
                let jsonObject = jsonFromFile("array_skip_test")
                
                let passportRule = ClassRule(Passport())
                    .optional("issuedBy", StringRule) { $0.issuedBy = $1 }
                    .expect("number", IntRule) { $0.number = $1 }
                
                let passportArrayRule = ArrayRule(itemRule: passportRule) {
                        print("Error: \($0)")
                    }
                
                let passportsRule = StructRule(ref([Passport]()))
                    .expect("passports", passportArrayRule, { $0.value = $1 })
                
                expect{ try passportsRule.validate(jsonObject) }.toNot(throwError(RuleError.InvalidJSONType("", nil)))
                
                let objects = try? passportsRule.validate(jsonObject)
                expect(objects?.count).to(equal(2))
            }
            
        }
        
        describe("Enum validation") {
            it("should performs enum validation of any internal type") {
                
                let jsonObject = jsonFromFile("enum_test")
                
                let enumRule = EnumRule<IssuedBy>()
                    .option("FMS", .FMS)
                    .option("SMS", .SMS)
                    .option("OPG", .OPG)
                    .option(0, .Unknown)                
                
                let intEnumRule = EnumRule<Active>()
                    .option(0, .Inactive)
                    .option(1, .Active)
                
                let testRule = StructRule(ref(Pass()))
                    .expect("issuedBy", enumRule) { $0.value.issuedBy = $1 }
                    .expect("active", intEnumRule) { $0.value.active = $1 }
                
                let testRules = ArrayRule(itemRule: testRule)
                
                do {
                    let tests = try testRules.validate(jsonObject)
                    
                    expect(tests.count).to(equal(4))
                    
                    expect(tests[1].active).to(equal(Active.Inactive))
                    expect(tests[1].issuedBy).to(equal(IssuedBy.SMS))
                    
                } catch let err {
                    expect(false).to(equal(true), description: "\(err)")
                }
                
            }
            
            it("should throw if enum is not in set of values provided") {
                let jsonObject = jsonFromFile("enum_test")
                
                let enumRule = EnumRule<IssuedBy>()
                    .option("XMS", .FMS)
                    .option("XMS", .SMS)
                    .option("XPG", .OPG)
                    .option(0, .Unknown)
                
                let testRule = StructRule(ref(Pass()))
                    .expect("issuedBy", enumRule) { $0.value.issuedBy = $1 }
                
                let testRules = ArrayRule(itemRule: testRule)
                
                expect{ try testRules.validate(jsonObject) }.to(throwError(RuleError.InvalidJSONType("", nil)))
                expect{ try testRules.validate(jsonObject) }.to(throwError { (error: RuleError) in
                    expect(error.description).to(equal("Unable to validate array of Pass: item #0 could not be validated.\nUnable to validate mandatory field \"issuedBy\" for Pass.\nUnable to validate enum IssuedBy. Unexpected enum case found: \"FMS\"."))
                    })

            }
            
            it("should be able to provide default value for unlisted items") {
                
                let jsonObject = jsonFromFile("defaults_test")
                
                let adminStaffRule = EnumRule(ifNotFound: AdminStaff.Other)
                    .option("ENGINEER", .Engineer)
                
                let employeeRule = ClassRule(Employee())
                    .expect("name", StringRule) { $0.name = $1 }
                    .optional("position", adminStaffRule) { $0.position = $1 }
                
                let employee = try! ArrayRule(itemRule: employeeRule).validate(jsonObject)
                
                expect(employee[0].position).to(equal(AdminStaff.Other))
                expect(employee[1].position).to(equal(AdminStaff.Engineer))
                expect(employee[2].position).to(equal(AdminStaff.Other))
            }
            
            
        }
        
        describe("Stringified JSON validation") {
            it("should perform validation in accordance with the nested rule") {
                
                let jsonObject = jsonFromFile("stringified_test")
                
                let passportRule = ClassRule(Passport())
                    .expect("issuedBy", StringRule, { $0.issuedBy = $1 })
                    .optional("number", IntRule, { $0.number = $1 })
                    .expect("valid", BoolRule, { $0.valid = $1 })
                
                let personRule = ClassRule(Person())
                    .expect("passport", StringifiedJSONRule(nestedRule: passportRule), { $0.passport = $1 })
                    .optional("passports", StringifiedJSONRule(nestedRule: ArrayRule(itemRule: passportRule))) { $0.nested = $1 }
                
                do {
                    let person = try personRule.validate(jsonObject)
                    
                    expect(person).toNot(beNil())
                    
                    expect(person.passport).toNot(beNil())
                    expect(person.passport.number).to(equal(123))
                    expect(person.passport.valid).to(equal(true))
                    
                    expect(person.nested.count).to(equal(2))
                    
                } catch let err {
                    expect(false).to(equal(true), description: "\(err)")
                }
            }
            
            it("should throw on parse error: comma absent after the 'number' field definition") {
                
                let jsonObject = jsonFromFile("stringified_negative_test")
                
                let passportRule = ClassRule(Passport())
                    .expect("issuedBy", StringRule, { $0.issuedBy = $1 })
                
                let personRule = ClassRule(Person())
                    .expect("passport", StringifiedJSONRule(nestedRule: passportRule), { $0.passport = $1 })
                
                expect{ try personRule.validate(jsonObject) }.to(throwError(RuleError.InvalidJSONType("", nil)))
                expect{ try personRule.validate(jsonObject) }.to(throwError { (error: RuleError) in
                        let stack = error.unwindStack()
                        expect(stack.count).to(equal(2))
                        expect("\(stack[1])").to(contain("Badly formed object around character 15."))                    
                    })

            }
        }
    }
}

func jsonFromFile(name: String) -> AnyObject {
    let data = NSData(contentsOfFile: NSBundle(forClass: BenderInTests.self).pathForResource(name, ofType: "json")!)!
    return try! NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
}

func dataFromFile(name: String) -> NSData? {
    return NSData(contentsOfFile: NSBundle(forClass: BenderInTests.self).pathForResource(name, ofType: "json")!)
}

class Passport {
    var number: Int?
    var issuedBy: String!
    var valid: Bool!
}

class Person {
    var name: String! = nil
    var age: Float! = nil
    var passport: Passport! = nil
    var oldPass: Passport?
    var nested: [Passport] = []
}

class Passports {
    var items: [Passport] = []
    var numbers: [Int] = []
}

enum IssuedBy {
    case Unknown
    case FMS
    case SMS
    case OPG
}

enum Active {
    case Active
    case Inactive
}

struct Pass {
    var issuedBy: IssuedBy = .Unknown
    var active: Active = .Inactive
}

struct Folder {
    var name: String
    var size: Int64
    var folders: [Folder]?
}

enum AdminStaff {
    case Engineer
    case Other
}

class Employee {
    var name: String?
    var age: Double?
    var position: AdminStaff?
}

class TraceableObject {
    static var traceObjectCreation: (()->Void)?
    init() {
        TraceableObject.traceObjectCreation?()
    }
    var name: String!
}

struct User {
    var id: String!
    var name: String!
}
