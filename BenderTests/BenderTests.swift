//
//  BenderTests.swift
//  BenderTests
//
//  Created by Evgenii Kamyshanov on 04.01.16.
//  Copyright © 2016 Evgenii Kamyshanov. All rights reserved.
//

import XCTest
import Quick
import Nimble

@testable import Bender

class Passport {
    var number: Int?
    var issuedBy: String! = nil
}

class Person {
    var name: String! = nil
    var age: Float! = nil
    var passport: Passport! = nil
    var oldPass: Passport?
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

class Pass {
    var issuedBy: IssuedBy = .Unknown
    var active: Active = .Inactive
}

class BenderTests: QuickSpec {
 
    override func spec() {
        
        describe("Basic struct validation") {
            it("should perform nested struct validating and binding") {
                
                let jsonObject = jsonFromFile("basic_test")
                
                let passportRule = StructRule({ Passport() })
                    .expect("issuedBy", TypeRule<String>(), { $0.issuedBy = $1 })
                    .optional("number", IntRule, { $0.number = $1 })
                
                let personRule = StructRule({ Person() })
                    .expect("name", TypeRule<String>()) { $0.name = $1 }
                    .expect("age", TypeRule<Float>()) { $0.age = $1 }
                    .expect("passport", passportRule, { $0.passport = $1 })
                    .optional("oldPass", passportRule, { $0.oldPass = $1 })

                do {
                    let person = try personRule.validate(jsonObject)
                    
                    expect(person).toNot(beNil())
                    expect(person.age).to(equal(37.5))
                    expect(person.passport).toNot(beNil())
                    expect(person.oldPass).to(beNil())
                    expect(person.passport.number).to(equal(123))
                    
                } catch let err {
                    expect(false).to(equal(true), description: "\(err)")
                }
            }
            
            it("should throw if expected field does not exist") {
                
                let jsonObject = jsonFromFile("basic_test")
                
                let passportRule = StructRule({ Passport() })
                    .expect("issued", TypeRule<String>(), { $0.issuedBy = $1 })
                    .optional("number", IntRule, { $0.number = $1 })
                
                let personRule = StructRule({ Person() })
                    .expect("passport", passportRule, { $0.passport = $1 })
                
                expect{ try personRule.validate(jsonObject) }.to(throwError(errorType: ValidateError.self))
                expect{ try personRule.validate(jsonObject) }.to(throwError { (error: ValidateError) in
                        print(error.description)
                    })
            }
            
            it("should throw if expected field is of wrong type") {
                
                let jsonObject = jsonFromFile("basic_test")
                
                let personRule = StructRule({ Person() })
                    .expect("name", TypeRule<Float>()) { $0.age = $1 }
                
                expect{ try personRule.validate(jsonObject) }.to(throwError(errorType: ValidateError.self))
            }
            
        }
        
        describe("Array validation") {
            it("should perform array validation as field in struct") {
                
                let jsonObject = jsonFromFile("array_test")
                
                let passportRule = StructRule({ Passport() })
                    .optional("issuedBy", TypeRule<String>(), { $0.issuedBy = $1 })
                    .expect("number", IntRule, { $0.number = $1 })
                
                let passportArrayRule = ArrayRule()
                    .item(passportRule)
                
                let passportsRule = StructRule({ Passports() })
                    .expect("passports", passportArrayRule, { $0.items = $1 })
                    .expect("numbers", ArrayRule().item(IntRule), { $0.numbers = $1 })
                
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
                let arrayRule = ArrayRule().item(IntRule)
                
                do {
                    let numbers = try arrayRule.validate(jsonObject)
                    
                    expect(numbers.count).to(equal(5))
                    expect(numbers[4]).to(equal(199))
                    
                } catch let err {
                    expect(false).to(equal(true), description: "\(err)")
                }
            }
        }
        
        describe("Enum validtion") {
            it("should performs enum validation of any internal type") {
                
                let jsonObject = jsonFromFile("enum_test")
                
                let enumRule = StringEnumRule<IssuedBy>()
                    .option("FMS", .FMS)
                    .option("SMS", .SMS)
                    .option("OPG", .OPG)
                
                let intEnumRule = EnumRule<Active, Int>()
                    .option(0, .Inactive)
                    .option(1, .Active)
                
                let testRule = StructRule({ Pass() })
                    .expect("issuedBy", enumRule, { $0.issuedBy = $1 })
                    .expect("active", intEnumRule, { $0.active = $1 })
                
                let testRules = ArrayRule()
                    .item(testRule)
                
                do {
                    let tests = try testRules.validate(jsonObject)
                    
                    expect(tests.count).to(equal(3))
                    
                    expect(tests[1].active).to(equal(Active.Inactive))
                    expect(tests[1].issuedBy).to(equal(IssuedBy.SMS))
                    
                } catch let err {
                    expect(false).to(equal(true), description: "\(err)")
                }
                
            }
            
            it("should throw if enum is not in set of values provided") {
                let jsonObject = jsonFromFile("enum_test")
                
                let enumRule = StringEnumRule<IssuedBy>()
                    .option("XMS", .FMS)
                    .option("XMS", .SMS)
                    .option("XPG", .OPG)
                
                let testRule = StructRule({ Pass() })
                    .expect("issuedBy", enumRule, { $0.issuedBy = $1 })
                
                let testRules = ArrayRule()
                    .item(testRule)
                
                expect{ try testRules.validate(jsonObject) }.to(throwError(errorType: ValidateError.self))
            }
        }
    }
}

func jsonFromFile(name: String) -> AnyObject {
    let data = NSData(contentsOfFile: NSBundle(forClass: BenderTests.self).pathForResource(name, ofType: "json")!)!
    return try! NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
}
