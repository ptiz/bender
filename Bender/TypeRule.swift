//
//  TypeRule.swift
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
