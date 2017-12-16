//
//  BenderPerformanceTests.swift
//  Bender
//
//  Created by Evgenii Kamyshanov on 13.12.16.
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

class BenderPerfTests: XCTestCase {
    
    func testPerformance_Binding_5Mb_JSON() {
        
        let friendRule = ClassRule(Friend())
            .expect("id", IntRule, { $0.ID = $1 })
            .expect("name", StringRule, { $0.name = $1 })
        
        let itemRule = ClassRule(Item())
            .expect("_id", StringRule, { $0.ID = $1 })
            .expect("index", IntRule, { $0.index = $1 })
            .expect("guid", StringRule, { $0.guid = $1 })
            .expect("isActive", BoolRule, { $0.isActive = $1 })
            .expect("balance", StringRule, { $0.balance = $1 })
            .expect("picture", StringRule, { $0.picture = $1 })
            .expect("age", IntRule, { $0.age = $1 })
            .expect("eyeColor", StringRule, { $0.eyeColor = $1 })
            .expect("name", StringRule, { $0.name = $1 })
            .expect("gender", StringRule, { $0.gender = $1 })
            .expect("company", StringRule, { $0.company = $1 })
            .expect("email", StringRule, { $0.email = $1 })
            .expect("phone", StringRule, { $0.phone = $1 })
            .expect("tags", ArrayRule(itemRule: StringRule), { $0.tags = $1 })
            .expect("latitude", DoubleRule, { $0.latitude = $1 })
            .expect("longitude", DoubleRule, { $0.longitude = $1 })
            .expect("friends", ArrayRule(itemRule: friendRule), { $0.friends = $1 })
        
        let arrayRule = ArrayRule(itemRule: itemRule)
        
        let path = Bundle(for: BenderPerfTests.self).path(forResource: "five_megs", ofType: "json")!
        let data = try! Data(contentsOf: URL(fileURLWithPath: path))
        let json = try! JSONSerialization.jsonObject(with: data, options: []) as AnyObject
        
        measure {
            let _ = try? arrayRule.validate(json)
        }
        
    }
}

class Friend {
    var ID: Int?
    var name: String?
}

class Item: CustomStringConvertible {
    var ID: String!
    var index: Int!
    var guid: String?
    var isActive: Bool?
    var balance: String?
    var picture: String?
    var age: Int?
    var eyeColor: String?
    var name: String?
    var gender: String?
    var company: String?
    var email: String?
    var phone: String?
    var tags: [String]?
    var latitude: Double?
    var longitude: Double?
    var friends: [Friend]?
    
    var description: String {
        return "@Item id \(ID ?? "#"), name: \(name ?? "no name")"
    }
}
