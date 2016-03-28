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
 Bender throwing error type
 
 - InvalidJSONType:   basic bender error, contains string and optional ValidateError cause
 - ExpectedNotFound:  throws if expected was not found, contains string and optional ValidateError cause
 - JSONSerialization: throws if JSON parser fails, contains string and optional ValidateError cause
 */
public indirect enum RuleError: ErrorType, CustomStringConvertible {
    case InvalidJSONType(String, RuleError?)
    case ExpectedNotFound(String, RuleError?)
    case InvalidJSONSerialization(String, NSError)
    case InvalidDump(String, RuleError?)
    case UnmetRequirement(String, RuleError?)
    
    public var description: String {
        switch self {
        case InvalidJSONType(let str, let cause):
            return descr(cause, str)
        case .ExpectedNotFound(let str, let cause):
            return descr(cause, str)
        case .InvalidJSONSerialization(let str, let err):
            return descr(err, str)
        case .InvalidDump(let str, let cause):
            return descr(cause, str)
        case .UnmetRequirement(let str, let cause):
            return descr(cause, str)
        }
    }
    
    public func unwindStack() -> [ErrorType] {
        switch self {
        case InvalidJSONType(_, let cause):
            return causeStack(cause)
        case .ExpectedNotFound(_, let cause):
            return causeStack(cause)
        case .InvalidJSONSerialization:
            return [self]
        case .InvalidDump(_, let cause):
            return causeStack(cause)
        case .UnmetRequirement(_, let cause):
            return causeStack(cause)
        }
    }
    
    private func descr(cause: RuleError?, _ msg: String) -> String {
        if let causeDescr = cause?.description {
            return "\(msg)\n\(causeDescr)"
        }
        return msg
    }
    
    private func descr(cause: NSError?, _ msg: String) -> String {
        guard let error = cause else {
            return msg
        }
        let errorDescription = "\n\((error.userInfo["NSDebugDescription"] ?? error.description)!)"
        return "\(msg)\(errorDescription)"
    }
    
    private func causeStack(cause: RuleError?) -> [ErrorType] {
        guard let stack = cause?.unwindStack() else { return [self] }
        return [self] + stack
    }
}
