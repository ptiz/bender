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
 Base generic bender protocol for validator rule.
 */
public protocol Rule {
    associatedtype V
    func validate(_ jsonValue: AnyObject) throws -> V
    func dump(_ value: V) throws -> AnyObject
}

// MARK: - Helpers

public extension Rule {
    func validateData(_ jsonData: Data?) throws -> V {
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
    
    func dumpData(_ value: V) throws -> Data {
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
 Generic class for boxing value type.
 */
public class ref<T> {
    open var value: T
    
    public init(_ value: T) {
        self.value = value
    }
}

