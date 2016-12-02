//
//  Bender.swift
//  Bender
//
//  Created by Evgenii Kamyshanov on 04.01.16.
//  Original work Copyright © 2016 Evgenii Kamyshanov
//  Modified work Copyright © 2016 Sviatoslav Bulgakov
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

/**
 Bender throwing error type
 
 - InvalidJSONType:   basic bender error, contains string and optional ValidateError cause
 - ExpectedNotFound:  throws if expected was not found, contains string and optional ValidateError cause
 - JSONSerialization: throws if JSON parser fails, contains string and optional ValidateError cause
 */
public indirect enum RuleError: Error, CustomStringConvertible {
    case invalidJSONType(String, RuleError?)
    case expectedNotFound(String, RuleError?)
    case invalidJSONSerialization(String, NSError)
    case invalidDump(String, RuleError?)
    case unmetRequirement(String, RuleError?)
    
    public var description: String {
        switch self {
        case .invalidJSONType(let str, let cause):
            return descr(cause, str)
        case .expectedNotFound(let str, let cause):
            return descr(cause, str)
        case .invalidJSONSerialization(let str, let err):
            return descr(err, str)
        case .invalidDump(let str, let cause):
            return descr(cause, str)
        case .unmetRequirement(let str, let cause):
            return descr(cause, str)
        }
    }
    
    public func unwindStack() -> [Error] {
        switch self {
        case .invalidJSONType(_, let cause):
            return causeStack(cause)
        case .expectedNotFound(_, let cause):
            return causeStack(cause)
        case .invalidJSONSerialization:
            return [self]
        case .invalidDump(_, let cause):
            return causeStack(cause)
        case .unmetRequirement(_, let cause):
            return causeStack(cause)
        }
    }
    
    fileprivate func descr(_ cause: RuleError?, _ msg: String) -> String {
        if let causeDescr = cause?.description {
            return "\(msg)\n\(causeDescr)"
        }
        return msg
    }
    
    fileprivate func descr(_ cause: NSError?, _ msg: String) -> String {
        guard let error = cause else {
            return msg
        }
        let errorDescription = "\n\((error.userInfo["NSDebugDescription"] ?? error.description)!)"
        return "\(msg)\(errorDescription)"
    }
    
    fileprivate func causeStack(_ cause: RuleError?) -> [Error] {
        guard let stack = cause?.unwindStack() else { return [self] }
        return [self] + stack
    }
}

/**
 Base generic bender protocol for validator rule.
 */
public protocol Rule {
    associatedtype V
    func validate(_ jsonValue: AnyObject) throws -> V
    func dump(_ value: V) throws -> AnyObject
}

/**
 Base class for numeric validators
*/
public class NumberRule<T>: Rule {
    public typealias V = T
        
    public func validate(_ jsonValue: AnyObject) throws -> T {
        guard let number = jsonValue as? NSNumber else {
            throw RuleError.invalidJSONType("Value of unexpected type found: \"\(jsonValue)\". Expected \(T.self).", nil)
        }
        return try validateNumber(number)
    }
    
    public func dump(_ value: T) throws -> AnyObject {
        return try toAny(value)
    }
    
    public func validateNumber(_ number: NSNumber) throws -> T {
        throw RuleError.invalidJSONType("Value of unexpected type found: \"\(number)\". Expected \(T.self).", nil)
    }
}

/**
 Validator for signed and unsigned integer numerics
*/
public class IntegerRule<T: Integer>: NumberRule<T> {
    let i: T = 0
    
    public override init() {
    }
    
    override public func validateNumber(_ number: NSNumber) throws -> T {
        switch i {
        case is Int: return number.intValue as! T
        case is Int8: return number.int8Value as! T
        case is Int16: return number.int16Value as! T
        case is Int32: return number.int32Value as! T
        case is Int64: return number.int64Value as! T
        case is UInt: return number.uintValue as! T
        case is UInt8: return number.uint8Value as! T
        case is UInt16: return number.uint16Value as! T
        case is UInt32: return number.uint32Value as! T
        case is UInt64: return number.uint64Value as! T
            
        default: throw RuleError.invalidJSONType("Value of unexpected type found: \"\(number)\". Expected \(T.self).", nil)
        }
    }
}

/**
 Vaidator for floating point numerics
*/
public class FloatingRule<T: ExpressibleByFloatLiteral>: NumberRule<T> {
    let f: T = 0.0
    
