//
//  BenderTests.swift
//  BenderTests
//
//  Created by Evgenii Kamyshanov on 04.01.16.
//  Copyright © 2016 Evgenii Kamyshanov. All rights reserved.
//

import XCTest
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

func jsonFromFile(name: String) -> AnyObject {
    let data = NSData(contentsOfFile: NSBundle(forClass: BenderTests.self).pathForResource(name, ofType: "json")!)!
    return try! NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
}

class BenderTests: XCTestCase {
    
    func testSmoke() {
        
        let jsonObject = jsonFromFile("basic_test")
        
        let passportRule = StructRule({ Passport() })
            .expect("issuedBy", TypeRule<String>(), { $0.issuedBy = $1 })
            .optional("number", IntRule, { $0.number = $1 })
        
        let personRule = StructRule({ Person() })
            .expect("name", TypeRule<String>(), { $0.name = $1 })
            .expect("age", TypeRule<Float>(), { $0.age = $1 })
            .expect("passport", passportRule, { $0.passport = $1 })
            .optional("oldPass", passportRule, { $0.oldPass = $1 })
        
        do {
            let person = try personRule.validate(jsonObject)
            
            XCTAssert(person.passport != nil)
            XCTAssert(person.age == 37.5)
            XCTAssert(person.oldPass == nil)
            
        } catch let err {
            print(err)            
            XCTAssert(false)
        }
        
    }
    
    func testArray() {
        
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
            
            XCTAssert(passports.items.count > 0)
            
        } catch let err {
            print(err)
            XCTAssert(false)
        }
    }
    
    func testNaturalArray() {
        
        let jsonObject = jsonFromFile("natural_array_test")
        
        let arrayRule = ArrayRule().item(IntRule)
        
        do {
            let numbers = try arrayRule.validate(jsonObject)
            XCTAssert(numbers.count > 0)
            
        } catch let err {
            print(err)
            XCTAssert(false)
        }
        
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
    
    func testEnum() {
        
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
            
            XCTAssert(tests.count > 0)
            
        } catch let err {
            print(err)
            XCTAssert(false)
        }
        
    }
    
}
