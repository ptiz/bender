//
//  Bender.swift
//  Bender
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

import Foundation
import UIKit

indirect enum ValidateError: ErrorType {
    case InvalidJSONType(String, ValidateError?)
    case ExpectedNotFound(String, ValidateError?)
    case JSONSerialization(String, NSError)
    
    var description: String {
        switch self {
        case InvalidJSONType(let str, let cause):
            return descr(cause, str)
        case .ExpectedNotFound(let str, let cause):
            return descr(cause, str)
        case .JSONSerialization(let str, let err):
            return descr(err, str)
        }
    }
    
    private func descr(cause: ValidateError?, _ msg: String) -> String {
        if let causeDescr = cause?.description {
            return "\(msg)\n\(causeDescr)"
        }
        return msg
    }
    
    private func descr(cause: NSError, _ msg: String) -> String {
        let errorDescription = "\n\((cause.userInfo["NSDebugDescription"] ?? cause.description)!)"
        return "\(msg)\(errorDescription)"
    }
}

protocol Rule {
    typealias V
    func validate(jsonValue: AnyObject) throws -> V
}

internal class NumberRule<T>: Rule {
    typealias V = T
    
    func validate(jsonValue: AnyObject) throws -> T {
        guard let number = jsonValue as? NSNumber else {
            throw ValidateError.InvalidJSONType("Value of unexpected type found: \"\(jsonValue)\". Expected \(T.self).", nil)
        }
        return try validateNumber(number)
    }
    
    func validateNumber(number: NSNumber) throws -> T {
        throw ValidateError.InvalidJSONType("Value of unexpected type found: \"\(number)\". Expected \(T.self).", nil)
    }
}

class IntegerRule<T: protocol<IntegerType>>: NumberRule<T> {
    let i: T = 0
    override func validateNumber(number: NSNumber) throws -> T {
        switch i {
        case is Int: return number.integerValue as! T
        case is Int8: return number.charValue as! T
        case is Int16: return number.shortValue as! T
        case is Int32: return number.intValue as! T
        case is Int64: return number.longLongValue as! T
        case is UInt: return number.unsignedIntegerValue as! T
        case is UInt8: return number.unsignedCharValue as! T
        case is UInt16: return number.unsignedShortValue as! T
        case is UInt32: return number.unsignedIntValue as! T
        case is UInt64: return number.unsignedLongLongValue as! T
            
        default: throw ValidateError.InvalidJSONType("Value of unexpected type found: \"\(number)\". Expected \(T.self).", nil)
        }
    }
}

class FloatingRule<T: protocol<FloatLiteralConvertible>>: NumberRule<T> {
    let f: T = 0.0
    override func validateNumber(number: NSNumber) throws -> T {
        switch f {
        case is Float: return number.floatValue as! T
        case is Double: return number.doubleValue as! T
            
        default: throw ValidateError.InvalidJSONType("Value of unexpected type found: \"\(number)\". Expected \(T.self).", nil)
        }
    }
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

let IntRule = IntegerRule<Int>()
let Int64Rule = IntegerRule<Int64>()
let UIntRule = IntegerRule<UInt>()
let DoubleRule = FloatingRule<Double>()
let FloatRule = FloatingRule<Float>()
let BoolRule = TypeRule<Bool>()
let StringRule = TypeRule<String>()

class StructRule<T>: Rule {
    typealias V = T
    typealias RuleClosure = (AnyObject, T) throws -> Void
    
    private var mandatoryRules = [String: RuleClosure]()
    private var optionalRules = [String: RuleClosure]()
    private let factory: ()->T
    
    init(@autoclosure(escaping) _ factory: ()->T) {
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

class ArrayRule<T, R: Rule where R.V == T>: Rule {
    typealias V = [T]
    typealias ValidateClosure = (AnyObject) throws -> T
    
    private var itemRule: R
    
    init(itemRule: R) {
        self.itemRule = itemRule
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
                newArray.append(try itemRule.validate(object))
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

class StringifiedJSONRule<R: Rule>: Rule {
    typealias V = R.V
    
    let nestedRule: R
    
    init(nestedRule: R) {
        self.nestedRule = nestedRule
    }
    
    func validate(jsonValue: AnyObject) throws -> V {
        guard let jsonString = jsonValue as? String, let data = jsonString.dataUsingEncoding(NSUTF8StringEncoding) else {
            throw ValidateError.InvalidJSONType("Value of unexpected type found: \"\(jsonValue)\". Expected stringified JSON.", nil)
        }
        
        do {
            let json = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            return try nestedRule.validate(json)
        } catch let error as NSError {
            throw ValidateError.JSONSerialization("Unable to parse stringified JSON: \(jsonString).", error)
        }
    }
}