    public override init() {
    }
    
    override public func validateNumber(_ number: NSNumber) throws -> T {
        switch f {
        case is Float: return number.floatValue as! T
        case is Double: return number.doubleValue as! T
            
        default: throw RuleError.invalidJSONType("Value of unexpected type found: \"\(number)\". Expected \(T.self).", nil)
        }
    }
}

/**
 Validator for any generic type that can be cast from NSValue automatically
*/
public class TypeRule<T>: Rule {
    public typealias V = T
    
    public init() {
    }
    
    open func validate(_ jsonValue: AnyObject) throws -> T {
        guard let value = jsonValue as? T else {
            throw RuleError.invalidJSONType("Value of unexpected type found: \"\(jsonValue)\". Expected \(T.self).", nil)
        }
        return value
    }
    
    open func dump(_ value: V) throws -> AnyObject {
        return try toAny(value)
    }
}

/// Set of predefined rules for integral types
public let IntRule = IntegerRule<Int>()
public let Int8Rule = IntegerRule<Int8>()
public let Int16Rule = IntegerRule<Int16>()
public let Int32Rule = IntegerRule<Int32>()
public let Int64Rule = IntegerRule<Int64>()
public let UIntRule = IntegerRule<UInt>()
public let UInt8Rule = IntegerRule<UInt8>()
public let UInt16Rule = IntegerRule<UInt16>()
public let UInt32Rule = IntegerRule<UInt32>()
public let UInt64Rule = IntegerRule<UInt64>()
public let DoubleRule = FloatingRule<Double>()
public let FloatRule = FloatingRule<Float>()
public let BoolRule = TypeRule<Bool>()
public let StringRule = TypeRule<String>()

/**
 Validator for compound types: classes or structs. Validates JSON struct for particular type T,
 which is passed by value of type RefT.
*/
public class CompoundRule<T, RefT>: Rule {
    public typealias V = T

    fileprivate typealias LateBindClosure = (RefT) -> Void
    fileprivate typealias RuleClosure = (AnyObject) throws -> LateBindClosure?
    fileprivate typealias OptionalRuleClosure = (AnyObject?) throws -> LateBindClosure?
    fileprivate typealias RequirementClosure = (AnyObject) throws -> Bool
    fileprivate typealias DumpRuleClosure = (T) throws -> AnyObject
    fileprivate typealias DumpOptionalRuleClosure = (T) throws -> AnyObject?
    
    fileprivate var requirements = [(JSONPath, RequirementClosure)]()
    
    fileprivate var mandatoryRules = [(JSONPath, RuleClosure)]()
    fileprivate var optionalRules = [(JSONPath, OptionalRuleClosure)]()
    
    fileprivate var mandatoryDumpRules = [(JSONPath, DumpRuleClosure)]()
    fileprivate var optionalDumpRules = [(JSONPath, DumpOptionalRuleClosure)]()
    
    fileprivate let factory: ()->RefT
    
    /**
     Validator initializer
     
     - parameter factory: autoclosure for allocating object, which returns reference to object of generic type T
     */
    public init( _ factory: @autoclosure @escaping ()->RefT) {
        self.factory = factory
    }
    
    /**
     Methoid for declaring requirement for input data, which must be met. Did not cause creation of a new bind item.
     Throws if the requirement was not met. No binding is possible while checking requirement.
     
     - parameter name:        string name if the filed which value is checked
     - parameter rule:        rule that should validate the value of the field
     - parameter requirement: closure, that receives unmutable validated field value to be checked and returns true if requiremet was met and false otherwise.
     
     - returns: returns self for field declaration chaining
     */
    open func required<R: Rule>(_ path: JSONPath, _ rule: R, requirement: @escaping (R.V)->Bool) -> Self {
        requirements.append((path,  { requirement(try rule.validate($0)) }))
        return self
    }

    /**
     Method for declaring mandatory field expected in a JSON dictionary. If the field is not found during validation,
     an error will be thrown.
     
     - parameter name: string name of the field
     - parameter rule: rule that should validate the value of the field
     - parameter bind: bind closure, that receives reference to object of generic parameter type as a first argument and validated field value as a second one
     
     - returns: returns self for field declaration chaining
     */
    open func expect<R: Rule>(_ path: JSONPath, _ rule: R, _ bind: @escaping (RefT, R.V)->Void) -> Self {
        mandatoryRules.append((path, storeRule(rule, bind)))
        return self
    }

