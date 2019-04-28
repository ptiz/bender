//
//  EnumRule.swift
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
 Validator for enum of type T. Checks that JSON value to be validated is equal to any option stored and .
 If all stored properties do not match, throws ValidateError.
 */
open class EnumRule<T: Equatable>: Rule {
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
