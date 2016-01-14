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
            return "\(msg)\n\(causeDescr)"
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
let UIntRule = TypeRule<UInt>()
let DoubleRule = TypeRule<Double>()
let FloatRule = TypeRule<Float>()
let BoolRule = TypeRule<Bool>()
let StringRule = TypeRule<String>()

class StructRule<T>: Rule {
    typealias V = T
    typealias RuleClosure = (AnyObject, T) throws -> Void
    
    private var mandatoryRules = [String: RuleClosure]()
    private var optionalRules = [String: RuleClosure]()
    private let factory: ()->T
    
    init(_ factory: ()->T) {
        self.factory = factory
    }
    
    func expect<R: Rule>(name: String, _ rule: R, _ bind: ((T, R.V)->Void)? = nil) -> Self {
        mandatoryRules[name] = storeRule(name, rule, bind)
        return self
    }
    
    func optional<R: Rule>(name: String, _ rule: R, _ bind: ((T, R.V)->Void)? = nil) -> Self {
        optionalRules[name] = storeRule(name, rule, bind)
        return self
    }
    
    func validate(jsonValue: AnyObject) throws -> T {
        guard let json = jsonValue as? [String: AnyObject] else {
            throw ValidateError.InvalidJSONType("Value of unexpected type found: \"\(jsonValue)\". Expected dictionary \(T.self).", nil)
        }
        
        let newStruct = factory()
        
        try validateMandatoryRules(json, withNewStruct: newStruct)
        try validateOptionalRules(json, withNewStruct: newStruct)
        
        return newStruct
    }
    
    //MARK: - implementation
    
    private func storeRule<R: Rule>(name: String, _ rule: R, _ bind: ((T, R.V)->Void)? = nil) -> RuleClosure {
        return { (json, struc) in
            if let b = bind {
                b(struc, try rule.validate(json))
            } else {
                try rule.validate(json)
            }
        }
    }
    
    private func validateMandatoryRules(json: [String: AnyObject], withNewStruct newStruct: T) throws {
        for (name, rule) in mandatoryRules {
            guard let value = json[name] else {
                throw ValidateError.ExpectedNotFound("Error validating \"\(json)\" as \(T.self). Mandatory field \"\(name)\" not found in struct.", nil)
            }
            
            do {
                try rule(value, newStruct)
            } catch let err as ValidateError {
                throw ValidateError.InvalidJSONType("Error validating mandatory field \"\(name)\" for \(T.self).", err)
            }
        }
    }
    
    private func validateOptionalRules(json: [String: AnyObject], withNewStruct newStruct: T) throws {
        for (name, rule) in optionalRules {
            if let value = json[name] {
                do {
                    try rule(value, newStruct)
                } catch let err as ValidateError {
                    throw ValidateError.InvalidJSONType("Error validating optional field \"\(name)\" for \(T.self).", err)
                }
            }
        }
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
        
        var counter = 0
        for object in json {
            counter += 1
            do {
                if let item = try itemRule?(object) {
                    newArray.append(item)
                }
            } catch let err as ValidateError {
                throw ValidateError.InvalidJSONType("Error validating array of \(T.self): item #\(counter) could not be validated.", err)
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
