//
//  JSONPath.swift
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

public struct JSONPath: ExpressibleByStringLiteral, ExpressibleByArrayLiteral, CustomStringConvertible {
    
    public enum PathElement: CustomStringConvertible {
        case DictionaryKey(String)
        case ArrayIndex(Int)
        
        public var description: String {
            switch self {
            case .DictionaryKey(let value): return value
            case .ArrayIndex(let value): return "\(value)"
            }
        }
    }
    
    public let elements: [PathElement]
    
    public init(_ value: [PathElement]) {
        elements = value
    }
    
    public init(unicodeScalarLiteral value: String) {
        elements = [PathElement.DictionaryKey(value)]
    }
    
    public init(extendedGraphemeClusterLiteral value: String) {
        elements = [PathElement.DictionaryKey(value)]
    }
    
    public init(stringLiteral value: String) {
        elements = [PathElement.DictionaryKey(value)]
    }
    
    public init(arrayLiteral elements: String...) {
        self.elements = elements.map({ PathElement.DictionaryKey($0) })
    }
    
    public init(_ elements: [String]) {
        self.elements = elements.map({ PathElement.DictionaryKey($0) })
    }
    
    public var description: String {
        return elements.map({ "\($0)" }).joined(separator: "/")
    }
    
    public func tail() -> JSONPath {
        return JSONPath(Array(elements[1..<elements.count]))
    }
    
    public var singleString: String? {
        if elements.count == 1 {
            switch elements[0] {
            case .DictionaryKey(let value): return value
            case .ArrayIndex: return nil
            }
        }
        return nil
    }
}

public func getInDictionary(_ dict: NSDictionary, atPath path: String) -> AnyObject? {
    if let value = dict.value(forKey: path) as AnyObject?, !(value is NSNull) {
        return value
    }
    return nil
}

public func getInDictionary(_ dict: NSDictionary, atPath path: JSONPath) -> AnyObject? {
    if let key = path.singleString {
        return getInDictionary(dict, atPath: key)
    }
    
    var currentObject: AnyObject? = dict as AnyObject
    for pathItem in path.elements {
        if let currentDict = currentObject as? NSDictionary, case .DictionaryKey(let item) = pathItem, let next = currentDict.value(forKey: item) as AnyObject?, !(next is NSNull) {
            currentObject = next
            continue
        }
        if let currentArray = currentObject as? NSArray, case .ArrayIndex(let index) = pathItem, currentArray.count > index && !(currentArray[index] is NSNull) {
            currentObject = currentArray[index] as AnyObject?
            continue
        }
        currentObject = nil
    }
    return currentObject
}

public func setInDictionary(_ dictionary: [String: AnyObject], object: AnyObject?, atPath path: JSONPath) throws -> [String: AnyObject] {
    guard let first = path.elements.first else {
        throw RuleError.invalidDump("Unexpectedly count of path elements is 0", nil)
    }
    guard case .DictionaryKey(let pathElement) = first else {
        throw RuleError.invalidDump("Dump by a path within an array is not implemented. Element \"\(first)\" is not a dictionary.", nil)
    }
    
    var traverseDictionary = dictionary
    if path.elements.count == 1 {
        traverseDictionary[pathElement] = object
        return traverseDictionary
    }
    
    if let nestedObject = traverseDictionary[pathElement] {
        guard let existingDictionary = nestedObject as? [String: AnyObject] else {
            throw RuleError.invalidDump("\"\(pathElement)\" is not a dictionary.", nil)
        }
        traverseDictionary[pathElement] = try setInDictionary(existingDictionary, object: object, atPath: path.tail()) as AnyObject?
        return traverseDictionary
    }
    
    traverseDictionary[pathElement] = try setInDictionary([:], object: object, atPath: path.tail()) as AnyObject?
    return traverseDictionary
}

/**
 Operator constructing JSONPath
 
 - parameter path:  JSONPath object or string literal for conversion initializer
 - parameter right: string literal to be added to the path
 
 - returns: newly created JSONPath with 'right' appended to it
 */
public func /(path: JSONPath, right: String) -> JSONPath {
    return JSONPath(path.elements + [.DictionaryKey(right)])
}

public func /(path: JSONPath, right: UInt) -> JSONPath {
    return JSONPath(path.elements + [.ArrayIndex(Int(right))])
}

public func /(path: JSONPath, right: JSONPath) -> JSONPath {
    return JSONPath(path.elements + right.elements)
}

