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
 Base generic bender protocol for validator rule.
 */
public protocol Rule {
    associatedtype V
    func validate(jsonValue: AnyObject) throws -> V
    func dump(value: V) throws -> AnyObject
}

public extension Rule {
    public func validateData(jsonData: NSData?) throws -> V {
        do {
            guard let data = jsonData else {
                throw RuleError.ExpectedNotFound("Unable to get JSON object: no data found.", nil)
            }
            return try validate(try NSJSONSerialization.JSONObjectWithData(data, options: []))
        } catch let error as RuleError {
            throw RuleError.InvalidJSONType("Unable to get JSON from data given.", error)
        } catch let error {
            throw RuleError.InvalidJSONType("Unable to get JSON from data given. \(error)", nil)
        }
    }
    
    public func dumpData(value: V) throws -> NSData {
        do {
            return try NSJSONSerialization.dataWithJSONObject(try dump(value), options: NSJSONWritingOptions(rawValue: 0))
        } catch let error as RuleError {
            throw RuleError.InvalidDump("Unable to dump value \(value) to JSON data.", error)
        } catch let error {
            throw RuleError.InvalidDump("Unable to dump value \(value) to JSON data. \(error)", nil)
        }
    }
}

