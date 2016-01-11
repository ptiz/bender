//
//  Bender.swift
//  Bender
//
//  Created by Evgenii Kamyshanov on 04.01.16.
//  Copyright © 2016 Evgenii Kamyshanov. All rights reserved.
//

import Foundation
import UIKit

indirect enum ValidateError: ErrorType {
    case InvalidJSONType(String, ValidateError?)
    case ExpectedNotFound(String, ValidateError?)
    
    var description: String {
        switch self {
        case InvalidJSONType(let str, let cause):
            return descr(cause, str)
        case .ExpectedNotFound(let str, let cause):
            return descr(cause, str)
        }
    }
    
    private func descr(cause: ValidateError?, _ msg: String) -> String {
        if let causeDescr = cause?.description {
            return msg + " " + causeDescr
        }
        return msg
    }
}

protocol Rule {
    typealias V
    func validate(jsonValue: AnyObject) throws -> V
}

class TypeRule<T>: Rule {
    typealias V = T
    
    func validate(jsonValue: AnyObject) throws -> T {
        guard let value = jsonValue as? T else {
            throw ValidateError.InvalidJSONType("Value of unexpected type found: \"\(jsonValue)\". Expected \(T.self).", nil)
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
            throw ValidateError.InvalidJSONType("Value of unexpected type found: \"\(jsonValue)\". Expected dictionary \(T.self).", nil)
        }
        
        let newStruct = factory()
        
        for (name, rule) in mandatoryRules {
            guard let value = json[name] else {
                throw ValidateError.ExpectedNotFound("Error validating \(jsonValue) as \(T.self). Mandatory field \"\(name)\" not found in struct.", nil)
            }
            
            do {
                try rule(value, newStruct)
            } catch let err as ValidateError {
                throw ValidateError.InvalidJSONType("Error validating \(T.self).", err)
            }
        }
        
        for (name, rule) in optionalRules {
            if let value = json[name] {
                do {
                    try rule(value, newStruct)
                } catch let err as ValidateError {
                    throw ValidateError.InvalidJSONType("Error validating \(T.self).", err)
                }
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
            throw ValidateError.InvalidJSONType("Value of unexpected type found: \"\(jsonValue)\". Expected array of \(T.self).", nil)
        }
        
        var newArray = [T]()
        
        for object in json {
            do {
                if let item = try itemRule?(object) {
                    newArray.append(item)
                }
            } catch let err as ValidateError {
                throw ValidateError.InvalidJSONType("Error validating array of \(T.self).", err)
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
            throw ValidateError.InvalidJSONType("Value of unexpected type found: \"\(jsonValue)\". Expected \(SourceType.self).", nil)
        }
        
        for (value, enumValue) in cases {
            if json == value {
                return enumValue
            }
        }
        
        throw ValidateError.ExpectedNotFound("Error validating \(T.self). Invalid enum case found: \"\(json)\".", nil)
    }
}

class StringEnumRule<T>: EnumRule<T, String> {
}
