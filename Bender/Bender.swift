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

/**
 Bender throwing error type
 
 - InvalidJSONType:   basic bender error, contains string and optional ValidateError cause
 - ExpectedNotFound:  throws if expected was not found, contains string and optional ValidateError cause
 - JSONSerialization: throws if JSON parser fails, contains string and optional ValidateError cause
 */
public indirect enum RuleError: ErrorType, CustomStringConvertible {
    case InvalidJSONType(String, RuleError?)
    case ExpectedNotFound(String, RuleError?)
    case InvalidJSONSerialization(String, NSError)
    case InvalidDump(String, RuleError?)
    case UnmetRequirement(String, RuleError?)
    
    public var description: String {
        switch self {
        case InvalidJSONType(let str, let cause):
            return descr(cause, str)
        case .ExpectedNotFound(let str, let cause):
            return descr(cause, str)
        case .InvalidJSONSerialization(let str, let err):
            return descr(err, str)
        case .InvalidDump(let str, let cause):
            return descr(cause, str)
        case .UnmetRequirement(let str, let cause):
            return descr(cause, str)
        }
    }
    
    public func unwindStack() -> [ErrorType] {
        switch self {
        case InvalidJSONType(_, let cause):
            return causeStack(cause)
        case .ExpectedNotFound(_, let cause):
            return causeStack(cause)
        case .InvalidJSONSerialization:
            return [self]
        case .InvalidDump(_, let cause):
            return causeStack(cause)
        case .UnmetRequirement(_, let cause):
            return causeStack(cause)
        }
    }
    
    private func descr(cause: RuleError?, _ msg: String) -> String {
        if let causeDescr = cause?.description {
            return "\(msg)\n\(causeDescr)"
        }
        return msg
    }
    
    private func descr(cause: NSError?, _ msg: String) -> String {
        guard let error = cause else {
            return msg
        }
        let errorDescription = "\n\((error.userInfo["NSDebugDescription"] ?? error.description)!)"
        return "\(msg)\(errorDescription)"
    }
    
    private func causeStack(cause: RuleError?) -> [ErrorType] {
        guard let stack = cause?.unwindStack() else { return [self] }
        return [self] + stack
    }
}

/**
 Base generic bender protocol for validator rule.
 */
public protocol Rule {
    typealias V
    func validate(jsonValue: AnyObject) throws -> V
    func dump(value: V) throws -> AnyObject
}

/**
 Base class for numeric validators
*/
internal class NumberRule<T>: Rule {
    typealias V = T
        
    func validate(jsonValue: AnyObject) throws -> T {
        guard let number = jsonValue as? NSNumber else {
            throw RuleError.InvalidJSONType("Value of unexpected type found: \"\(jsonValue)\". Expected \(T.self).", nil)
        }
        return try validateNumber(number)
    }
    
    func dump(value: T) throws -> AnyObject {
        return try toAny(value)
    }
    
    func validateNumber(number: NSNumber) throws -> T {
        throw RuleError.InvalidJSONType("Value of unexpected type found: \"\(number)\". Expected \(T.self).", nil)
    }
}

/**
 Validator for signed and unsigned integer numerics
*/
public class IntegerRule<T: protocol<IntegerType>>: NumberRule<T> {
    let i: T = 0
    
    public override init() {
    }
    
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
            
        default: throw RuleError.InvalidJSONType("Value of unexpected type found: \"\(number)\". Expected \(T.self).", nil)
        }
    }
}

/**
 Vaidator for floating point numerics
*/
public class FloatingRule<T: protocol<FloatLiteralConvertible>>: NumberRule<T> {
    let f: T = 0.0
    
    public override init() {
    }
    