    /**
     Method for declaring mandatory field expected in a JSON dictionary. If the field is not found during validation,
     an error will be thrown.
     
     - parameter name: string name of the field
     - parameter rule: rule that should validate the value of the field
     - parameter bind: optional bind closure, that receives reference to object of generic parameter type as a first argument and validated field value as a second one
     - parameter dump: closure used for dump, receives immutable object of type T and may return optional value of validated field type
     
     - returns: returns self for field declaration chaining
     */
    open func expect<R: Rule>(_ path: JSONPath, _ rule: R, _ bind: @escaping (RefT, R.V)->Void, dump: @escaping (T)->R.V?) -> Self {
        mandatoryRules.append((path, storeRule(rule, bind)))
        mandatoryDumpRules.append((path, storeDumpRuleForseNull(rule, dump)))
        return self
    }

    /**
     Method for declaring mandatory field expected in a JSON dictionary. If the field is not found during validation,
     an error will be thrown.
     
     - parameter name: string name of the field
     - parameter rule: rule that should validate the value of the field
     - parameter bind: optional bind closure, that receives reference to object of generic parameter type as a first argument and validated field value as a second one
     - parameter dump: closure used for dump, receives immutable object of type T and should return value of validated field type
     
     - returns: returns self for field declaration chaining
     */
    open func expect<R: Rule>(_ path: JSONPath, _ rule: R, _ bind: @escaping (RefT, R.V)->Void, dump: @escaping (T)->R.V) -> Self {
        mandatoryRules.append((path, storeRule(rule, bind)))
        mandatoryDumpRules.append((path, storeDumpRule(rule, dump)))
        return self
    }
    
    /**
     Method for declaring mandatory field expected in a JSON dictionary. If the field is not found during validation,
     an error will be thrown.
     
     - parameter name: string name of the field
     - parameter rule: rule that should validate the value of the field
     - parameter dump: closure used for dump, receives immutable object of type T and may return optional value of validated field type
     
     - returns: returns self for field declaration chaining
     */
    open func expect<R: Rule>(_ path: JSONPath, _ rule: R, dump: @escaping (T)->R.V?) -> Self {
        mandatoryDumpRules.append((path, storeDumpRuleForseNull(rule, dump)))
        return self
    }
    
    /**
     Method for declaring mandatory field expected in a JSON dictionary. If the field is not found during validation,
     an error will be thrown.
     
     - parameter name: string name of the field
     - parameter rule: rule that should validate the value of the field
     - parameter dump: closure used for dump, receives immutable object of type T and should return value of validated field type
     
     - returns: returns self for field declaration chaining
     */
    open func expect<R: Rule>(_ path: JSONPath, _ rule: R, dump: @escaping (T)->R.V) -> Self {
        mandatoryDumpRules.append((path, storeDumpRule(rule, dump)))
        return self
    }
    
    /**
     Method for declaring optional field that may be found in a JSON dictionary. If the field is not found during validation,
     nothing happens.
     
     - parameter name: string name of the field
     - parameter rule: rule that should validate the value of the field
     - parameter ifNotFound: optional value of field type, i.e. R.V. It is being returned if provided in case if the
        JSON field value is not found or is 'null'.     
     - parameter bind: optional bind closure, that receives reference to object of generic parameter type as a first argument and validated field value as a second one
     
     - returns: returns self for field declaration chaining
     */
    open func optional<R: Rule>(_ path: JSONPath, _ rule: R, ifNotFound: R.V? = nil, _ bind: @escaping (RefT, R.V)->Void) -> Self {
        optionalRules.append((path, storeOptionalRule(rule, ifNotFound, bind)))
        return self
    }

    /**
     Method for declaring optional field that may be found in a JSON dictionary. If the field is not found during validation,
     nothing happens.
     
     - parameter name: string name of the field
     - parameter rule: rule that should validate the value of the field
     - parameter ifNotFound: optional value of field type, i.e. R.V. It is being returned if provided in case if the 
        JSON field value is not found or is 'null'.
     - parameter bind: optional bind closure, that receives reference to object of generic parameter type as a first argument and validated field value as a second one
     - parameter dump: closure used for dump, receives immutable object of type T and should return value of validated field type
     
     - returns: returns self for field declaration chaining
     */
    open func optional<R: Rule>(_ path: JSONPath, _ rule: R, ifNotFound: R.V? = nil, _ bind: @escaping (RefT, R.V)->Void, dump: @escaping (T)->R.V?) -> Self {
        optionalRules.append((path, storeOptionalRule(rule, ifNotFound, bind)))
        optionalDumpRules.append((path, storeDumpRule(rule, dump)))
        return self
    }
    
