//
//  AsyncOperation.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 10/13/24.
//  Source: https://www.avanderlee.com/swift/asynchronous-operations/

import UIKit

class AsyncOperation: Operation, @unchecked Sendable {
    
    private let lockQueue = DispatchQueue(label: "asyncOperation", attributes: .concurrent)
    private var _isExecuting: Bool = false
    private var _isFinished: Bool = false
    
    override var isAsynchronous: Bool {
        return true
    }
    
    override private(set) var isExecuting: Bool {
        get {
            return lockQueue.sync { () -> Bool in
                return _isExecuting
            }
        }
        set {
            willChangeValue(forKey: "isExecuting")
            lockQueue.sync(flags: [.barrier]) {
                _isExecuting = newValue
            }
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    override private(set) var isFinished: Bool {
        get {
            return lockQueue.sync { () -> Bool in
                return _isFinished
            }
        }
        set {
            willChangeValue(forKey: "isFinished")
            lockQueue.sync(flags: [.barrier]) {
                _isFinished = newValue
            }
            didChangeValue(forKey: "isFinished")
        }
    }

    override func start() {
        
        guard !isCancelled else {
            finish()
            return
        }
        
        isFinished = false
        isExecuting = true
        
        main()
    }

    func finish() {
        isExecuting = false
        isFinished = true
    }
    
    override func cancel() {
        super.cancel()
        
        if isExecuting {
            finish()
        }
    }
}



