//
//  Bender.swift
//  Bender
//
//  Created by Evgenii Kamyshanov on 04.01.16.
//  Copyright © 2016 Evgenii Kamyshanov. All rights reserved.
//

import Foundation
import UIKit

enum ValidateError: ErrorType {
    case InvalidJSON
    case InvalidJSONType(String)
}

protocol Rule {
    typealias V
    func validate(jsonValue: AnyObject) throws -> V
}

class TypeRule<T>: Rule {
    typealias V = T
    
    func validate(jsonValue: AnyObject) throws -> T {
        guard let value = jsonValue as? T else {
            throw ValidateError.InvalidJSON
        }
        return value
    }
}

let IntRule = TypeRule<Int>()

class StructRule<T>: Rule {
    typealias V = T
    typealias RuleClosure = (AnyObject, T) throws -> Void
    
    private var mandatoryRules = [String: RuleClosure]()
    private var optionalRules = [String: RuleClosure]()
    private let factory: ()->T
    
    init(_ factory: ()->T) {
        self.factory = factory
    }
        
    func expect<R: Rule>(name: String, _ rule: R, _ bind: (T, R.V)->Void) -> Self {
        mandatoryRules[name] = { (json, struc) in
            bind(struc, try rule.validate(json))
        }
        return self
    }
    
    func optional<R: Rule>(name: String, _ rule: R, _ bind: (T, R.V)->Void) -> Self {
        optionalRules[name] = { (json, struc) in
            bind(struc, try rule.validate(json))
        }
        return self
    }
    
    func validate(jsonValue: AnyObject) throws -> T {
        guard let json = jsonValue as? [String: AnyObject] else {
            throw ValidateError.InvalidJSON
        }
        
        let newStruct = factory()
        
        for (name, rule) in mandatoryRules {
            guard let value = json[name] else {
                throw ValidateError.InvalidJSONType("Mandatory \(name) is not found in \(json)")
            }
            try rule(value, newStruct)
        }
        
        for (name, rule) in optionalRules {
            if let value = json[name] {
                try rule(value, newStruct)
            }
        }
        
        return newStruct
    }
    
}

class ArrayRule<T>: Rule {
    typealias V = [T]
    typealias ValidateClosure = (AnyObject) throws -> T
    
    private var itemRule: ValidateClosure?
    
    func item<R: Rule where R.V == T>(rule: R) -> Self {
        itemRule = { json in
            try rule.validate(json)
        }
        return self
    }
    
    func validate(jsonValue: AnyObject) throws -> V {
        guard let json = jsonValue as? [AnyObject] else {
            throw ValidateError.InvalidJSON
        }
        
        var newArray = [T]()
        
        for object in json {
            if let item = try itemRule?(object) {
                newArray.append(item)
            }
        }
        
        return newArray
    }
}

class EnumRule<T, S: Equatable>: Rule {
    typealias V = T
    typealias SourceType = S
    
    var cases: [(SourceType, T)] = []
    
    func option(value: SourceType, _ enumValue: T) -> Self {
        cases.append((value, enumValue))
        return self
    }
    
    func validate(jsonValue: AnyObject) throws -> V {
        guard let json = jsonValue as? SourceType else {
            throw ValidateError.InvalidJSON
        }
        
        for (value, enumValue) in cases {
            if json == value {
                return enumValue
            }
        }
        
        throw ValidateError.InvalidJSONType("Unknown enum value: \(json)")
    }
}

class StringEnumRule<T>: EnumRule<T, String> {
    
}