    /**
     Method for declaring optional field that may be found in a JSON dictionary. If the field is not found during validation,
     nothing happens.
     
     - parameter name: string name of the field
     - parameter rule: rule that should validate the value of the field
     - parameter dump: closure used for dump, receives immutable object of type T and may return optional value of R.V field type
     
     - returns: returns self for field declaration chaining
     */
    open func optional<R: Rule>(_ path: JSONPath, _ rule: R, dump: @escaping (T)->R.V?) -> Self {
        optionalDumpRules.append((path, storeDumpRule(rule, dump)))
        return self
    }
    
    /**
     Validates JSON dictionary and returns T value if succeeded. Validation throws if jsonValue is not a JSON dictionary or if any nested rule throws. Object of type T will not be created if the validation fails.
     
     - parameter jsonValue: JSON dictionary to be validated and converted into T
     
     - throws: throws RuleError
     
     - returns: object of generic parameter argument if validation was successful
     */
    open func validate(_ jsonValue: AnyObject) throws -> T {
        guard let json = jsonValue as? [String: AnyObject] else {
            throw RuleError.invalidJSONType("Value of unexpected type found: \"\(jsonValue)\". Expected dictionary \(T.self).", nil)
        }
        
        try validateRequirements(json)
        
        let mandatoryBindings = try validateMandatoryRules(json)
        let optionalBindings = try validateOptionalRules(json)
        
        let newStruct = factory()
        
        for binding in mandatoryBindings + optionalBindings {
            binding(newStruct)
        }
        
        return value(newStruct)
    }
    
    /**
     Dumps compund object of type T to [String: AnyObject] dictionary. Throws in case if any nested rule does.
     
     - parameter value: compund value of type T
     
     - throws: throws RuleError
     
     - returns: [String: AnyObject] dictionary
     */
    open func dump(_ value: T) throws -> AnyObject {
        var dictionary = [String: AnyObject]()
        
        try dumpMandatoryRules(value, dictionary: &dictionary)
        try dumpOptionalRules(value, dictionary: &dictionary)

        return dictionary as AnyObject
    }
    
    /**
     Functions that unboxes reference to generic parameter and returns object of type T
     
     - parameter newStruct: reference to generic parameter T
     
     - returns: object of generic parameter T
     */
    func value(_ newStruct: RefT) -> T {
        return newStruct as! T
    }
    
    //MARK: - implementation
    
    fileprivate func storeRule<R: Rule>(_ rule: R, _ bind: ((RefT, R.V)->Void)? = nil) -> RuleClosure {
        return { (json) in
            let v = try rule.validate(json)
            if let b = bind {
                return { b($0, v) }
            }
            return nil
        }
    }
    
    fileprivate func storeOptionalRule<R: Rule>(_ rule: R, _ ifNotFound: R.V?, _ bind: ((RefT, R.V)->Void)?) -> OptionalRuleClosure {
        return { (optionalJson) in
            guard let json = optionalJson, !(json is NSNull) else {
                if let v = ifNotFound, let b = bind {
                    return { b($0, v) }
                }
                return nil
            }
            
            let v = try rule.validate(json)
            if let b = bind {
                return { b($0, v) }
            }
            return nil
        }
    }
    
    fileprivate func storeDumpRule<R: Rule>(_ rule: R, _ dump: @escaping (T)->R.V) -> DumpRuleClosure {
        return { struc in return try rule.dump(dump(struc)) }
    }

    fileprivate func storeDumpRuleForseNull<R: Rule>(_ rule: R, _ dump: @escaping (T)->R.V?) -> DumpRuleClosure {
        return { struc in
            if let v = dump(struc) {
                return try rule.dump(v)
            }
            return NSNull()
        }
    }
    
    fileprivate func storeDumpRule<R: Rule>(_ rule: R, _ dump: @escaping (T)->R.V?) -> DumpOptionalRuleClosure {
        return { struc in
            if let v = dump(struc) {
                return try rule.dump(v)
            }
            return nil
        }
    }
    
