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

/**
 Bender throwing error type
 
 - InvalidJSONType:   basic bender error, contains string and optional ValidateError cause
 - ExpectedNotFound:  throws if expected was not found, contains string and optional ValidateError cause
 - JSONSerialization: throws if JSON parser fails, contains string and optional ValidateError cause
 */
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

/**
 Base generic bender protocol for validator rule.
 */
protocol Rule {
    typealias V
    func validate(jsonValue: AnyObject) throws -> V
}

/**
 Base class for numeric validators
*/
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

/**
 Validator for signed and unsigned integer numerics
*/
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

/**
 Vaidator for floating point numerics
*/
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

/**
 Validator for any generic type that can be cast from NSValue automatically
*/
class TypeRule<T>: Rule {
    typealias V = T
    
    func validate(jsonValue: AnyObject) throws -> T {
        guard let value = jsonValue as? T else {
            throw ValidateError.InvalidJSONType("Value of unexpected type found: \"\(jsonValue)\". Expected \(T.self).", nil)
        }
        return value
    }
}

/// Set of predefined rules for integral types
let IntRule = IntegerRule<Int>()
let Int64Rule = IntegerRule<Int64>()
let UIntRule = IntegerRule<UInt>()
let DoubleRule = FloatingRule<Double>()
let FloatRule = FloatingRule<Float>()
let BoolRule = TypeRule<Bool>()
let StringRule = TypeRule<String>()

/**
 Validator for compound types: classes or structs. Validates JSON struct for particular type T,
 which is passed by value of type RefT.
*/
class CompoundRule<T, RefT>: Rule {
    typealias V = T
    typealias RuleClosure = (AnyObject, RefT) throws -> Void
    
    private var mandatoryRules = [String: RuleClosure]()
    private var optionalRules = [String: RuleClosure]()
    private let factory: ()->RefT
    
    /**
     Validator initializer
     
     - parameter factory: autoclosure for allocating object, which returns reference to object of generic type T
     */
    init(@autoclosure(escaping) _ factory: ()->RefT) {
        self.factory = factory
    }

    /**
     Method for declaring mandatory field expected in a JSON dictionary. If the field is not found during validation,
     an error will be thrown.
     
     - parameter name: string name of the field
     - parameter rule: rule that should validate the value of the field
     - parameter bind: optional bind closure, that receives reference to object of generic parameter type as a first argument and validated field value as a second one
     
     - returns: returns self for field declaration chaining
     */
    func expect<R: Rule>(name: String, _ rule: R, _ bind: ((RefT, R.V)->Void)? = nil) -> Self {
        mandatoryRules[name] = storeRule(name, rule, bind)
        return self
    }
    
    /**
     Method for declaring optional field that may be found in a JSON dictionary. If the field is not found during validation,
     nothing happens.
     
     - parameter name: string name of the field
     - parameter rule: rule that should validate the value of the field
     - parameter bind: optional bind closure, that receives reference to object of generic parameter type as a first argument and validated field value as a second one
     
     - returns: returns self for field declaration chaining
     */
    func optional<R: Rule>(name: String, _ rule: R, _ bind: ((RefT, R.V)->Void)? = nil) -> Self {
        optionalRules[name] = storeRule(name, rule, bind)
        return self
    }
    
    /**
     Validates JSON dictionary and returns T value if succeeded. Validation throws if jsonValue is not a JSON dictionary or if any nested rule throws.
     
     - parameter jsonValue: JSON dictionary to be validated and converted into T
     
     - throws: throws ValidateError
     
     - returns: object of generic parameter argument if validation was successful
     */
    func validate(jsonValue: AnyObject) throws -> T {
        guard let json = jsonValue as? [String: AnyObject] else {
            throw ValidateError.InvalidJSONType("Value of unexpected type found: \"\(jsonValue)\". Expected dictionary \(T.self).", nil)
        }
        
        let newStruct = factory()
        
        try validateMandatoryRules(json, withNewStruct: newStruct)
        try validateOptionalRules(json, withNewStruct: newStruct)
        
        return value(newStruct)
    }
    
    /**
     Functions that unboxes reference to generic parameter and returns object of type T
     
     - parameter newStruct: reference to generic parameter T
     
     - returns: object of generic parameter T
     */
    func value(newStruct: RefT) -> T {
        return newStruct as! T
    }
    
    //MARK: - implementation
    
