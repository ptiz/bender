//
//  StringifiedJSONRule.swift
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
