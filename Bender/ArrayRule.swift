//
//  ArrayRule.swift
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
