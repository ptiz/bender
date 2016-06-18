//
//  ObjectRule.swift
//  Bender
//
//  Created by Evgenii Kamyshanov on 28.03.16.
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
 Validator for compound types: classes or structs. Validates JSON struct for particular type T,
 which is passed by value of type RefT.
 */
public class ObjectRule<T, RefT>: Rule {
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
        
        let newStruct = try factory(json)
        
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
    
    func factory(jsonValue: [String: AnyObject]) throws -> RefT {
        fatalError("ObjectRule.factory is an abstract method. Please override it in descendants.")
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
public class ClassRule<T>: ObjectRule<T, T> {
    
    private let factory: ()->T
    
    public init(@autoclosure(escaping) _ factory: ()->T) {
        self.factory = factory
    }
    
    public override func value(newStruct: T) -> T {
        return newStruct
    }
    
    override func factory(jsonValue: [String: AnyObject]) throws -> T {
        return self.factory()
    }
}

/**
 Validator of compound JSON object with binding to value type like struct T. Reference type is ref<T>.
 */
public class StructRule<T>: ObjectRule<T, ref<T>> {
    
    private let factory: ()->ref<T>
    
    public init(@autoclosure(escaping) _ factory: ()->ref<T>) {
        self.factory = factory
    }
    
    public override func value(newStruct: ref<T>) -> T {
        return newStruct.value
    }
    
    override func factory(jsonValue: [String: AnyObject]) throws -> ref<T> {
        return self.factory()
    }
}

public class ContextClassRule<T>: ObjectRule<T, T> {
    
    private let factory: ([String: AnyObject]) throws ->T
    
    public init(_ factory: ([String: AnyObject]) throws ->T) {
        self.factory = factory
    }
    
    public override func value(newStruct: T) -> T {
        return newStruct
    }
    
    override func factory(jsonValue: [String: AnyObject]) throws -> T {
        return try self.factory(jsonValue)
    }
}

//TODO: remove AnyObject requirement for protocols and think about custom type cast closure in each "type" method 
public class PolyClassRule<T: AnyObject>: Rule {
    public typealias V = T
    
    private typealias CheckRuleClosure = ([String: AnyObject]) -> (([String: AnyObject]) throws -> T)?
    private typealias DumpRuleClosure = (V) throws -> AnyObject?
    
    private var checkRuleClosures = [CheckRuleClosure]()
    private var dumpRuleClosures = [DumpRuleClosure]()
    
    //TODO: add "checker" function/class family
    public func type<R: Rule>(check: ([String: AnyObject])->Bool, rule: R) -> Self {
        checkRuleClosures.append({ json in
            if check(json) {
                return { json in
                    // WORKAROUND: there is no ability in swift to constraint to child of a generic type,
                    // so let's check it in runtime
                    guard let t = try rule.validate(json) as? T else {
                        throw RuleError.InvalidJSONType("Object of unexpected type validated: \"\(R.V.self)\". Expected child of \(T.self).", nil)
                    }
                    return t
                }
            }
            return nil
        })
        
        dumpRuleClosures.append({ value in
            if let v = value as? R.V {
                return try rule.dump(v)
            }
            return nil
        })
        
        return self
    }
    
    public func validate(jsonValue: AnyObject) throws -> T {
        guard let json = jsonValue as? [String: AnyObject] else {
            throw RuleError.InvalidJSONType("Value of unexpected type found: \"\(jsonValue)\". Expected dictionary \(T.self).", nil)
        }
        
        for ruleClosure in checkRuleClosures {
            if let ruleValidate = ruleClosure(json) {
                return try ruleValidate(json)
            }
        }
        
        throw RuleError.ExpectedNotFound("Could not found matching type for \(T.self) in dictionary: \(json)", nil)
    }
    
    public func dump(value: V) throws -> AnyObject {
        for rule in dumpRuleClosures {
            if let obj = try rule(value) {
                return obj
            }
        }
        throw RuleError.InvalidDump("Unable to find rule for value \(value).", nil)
    }
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


