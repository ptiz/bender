//
//  ObjectRule.swift
//  Bender
//
//  Created by Evgenii Kamyshanov on 07.12.16.
//  Original work Copyright © 2016 Evgenii Kamyshanov
//  Modified work Copyright © 2016 Sviatoslav Bulgakov, Anton Davydov
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
    
    fileprivate typealias LateBindClosure = (RefT) -> Void
    fileprivate typealias RuleClosure = (AnyObject) throws -> LateBindClosure?
    fileprivate typealias OptionalRuleClosure = (AnyObject?) throws -> LateBindClosure?
    fileprivate typealias RequirementClosure = (AnyObject) throws -> Bool
    fileprivate typealias DumpRuleClosure = (T) throws -> AnyObject
    fileprivate typealias DumpOptionalRuleClosure = (T) throws -> AnyObject?
    
    fileprivate var pathRequirements = [(JSONPath, RequirementClosure)]()
    
    fileprivate var pathMandatoryRules = [(JSONPath, RuleClosure)]()
    fileprivate var pathOptionalRules = [(JSONPath, OptionalRuleClosure)]()
    
    fileprivate var mandatoryDumpRules = [(JSONPath, DumpRuleClosure)]()
    fileprivate var optionalDumpRules = [(JSONPath, DumpOptionalRuleClosure)]()
    
    fileprivate let objectFactory: ()->RefT
    
    /**
     Validator initializer
     
     - parameter factory: autoclosure for allocating object, which returns reference to object of generic type T
     */
    public init(_ objectFactory: @autoclosure @escaping ()->RefT) {
        self.objectFactory = objectFactory
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
        pathRequirements.append((path,  { requirement(try rule.validate($0)) }))
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
        pathMandatoryRules.append((path, storeRule(rule, bind)))
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
        pathMandatoryRules.append((path, storeRule(rule, bind)))
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
        pathMandatoryRules.append((path, storeRule(rule, bind)))
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
        pathOptionalRules.append((path, storeOptionalRule(rule, ifNotFound, bind)))
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
        pathOptionalRules.append((path, storeOptionalRule(rule, ifNotFound, bind)))
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
        guard let json = jsonValue as? NSDictionary else {
            throw RuleError.invalidJSONType("Value of unexpected type found: \"\(jsonValue)\". Expected dictionary \(T.self).", nil)
        }
        
        try validateRequirements(json)
        
        let mandatoryBindings = try validateMandatoryRules(json)
        let optionalBindings = try validateOptionalRules(json)
        
        let newStruct = objectFactory()
        
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
    
    fileprivate func validateRequirements(_ json: NSDictionary) throws {
        for (path, rule) in pathRequirements {
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
    
    fileprivate func validateMandatoryRules(_ json: NSDictionary) throws -> [LateBindClosure] {
        var bindings = [LateBindClosure]()
        for (path, rule) in pathMandatoryRules {
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
    
    fileprivate func validateOptionalRules(_ json: NSDictionary) throws -> [LateBindClosure] {
        var bindings = [LateBindClosure]()
        for (path, rule) in pathOptionalRules {
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
public class ClassRule<T>: ObjectRule<T, T> {
    
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
public class StructRule<T>: ObjectRule<T, ref<T>> {
    
    public override init( _ factory: @autoclosure @escaping ()->ref<T>) {
        super.init(factory)
    }
    
    open override func value(_ newStruct: ref<T>) -> T {
        return newStruct.value
    }
}