    fileprivate func validateRequirements(_ json:[String: AnyObject]) throws {
        for (path, rule) in requirements {
            guard let value = objectIn(json as AnyObject, atPath: path) else {
                throw RuleError.expectedNotFound("Unable to check the requirement, field \"\(path)\" not found in struct.", nil)
            }
            
            do {
                if !(try rule(value)) {
                    throw RuleError.unmetRequirement("Requirement was not met for field \"\(path)\" with value \"\(value)\"", nil)
                }
            } catch let err as RuleError {
                switch err {
                case .unmetRequirement: throw err
                default:
                    throw RuleError.unmetRequirement("Requirement was not met for field \"\(path)\" with value \"\(value)\"", err)
                }
            }
        }
    }
    
    fileprivate func validateMandatoryRules(_ json: [String: AnyObject]) throws -> [LateBindClosure] {
        var bindings = [LateBindClosure]()
        for (path, rule) in mandatoryRules {
            guard let value = objectIn(json as AnyObject, atPath: path) else {
                throw RuleError.expectedNotFound("Unable to validate \"\(json)\" as \(T.self). Mandatory field \"\(path)\" not found in struct.", nil)
            }
            
            do {
                if let binding = try rule(value) { bindings.append(binding) }
            } catch let err as RuleError {
                throw RuleError.invalidJSONType("Unable to validate mandatory field \"\(path)\" for \(T.self).", err)
            }
        }
        return bindings
    }
    
    fileprivate func validateOptionalRules(_ json: [String: AnyObject]) throws -> [LateBindClosure] {
        var bindings = [LateBindClosure]()
        for (path, rule) in optionalRules {
            let value = objectIn(json as AnyObject, atPath: path)
            do {
                if let binding = try rule(value) { bindings.append(binding) }
            } catch let err as RuleError {
                throw RuleError.invalidJSONType("Unable to validate optional field \"\(path)\" for \(T.self).", err)
            }
        }
        return bindings
    }
    
    fileprivate func dumpMandatoryRules(_ value: T, dictionary: inout [String: AnyObject]) throws {
        for (path, rule) in mandatoryDumpRules {
            do {
                dictionary = try setInDictionary(dictionary, object: try rule(value), atPath: path)
            } catch let err as RuleError {
                throw RuleError.invalidDump("Unable to dump mandatory field \(path) for \(T.self).", err)
            }
        }
    }
    
    fileprivate func dumpOptionalRules(_ value: T, dictionary: inout [String: AnyObject]) throws {
        for (path, rule) in optionalDumpRules {
            do {
                if let v = try rule(value) {
                    dictionary = try setInDictionary(dictionary, object: v, atPath: path)
                }
            } catch let err as RuleError {
                throw RuleError.invalidDump("Unable to dump optional field \(path) for \(T.self).", err)
            }
        }
    }
}

/**
 Validator of compound JSON object with binding to reference type like class T. Reference type is T itself.
*/
public class ClassRule<T>: CompoundRule<T, T> {
    
    public override init( _ factory: @autoclosure @escaping ()->T) {
        super.init(factory)
    }
    
    open override func value(_ newStruct: T) -> T {
        return newStruct
    }
}

/**
 Validator of compound JSON object with binding to value type like struct T. Reference type is ref<T>.
*/
public class StructRule<T>: CompoundRule<T, ref<T>> {

    public override init( _ factory: @autoclosure @escaping ()->ref<T>) {
        super.init(factory)
    }
    
    open override func value(_ newStruct: ref<T>) -> T {
        return newStruct.value
    }
}

/**
 Validator for arrays of items of type T, that should be validated by rule of type R, i.e. where R.V == T.
*/
public class ArrayRule<T, R: Rule>: Rule where R.V == T {
    public typealias V = [T]

    typealias ValidateClosure = (AnyObject) throws -> T
    public typealias InvalidItemHandler = (Error) throws -> Void
    
    fileprivate var itemRule: R
    fileprivate var invalidItemHandler: InvalidItemHandler = { throw $0 }
    
     /**
     Validator initializer
     
     - parameter itemRule: rule for validating array items of type R.V
     - parameter invalidItemHandler: handler closure which is called when the item cannnot be validated.
        Can throw is there is no need to keep checking.
     */
    public init(itemRule: R, invalidItemHandler: InvalidItemHandler? = nil) {
        self.itemRule = itemRule
        if let handler = invalidItemHandler {
            self.invalidItemHandler = handler
        }
    }
    