    override func validateNumber(number: NSNumber) throws -> T {
        switch f {
        case is Float: return number.floatValue as! T
        case is Double: return number.doubleValue as! T
            
        default: throw RuleError.InvalidJSONType("Value of unexpected type found: \"\(number)\". Expected \(T.self).", nil)
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
    
    public func validate(jsonValue: AnyObject) throws -> T {
        guard let value = jsonValue as? T else {
            throw RuleError.InvalidJSONType("Value of unexpected type found: \"\(jsonValue)\". Expected \(T.self).", nil)
        }
        return value
    }
    
    public func dump(value: V) throws -> AnyObject {
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

    private typealias LateBindClosure = (RefT) -> Void
    private typealias RuleClosure = (AnyObject) throws -> LateBindClosure?
    private typealias OptionalRuleClosure = (AnyObject?) throws -> LateBindClosure?
    private typealias RequirementClosure = (AnyObject) throws -> Bool
    private typealias DumpRuleClosure = (T) throws -> AnyObject
    private typealias DumpOptionalRuleClosure = (T) throws -> AnyObject?
    
    private var requirements = [(JSONPath, RequirementClosure)]()
    
    private var mandatoryRules = [(JSONPath, RuleClosure)]()
    private var optionalRules = [(JSONPath, OptionalRuleClosure)]()
    
    private var mandatoryDumpRules = [(JSONPath, DumpRuleClosure)]()
    private var optionalDumpRules = [(JSONPath, DumpOptionalRuleClosure)]()
    
    private let factory: ()->RefT
    
    /**
     Validator initializer
     
     - parameter factory: autoclosure for allocating object, which returns reference to object of generic type T
     */
    public init(@autoclosure(escaping) _ factory: ()->RefT) {
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
    public func required<R: Rule>(path: JSONPath, _ rule: R, requirement: (R.V)->Bool) -> Self {
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
    public func expect<R: Rule>(path: JSONPath, _ rule: R, _ bind: (RefT, R.V)->Void) -> Self {
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
    public func expect<R: Rule>(path: JSONPath, _ rule: R, _ bind: (RefT, R.V)->Void, dump: (T)->R.V?) -> Self {
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
    public func expect<R: Rule>(path: JSONPath, _ rule: R, _ bind: (RefT, R.V)->Void, dump: (T)->R.V) -> Self {
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
    public func expect<R: Rule>(path: JSONPath, _ rule: R, dump: (T)->R.V?) -> Self {
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
    public func expect<R: Rule>(path: JSONPath, _ rule: R, dump: (T)->R.V) -> Self {
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
    public func optional<R: Rule>(path: JSONPath, _ rule: R, ifNotFound: R.V? = nil, _ bind: (RefT, R.V)->Void) -> Self {
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
    public func optional<R: Rule>(path: JSONPath, _ rule: R, ifNotFound: R.V? = nil, _ bind: (RefT, R.V)->Void, dump: (T)->R.V?) -> Self {
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
    public func optional<R: Rule>(path: JSONPath, _ rule: R, dump: (T)->R.V?) -> Self {
        optionalDumpRules.append((path, storeDumpRule(rule, dump)))
        return self
    }
    
    /**
     Validates JSON dictionary and returns T value if succeeded. Validation throws if jsonValue is not a JSON dictionary or if any nested rule throws. Object of type T will not be created if the validation fails.
     
     - parameter jsonValue: JSON dictionary to be validated and converted into T
     
     - throws: throws RuleError
     
     - returns: object of generic parameter argument if validation was successful
     */
    public func validate(jsonValue: AnyObject) throws -> T {
        guard let json = jsonValue as? [String: AnyObject] else {
            throw RuleError.InvalidJSONType("Value of unexpected type found: \"\(jsonValue)\". Expected dictionary \(T.self).", nil)
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
    public func dump(value: T) throws -> AnyObject {
        var dictionary = [String: AnyObject]()
        
        try dumpMandatoryRules(value, dictionary: &dictionary)
        try dumpOptionalRules(value, dictionary: &dictionary)

        return dictionary
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
    
    private func storeRule<R: Rule>(rule: R, _ bind: ((RefT, R.V)->Void)? = nil) -> RuleClosure {
        return { (json) in
            let v = try rule.validate(json)
            if let b = bind {
                return { b($0, v) }
            }
            return nil
        }
    }
    
    private func storeOptionalRule<R: Rule>(rule: R, _ ifNotFound: R.V?, _ bind: ((RefT, R.V)->Void)?) -> OptionalRuleClosure {
        return { (optionalJson) in
            guard let json = optionalJson where !(json is NSNull) else {
                if let v = ifNotFound, b = bind {
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
    
    private func storeDumpRule<R: Rule>(rule: R, _ dump: (T)->R.V) -> DumpRuleClosure {
        return { struc in return try rule.dump(dump(struc)) }
    }

    private func storeDumpRuleForseNull<R: Rule>(rule: R, _ dump: (T)->R.V?) -> DumpRuleClosure {
        return { struc in
            if let v = dump(struc) {
                return try rule.dump(v)
            }
            return NSNull()
        }
    }
    
    private func storeDumpRule<R: Rule>(rule: R, _ dump: (T)->R.V?) -> DumpOptionalRuleClosure {
        return { struc in
            if let v = dump(struc) {
                return try rule.dump(v)
            }
            return nil
        }
    }
    
    private func validateRequirements(json:[String: AnyObject]) throws {
        for (path, rule) in requirements {
            guard let value = objectIn(json, atPath: path) else {
                throw RuleError.ExpectedNotFound("Unable to check the requirement, field \"\(path)\" not found in struct.", nil)
            }
            
            do {
                if !(try rule(value)) {
                    throw RuleError.UnmetRequirement("Requirement was not met for field \"\(path)\" with value \"\(value)\"", nil)
                }
            } catch let err as RuleError {
                switch err {
                case .UnmetRequirement: throw err
                default:
                    throw RuleError.UnmetRequirement("Requirement was not met for field \"\(path)\" with value \"\(value)\"", err)
                }
            }
        }
    }
    
    private func validateMandatoryRules(json: [String: AnyObject]) throws -> [LateBindClosure] {
        var bindings = [LateBindClosure]()
        for (path, rule) in mandatoryRules {
            guard let value = objectIn(json, atPath: path) else {
                throw RuleError.ExpectedNotFound("Unable to validate \"\(json)\" as \(T.self). Mandatory field \"\(path)\" not found in struct.", nil)
            }
            
            do {
                if let binding = try rule(value) { bindings.append(binding) }
            } catch let err as RuleError {
                throw RuleError.InvalidJSONType("Unable to validate mandatory field \"\(path)\" for \(T.self).", err)
            }
        }
        return bindings
    }
    
    private func validateOptionalRules(json: [String: AnyObject]) throws -> [LateBindClosure] {
        var bindings = [LateBindClosure]()
        for (path, rule) in optionalRules {
            let value = objectIn(json, atPath: path)
            do {
                if let binding = try rule(value) { bindings.append(binding) }
            } catch let err as RuleError {
                throw RuleError.InvalidJSONType("Unable to validate optional field \"\(path)\" for \(T.self).", err)
            }
        }
        return bindings
    }
    
    private func dumpMandatoryRules(value: T, inout dictionary: [String: AnyObject]) throws {
        for (path, rule) in mandatoryDumpRules {
            do {
                dictionary = try setInDictionary(dictionary, object: try rule(value), atPath: path)
            } catch let err as RuleError {
                throw RuleError.InvalidDump("Unable to dump mandatory field \(path) for \(T.self).", err)
            }
        }
    }
    
    private func dumpOptionalRules(value: T, inout dictionary: [String: AnyObject]) throws {
        for (path, rule) in optionalDumpRules {
            do {
                if let v = try rule(value) {
                    dictionary = try setInDictionary(dictionary, object: v, atPath: path)
                }
            } catch let err as RuleError {
                throw RuleError.InvalidDump("Unable to dump optional field \(path) for \(T.self).", err)
            }
        }
    }
}

/**
 Validator of compound JSON object with binding to reference type like class T. Reference type is T itself.
*/
public class ClassRule<T>: CompoundRule<T, T> {
    
    public override init(@autoclosure(escaping) _ factory: ()->T) {
        super.init(factory)
    }
    
    public override func value(newStruct: T) -> T {
        return newStruct
    }
}

/**
 Validator of compound JSON object with binding to value type like struct T. Reference type is ref<T>.
*/
public class StructRule<T>: CompoundRule<T, ref<T>> {

    public override init(@autoclosure(escaping) _ factory: ()->ref<T>) {
        super.init(factory)
    }
    
    public override func value(newStruct: ref<T>) -> T {
        return newStruct.value
    }
}

/**
 Validator for arrays of items of type T, that should be validated by rule of type R, i.e. where R.V == T.
*/
public class ArrayRule<T, R: Rule where R.V == T>: Rule {
    public typealias V = [T]

    typealias ValidateClosure = (AnyObject) throws -> T
    public typealias InvalidItemHandler = (ErrorType) throws -> Void
    
    private var itemRule: R
    private var invalidItemHandler: InvalidItemHandler = { throw $0 }
    
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
    public func validate(jsonValue: AnyObject) throws -> V {
        guard let json = jsonValue as? [AnyObject] else {
            throw RuleError.InvalidJSONType("Value of unexpected type found: \"\(jsonValue)\". Expected array of \(T.self).", nil)
        }
        
        var newArray = [T]()
        var index: Int = 0
  
        do {
            for (i, object) in json.enumerate() {
                do {
                    newArray.append(try itemRule.validate(object))
                } catch let handlerError {
                    index = i
                    try invalidItemHandler(handlerError)
                }
            }
        } catch let err as RuleError {
            throw RuleError.InvalidJSONType("Unable to validate array of \(T.self): item #\(index) could not be validated.", err)
        }
    
        return newArray
    }
    
    /**
     Dumps array of AnyObject type in case of success. Throws if cannot dump any item in source array.
     
     - parameter value: array with items of type T
     
     - throws: throws RuleError if cannot dump any item in source array
     
     - returns: returns array of AnyObject, dumped by item rule
     */
    public func dump(value: V) throws -> AnyObject {
        var array = [AnyObject]()
        for (index, t) in value.enumerate() {
            do {
                array.append(try itemRule.dump(t))
            } catch let err as RuleError {
                throw RuleError.InvalidDump("Unable to dump array of \(T.self): item #\(index) could not be dumped.", err)
            }
        }
        return array
    }
}

/**
 Validator for enum of type T. Checks that JSON value to be validated is equal to any option stored and .
 If all stored properties do not match, throws ValidateError.
*/
public class EnumRule<T: Equatable>: Rule {
    public typealias V = T
    
    private var cases: [(AnyObject) throws -> T?] = []
    private var reverseCases: [(T) throws -> AnyObject?] = []
    private var byDefault: V?
    
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
    public func option<S: Equatable>(value: S, _ enumValue: T) -> Self {
        cases.append({ jsonValue in
            guard let json = jsonValue as? S where json == value else {
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
    public func validate(jsonValue: AnyObject) throws -> V {
        for theCase in cases {
            if let value = try theCase(jsonValue) {
                return value
            }
        }
        
        if let byDefault = self.byDefault {
            return byDefault
        }
        
        throw RuleError.ExpectedNotFound("Unable to validate enum \(T.self). Unexpected enum case found: \"\(jsonValue)\".", nil)
    }
    
    /**
     Dumps AnyObject which is related to the value provided, throws in case if it is unable to convert the value.
     
     - parameter value: enum value provided
     
     - throws: RuleError in case if it is impossible to covert the value
     
     - returns: AnyObject to which the enum value has been encoded
     */
    public func dump(value: V) throws -> AnyObject {
        for theCase in reverseCases {
            do {
                if let v = try theCase(value) {
                    return v
                }
            } catch let err as RuleError {
                throw RuleError.InvalidDump("Unable to dump enum \(T.self).", err)
            }
        }
        
        throw RuleError.ExpectedNotFound("Unable to dump enum \(T.self). Unexpected enum case given: \"\(value)\".", nil)
    }
}

/**
 Validator of JSON encoded into string like this: "\"field": \"value\"". Encoded JSON should be validated by given rule of type R.
*/
public class StringifiedJSONRule<R: Rule>: Rule {
    public typealias V = R.V
    
    private let nestedRule: R
    
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
    public func validate(jsonValue: AnyObject) throws -> V {
        guard let jsonString = jsonValue as? String, let data = jsonString.dataUsingEncoding(NSUTF8StringEncoding) else {
            throw RuleError.InvalidJSONType("Value of unexpected type found: \"\(jsonValue)\". Expected stringified JSON.", nil)
        }
        
        do {
            let json = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            return try nestedRule.validate(json)
        } catch let error as NSError {
            throw RuleError.InvalidJSONSerialization("Unable to parse stringified JSON: \(jsonString).", error)
        }
    }
    
    /**
     Dumps string with JSON encoded in UTF-8 in case of success. Throws if cannot dump nested rule.
     
     - parameter value: value of type R.V, i.e. nested rule type
     
     - throws: RuleError if cannot dump nested rule
     
     - returns: string with JSON encoded in UTF-8
     */
    public func dump(value: V) throws -> AnyObject {
        do {
            let json = try nestedRule.dump(value)
            let data = try NSJSONSerialization.dataWithJSONObject(json, options: NSJSONWritingOptions(rawValue: 0))
            guard let string = String(data: data, encoding: NSUTF8StringEncoding) else {
                throw RuleError.InvalidDump("Unable to dump stringified JSON: \(json). Could not convert JSON to string.", nil)
            }
            return string
        } catch let error as NSError {
            let cause = RuleError.InvalidJSONSerialization("Could not convert object to JSON: \(value).", error)
            throw RuleError.InvalidDump("Unable to dump stringified JSON.", cause)
        } catch let error as RuleError {
            throw RuleError.InvalidDump("Unable to dump stringified JSON for object: \(value)", error)
        }
    }
}

public struct JSONPath: StringLiteralConvertible, ArrayLiteralConvertible, CustomStringConvertible {
    
    public let elements: [String]
    
    public init(unicodeScalarLiteral value: String) {
        elements = [value]
    }
    
    public init(extendedGraphemeClusterLiteral value: String) {
        elements = [value]
    }
    
    public init(stringLiteral value: String) {
        elements = [value]
    }
    
    public init(arrayLiteral elements: String...) {
        self.elements = elements
    }
    
    public init(_ elements: [String]) {
        self.elements = elements
    }
    
    public var description: String {
        var str = elements.first ?? ""
        for index in 1..<elements.count {
            str += "/\(elements[index])"
        }
        return str
    }
    
    public func tail() -> JSONPath {
        return JSONPath(Array(elements[1..<elements.count]))
    }
}

func objectIn(object: AnyObject, atPath path: JSONPath) -> AnyObject? {
    var currentObject: AnyObject? = object
    for pathItem in path.elements {
        guard let currentDict = currentObject as? [String: AnyObject] else {
            return nil
        }
        if let next = currentDict[pathItem] where !(next is NSNull) {
            currentObject = next
            continue
        }
        currentObject = nil
    }
    return currentObject
}

func setInDictionary(var dictionary: [String: AnyObject], object: AnyObject?, atPath path: JSONPath) throws -> [String: AnyObject] {
    if path.elements.count == 1 {
        dictionary[path.elements.last!] = object
        return dictionary
    }
    
    let pathElement = path.elements.first!
    if let nestedObject = dictionary[pathElement] {
        guard let existingDictionary = nestedObject as? [String: AnyObject] else {
            throw RuleError.InvalidDump("\"\(pathElement)\" is not a dictionary.", nil)
        }
        dictionary[pathElement] = try setInDictionary(existingDictionary, object: object, atPath: path.tail())
        return dictionary
    }
    
    dictionary[pathElement] = try setInDictionary([:], object: object, atPath: path.tail())
    return dictionary
}

/**
 Generic class for boxing value type.
*/
public class ref<T> {
    public var value: T
    
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
func toAny<T>(t: T) throws -> AnyObject {
    switch t {
    case let v as Int: return NSNumber(integer: v)
    case let v as Int8: return NSNumber(char: v)
    case let v as Int16: return NSNumber(short: v)
    case let v as Int32: return NSNumber(int: v)
    case let v as Int64: return NSNumber(longLong: v)
    case let v as UInt: return NSNumber(unsignedInteger: v)
    case let v as UInt8: return NSNumber(unsignedChar: v)
    case let v as UInt16: return NSNumber(unsignedShort: v)
    case let v as UInt32: return NSNumber(unsignedInt: v)
    case let v as UInt64: return NSNumber(unsignedLongLong: v)
    case let v as Bool: return NSNumber(bool: v)
    case let v as Float: return NSNumber(float: v)
    case let v as Double: return NSNumber(double: v)
    case let v as String: return v
    default:
        throw RuleError.InvalidDump("Unable to dump value of unknown type: \(t)", nil)
    }
}

// MARK: - Helpers

public extension Rule {
    public func validateData(jsonData: NSData?) throws -> V {
        do {
            guard let data = jsonData else {
                throw RuleError.ExpectedNotFound("Unable to get JSON object: no data found.", nil)
            }
            return try validate(try NSJSONSerialization.JSONObjectWithData(data, options: []))
        } catch let error as NSError {
            throw RuleError.InvalidJSONSerialization("Unable to get JSON from data given", error)
        }
    }
    
    public func dumpData(value: V) throws -> NSData {
        do {
            return try NSJSONSerialization.dataWithJSONObject(try dump(value), options: NSJSONWritingOptions(rawValue: 0))
        } catch let error as NSError {
            let cause = RuleError.InvalidJSONSerialization("Could not convert JSON object to data.", error)
            throw RuleError.InvalidDump("Unable to dump value \(value) to JSON data.", cause)
        }
    }
}

public func /(path: JSONPath, right: String) -> JSONPath {
    return JSONPath(path.elements + [right])
}

