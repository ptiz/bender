//
//  TypeRule.swift
//  Bender
//
//  Created by Evgenii Kamyshanov on 07.12.16.
//  Original work Copyright © 2016 Evgenii Kamyshanov
//  Modified work Copyright © 2016 Anton Davydov
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
 Base class for numeric validators
 */
open class NumberRule<T>: Rule {
    public typealias V = T
    
    public func validate(_ jsonValue: AnyObject) throws -> T {
        guard let number = jsonValue as? NSNumber else {
            throw RuleError.invalidJSONType("Value of unexpected type found: \"\(jsonValue)\". Expected \(T.self).", nil)
        }
        return try validateNumber(number)
    }
    
    open func dump(_ value: T) throws -> AnyObject {
        return try toAny(value)
    }
    
    open func validateNumber(_ number: NSNumber) throws -> T {
        throw RuleError.invalidJSONType("Value of unexpected type found: \"\(number)\". Expected \(T.self).", nil)
    }
}

/**
 Validator for signed and unsigned integer numerics
 */
public class IntegerRule<T: BinaryInteger>: NumberRule<T> {
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