    /**
     Validates JSON array and returns [T] if succeeded. Validation throws if jsonValue is not a JSON array or if item rule throws for any item.
     
     - parameter jsonValue: JSON array to be validated and converted into [T]
     
     - throws: throws ValidateError
     
     - returns: array of objects of first generic parameter argument if validation was successful
     */
    open func validate(_ jsonValue: AnyObject) throws -> V {
        guard let json = jsonValue as? [AnyObject] else {
            throw RuleError.invalidJSONType("Value of unexpected type found: \"\(jsonValue)\". Expected array of \(T.self).", nil)
        }
        
        var newArray = [T]()
        var index: Int = 0
  
        do {
            for (i, object) in json.enumerated() {
                do {
                    newArray.append(try itemRule.validate(object))
                } catch let handlerError {
                    index = i
                    try invalidItemHandler(handlerError)
                }
            }
        } catch let err as RuleError {
            throw RuleError.invalidJSONType("Unable to validate array of \(T.self): item #\(index) could not be validated.", err)
        }
    
        return newArray
    }
    
    /**
     Dumps array of AnyObject type in case of success. Throws if cannot dump any item in source array.
     
     - parameter value: array with items of type T
     
     - throws: throws RuleError if cannot dump any item in source array
     
     - returns: returns array of AnyObject, dumped by item rule
     */
    open func dump(_ value: V) throws -> AnyObject {
        var array = [AnyObject]()
        for (index, t) in value.enumerated() {
            do {
                array.append(try itemRule.dump(t))
            } catch let err as RuleError {
                throw RuleError.invalidDump("Unable to dump array of \(T.self): item #\(index) could not be dumped.", err)
            }
        }
        return array as AnyObject
    }
}

/**
 Validator for enum of type T. Checks that JSON value to be validated is equal to any option stored and .
 If all stored properties do not match, throws ValidateError.
*/
public class EnumRule<T: Equatable>: Rule {
    public typealias V = T
    
    fileprivate var cases: [(AnyObject) throws -> T?] = []
    fileprivate var reverseCases: [(T) throws -> AnyObject?] = []
    fileprivate var byDefault: V?
    
    /**
     Initializer for EnumRule.
     
     - parameter byDefault: optional parameter of type V, which is being returned if provided, 
        in case if no matches found during validation in options list for the particular JSON value.
        Do not pass it to the 'dump', it will throw.
     */
    public init(ifNotFound byDefault: V? = nil) {
        self.byDefault = byDefault
    }
    
    /**
     Method for declaring matching between given value and enum case of type T. 
     JSON value should be comparable with the value, i.e. should cast to S which is Equatable.
     
     - parameter value:     constant of type S which is corresponding to enumValue
     - parameter enumValue: enum value of type T
     
     - returns: self for options declaration chaining
     */
    open func option<S: Equatable>(_ value: S, _ enumValue: T) -> Self {
        cases.append({ jsonValue in
            guard let json = jsonValue as? S, json == value else {
                return nil
            }
            return enumValue
        })
        
        reverseCases.append({ ev in
            if enumValue == ev  {
                return try toAny(value)
            }
            return nil
        })
        return self
    }
    
    /**
     Compares all stored option constants with given JSON value. If one of them matches, returns corresponding enum case. Throws otherwise.
     
     - parameter jsonValue: JSON value that can be compared with the stored value of type S
     
     - throws: throws ValidateError
     
     - returns: returns enum case of type T if matching value found, throws otherwise
     */
    open func validate(_ jsonValue: AnyObject) throws -> V {
        for theCase in cases {
            if let value = try theCase(jsonValue) {
                return value
            }
        }
        
        if let byDefault = self.byDefault {
            return byDefault
        }
        
        throw RuleError.expectedNotFound("Unable to validate enum \(T.self). Unexpected enum case found: \"\(jsonValue)\".", nil)
    }
    
    /**
     Dumps AnyObject which is related to the value provided, throws in case if it is unable to convert the value.
     
     - parameter value: enum value provided
     
     - throws: RuleError in case if it is impossible to covert the value
     
     - returns: AnyObject to which the enum value has been encoded
     */
    open func dump(_ value: V) throws -> AnyObject {
        for theCase in reverseCases {
            do {
                if let v = try theCase(value) {
                    return v
                }
            } catch let err as RuleError {
                throw RuleError.invalidDump("Unable to dump enum \(T.self).", err)
            }
        }
        
        throw RuleError.expectedNotFound("Unable to dump enum \(T.self). Unexpected enum case given: \"\(value)\".", nil)
    }
}

