//
//  JSONPath.swift
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

func setInDictionary(dictionary: [String: AnyObject], object: AnyObject?, atPath path: JSONPath) throws -> [String: AnyObject] {
    var traverseDictionary = dictionary
    if path.elements.count == 1 {
        traverseDictionary[path.elements.last!] = object
        return traverseDictionary
    }
    
    let pathElement = path.elements.first!
    if let nestedObject = traverseDictionary[pathElement] {
        guard let existingDictionary = nestedObject as? [String: AnyObject] else {
            throw RuleError.InvalidDump("\"\(pathElement)\" is not a dictionary.", nil)
        }
        traverseDictionary[pathElement] = try setInDictionary(existingDictionary, object: object, atPath: path.tail())
        return traverseDictionary
    }
    
    traverseDictionary[pathElement] = try setInDictionary([:], object: object, atPath: path.tail())
    return traverseDictionary
}

/**
 Operator constructing JSONPath
 
 - parameter path:  JSONPath object or string literal for conversion initializer
 - parameter right: string literal to be added to the path
 
 - returns: newly created JSONPath with 'right' appended to it
 */
public func /(path: JSONPath, right: String) -> JSONPath {
    return JSONPath(path.elements + [right])
}