    private func storeRule<R: Rule>(name: String, _ rule: R, _ bind: ((RefT, R.V)->Void)? = nil) -> RuleClosure {
        return { (json, struc) in
            if let b = bind {
                b(struc, try rule.validate(json))
            } else {
                try rule.validate(json)
            }
        }
    }
    
    private func validateMandatoryRules(json: [String: AnyObject], withNewStruct newStruct: RefT) throws {
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
    
    private func validateOptionalRules(json: [String: AnyObject], withNewStruct newStruct: RefT) throws {
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

/**
 Validator of compound JSON object with binding to reference type like class T. Reference type is T itself.
*/
class ClassRule<T>: CompoundRule<T, T> {
    
    override init(@autoclosure(escaping) _ factory: ()->T) {
        super.init(factory)
    }
    
    override func value(newStruct: T) -> T {
        return newStruct
    }
}

/**
 Validator of compound JSON object with binding to value type like struct T. Reference type is ref<T>.
*/
class StructRule<T>: CompoundRule<T, ref<T>> {

    override init(@autoclosure(escaping) _ factory: ()->ref<T>) {
        super.init(factory)
    }
    
    override func value(newStruct: ref<T>) -> T {
        return newStruct.value
    }
}

/**
 Validator for arrays of items of type T, that should be validated by rule of type R.
*/
class ArrayRule<T, R: Rule where R.V == T>: Rule {
    typealias V = [T]
    typealias ValidateClosure = (AnyObject) throws -> T
    
    private var itemRule: R
    
    /**
     Validator initializer
     
     - parameter itemRule: rule for validating array items
     */
    init(itemRule: R) {
        self.itemRule = itemRule
    }
    
    /**
     Validates JSON array and returns [T] if succeeded. Validation throws if jsonValue is not a JSON array or if item rule throws for any item.
     
     - parameter jsonValue: JSON array to be validated and converted into [T]
     
     - throws: throws ValidateError
     
     - returns: array of objects of first generic parameter argument if validation was successful
     */
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

/**
 Validator for enum of type T. Checks that JSON value to be validated is equal to any option stored and .
 If all stored properties do not match, throws ValidateError.
*/
class EnumRule<T>: Rule {
    typealias V = T
    
    var cases: [(AnyObject) throws ->T?] = []
    
    /**
     Method for declaring matching between given value and enum case of type T. 
     JSON value should be comparable with the value, i.e. should cast to S which is Equatable.
     
     - parameter value:     constant of type S which is corresponding to enumValue
     - parameter enumValue: enum value of type T
     
     - returns: self for options declaration chaining
     */
    func option<S: Equatable>(value: S, _ enumValue: T) -> Self {
        cases.append({ jsonValue in
            guard let json = jsonValue as? S where json == value else {
                return nil
            }
            return enumValue
        })
        return self
    }
    
    /**
     Compares all stored option constants with given JSON value. If one of them matches, returns corresponding enum case. Throws otherwise.
     
     - parameter jsonValue: JSON value that can be compared with the stored value of type S
     
     - throws: throws ValidateError
     
     - returns: returns enum case of type T if matching value found, throws otherwise
     */
    func validate(jsonValue: AnyObject) throws -> V {
        for theCase in cases {
            if let value = try theCase(jsonValue) {
                return value
            }
        }
        
        throw ValidateError.ExpectedNotFound("Error validating enum \(T.self). Invalid enum case found: \"\(jsonValue)\".", nil)
    }
}

/**
 Validator of JSON encoded into string like this: "\"field": \"value\"". Encoded JSON should be validated by given rule of type R.
*/
class StringifiedJSONRule<R: Rule>: Rule {
    typealias V = R.V
    
    let nestedRule: R
    
    /**
     Validator initializer
     
     - parameter nestedRule: rule to validate JSON decoded from string
     */
    init(nestedRule: R) {
        self.nestedRule = nestedRule
    }
    
    /**
     Checks if string contains JSON. Calls nested rule validator if succeeded. Throws ValidateError otherwise.
     
     - parameter jsonValue: string containing encoded JSON
     
     - throws: throws ValidateError
     
     - returns: returns object of nested rule struct type (i.e. R.V), if validated. Throws otherwise.
     */
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

/**
 Generic class for boxing value type.
*/
class ref<T> {
    var value: T
    
    init(_ value: T) {
        self.value = value
    }
}