/**
 Validator of JSON encoded into string like this: "\"field": \"value\"". Encoded JSON should be validated by given rule of type R.
*/
public class StringifiedJSONRule<R: Rule>: Rule {
    public typealias V = R.V
    
    fileprivate let nestedRule: R
    
    /**
     Validator initializer
     
     - parameter nestedRule: rule to validate JSON decoded from string
     */
    public init(nestedRule: R) {
        self.nestedRule = nestedRule
    }
    
    /**
     Checks if string contains JSON. Calls nested rule validator if succeeded. Throws ValidateError otherwise.
     
     - parameter jsonValue: string containing encoded JSON
     
     - throws: throws ValidateError
     
     - returns: returns object of nested rule struct type (i.e. R.V), if validated. Throws otherwise.
     */
    open func validate(_ jsonValue: AnyObject) throws -> V {
        guard let jsonString = jsonValue as? String, let data = jsonString.data(using: String.Encoding.utf8) else {
            throw RuleError.invalidJSONType("Value of unexpected type found: \"\(jsonValue)\". Expected stringified JSON.", nil)
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            return try nestedRule.validate(json as AnyObject)
        } catch let error as NSError {
            throw RuleError.invalidJSONSerialization("Unable to parse stringified JSON: \(jsonString).", error)
        }
    }
    
    /**
     Dumps string with JSON encoded in UTF-8 in case of success. Throws if cannot dump nested rule.
     
     - parameter value: value of type R.V, i.e. nested rule type
     
     - throws: RuleError if cannot dump nested rule
     
     - returns: string with JSON encoded in UTF-8
     */
    open func dump(_ value: V) throws -> AnyObject {
        do {
            let json = try nestedRule.dump(value)
            let data = try JSONSerialization.data(withJSONObject: json, options: JSONSerialization.WritingOptions(rawValue: 0))
            guard let string = String(data: data, encoding: String.Encoding.utf8) else {
                throw RuleError.invalidDump("Unable to dump stringified JSON: \(json). Could not convert JSON to string.", nil)
            }
            return string as AnyObject
        } catch let error as NSError {
            let cause = RuleError.invalidJSONSerialization("Could not convert object to JSON: \(value).", error)
            throw RuleError.invalidDump("Unable to dump stringified JSON.", cause)
        } catch let error as RuleError {
            throw RuleError.invalidDump("Unable to dump stringified JSON for object: \(value)", error)
        }
    }
}

public struct JSONPath: ExpressibleByStringLiteral, ExpressibleByArrayLiteral, CustomStringConvertible {
    
    public enum PathElement: CustomStringConvertible {
        case DictionaryKey(String)
        case ArrayIndex(Int)
        
        public var description: String {
            switch self {
            case .DictionaryKey(let value): return value
            case .ArrayIndex(let value): return "\(value)"
            }
        }
    }
    
    public let elements: [PathElement]
    
    public init(_ value: [PathElement]) {
        elements = value
    }
    
    public init(unicodeScalarLiteral value: String) {
        elements = [PathElement.DictionaryKey(value)]
    }
    
    public init(extendedGraphemeClusterLiteral value: String) {
        elements = [PathElement.DictionaryKey(value)]
    }
    
    public init(stringLiteral value: String) {
        elements = [PathElement.DictionaryKey(value)]
    }
    
    public init(arrayLiteral elements: String...) {
        self.elements = elements.map({ PathElement.DictionaryKey($0) })
    }
    
    public init(_ elements: [String]) {
        self.elements = elements.map({ PathElement.DictionaryKey($0) })
    }
    
    public var description: String {
        return elements.map({ "\($0)" }).joined(separator: "/")
    }
    
    public func tail() -> JSONPath {
        return JSONPath(Array(elements[1..<elements.count]))
    }
}

func objectIn(_ object: AnyObject, atPath path: JSONPath) -> AnyObject? {
    var currentObject: AnyObject? = object
    for pathItem in path.elements {
        if let currentDict = currentObject as? [String: AnyObject], case .DictionaryKey(let item) = pathItem, let next = currentDict[item], !(next is NSNull) {
            currentObject = next
            continue
        }
        if let currentArray = currentObject as? [AnyObject], case .ArrayIndex(let index) = pathItem, currentArray.count > index && !(currentArray[index] is NSNull) {
            currentObject = currentArray[index]
            continue
        }
        currentObject = nil
    }
    return currentObject
}

func setInDictionary(_ dictionary: [String: AnyObject], object: AnyObject?, atPath path: JSONPath) throws -> [String: AnyObject] {
    guard let first = path.elements.first else {
        throw RuleError.invalidDump("Unexpectedly count of path elements is 0", nil)
    }
    guard case .DictionaryKey(let pathElement) = first else {
        throw RuleError.invalidDump("Dump of array is not implemented. Element \"\(first)\" is not a dictionary.", nil)
    }

    var traverseDictionary = dictionary
    if path.elements.count == 1 {
        traverseDictionary[pathElement] = object
        return traverseDictionary
    }
    
    if let nestedObject = traverseDictionary[pathElement] {
        guard let existingDictionary = nestedObject as? [String: AnyObject] else {
            throw RuleError.invalidDump("\"\(pathElement)\" is not a dictionary.", nil)
        }
        traverseDictionary[pathElement] = try setInDictionary(existingDictionary, object: object, atPath: path.tail()) as AnyObject?
        return traverseDictionary
    }
    
    traverseDictionary[pathElement] = try setInDictionary([:], object: object, atPath: path.tail()) as AnyObject?
    return traverseDictionary
}

/**
 Generic class for boxing value type.
*/
public class ref<T> {
    open var value: T
    
    public init(_ value: T) {
        self.value = value
    }
}

/**
 Helper generic function for converting integral values of type T to AnyObject.
 
 - parameter t: value of type T to be converted
 
 - throws: throws RuleError if type of the value cannot be converted to AnyObject
 
 - returns: returns AnyObject with boxed t value inside
 */
func toAny<T>(_ t: T) throws -> AnyObject {
    switch t {
    case let v as Int: return NSNumber(value: v)
    case let v as Int8: return NSNumber(value: v)
    case let v as Int16: return NSNumber(value: v)
    case let v as Int32: return NSNumber(value: v)
    case let v as Int64: return NSNumber(value: v)
    case let v as UInt: return NSNumber(value: v)
    case let v as UInt8: return NSNumber(value: v)
    case let v as UInt16: return NSNumber(value: v)
    case let v as UInt32: return NSNumber(value: v)
    case let v as UInt64: return NSNumber(value: v)
    case let v as Bool: return NSNumber(value: v)
    case let v as Float: return NSNumber(value: v)
    case let v as Double: return NSNumber(value: v)
    case let v as String: return v as NSString
    default:
        throw RuleError.invalidDump("Unable to dump value of unknown type: \(t)", nil)
    }
}

// MARK: - Helpers

public extension Rule {
    public func validateData(_ jsonData: Data?) throws -> V {
        do {
            guard let data = jsonData else {
                throw RuleError.expectedNotFound("Unable to get JSON object: no data found.", nil)
            }
            return try validate(try JSONSerialization.jsonObject(with: data, options: []) as AnyObject)
        } catch let error as RuleError {
            throw RuleError.invalidJSONType("Unable to get JSON from data given.", error)
        } catch let error {
            throw RuleError.invalidJSONType("Unable to get JSON from data given. \(error)", nil)
        }
    }
    
    public func dumpData(_ value: V) throws -> Data {
        do {
            return try JSONSerialization.data(withJSONObject: try dump(value), options: JSONSerialization.WritingOptions(rawValue: 0))
        } catch let error as RuleError {
            throw RuleError.invalidDump("Unable to dump value \(value) to JSON data.", error)
        } catch let error {
            throw RuleError.invalidDump("Unable to dump value \(value) to JSON data. \(error)", nil)
        }
    }
}

/**
 Operator constructing JSONPath
 
 - parameter path:  JSONPath object or string literal for conversion initializer
 - parameter right: string literal to be added to the path
 
 - returns: newly created JSONPath with 'right' appended to it
 */
public func /(path: JSONPath, right: String) -> JSONPath {
    return JSONPath(path.elements + [.DictionaryKey(right)])
}

public func /(path: JSONPath, right: UInt) -> JSONPath {
    return JSONPath(path.elements + [.ArrayIndex(Int(right))])
}

public func /(path: JSONPath, right: JSONPath) -> JSONPath {
    return JSONPath(path.elements + right.elements)
}
