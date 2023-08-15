
//
//  TaskQueue.swift
//  PusherSwift
//
//  Created by Kirtankumar Patel , Hemal Patel on 11/08/2023.
//


import Foundation

internal class TaskQueue: CustomStringConvertible {
    public typealias ClosureNoResultNext = () -> Void
    public typealias ClosureWithResultNext = (Any?, @escaping (Any?) -> Void) -> Void

    internal var tasks = [ClosureWithResultNext]()
    internal lazy var completions = [ClosureNoResultNext]()

    fileprivate(set) var numberOfActiveTasks = 0
    internal var maximumNumberOfActiveTasks = 1 {
        willSet {
            assert(maximumNumberOfActiveTasks > 0, "Setting less than 1 task at a time is not allowed")
        }
    }

    fileprivate var currentTask: ClosureWithResultNext? = nil
    fileprivate(set) var lastResult: Any! = nil

    fileprivate(set) var running = false

    internal var paused: Bool = false {
        didSet {
            running = !paused
        }
    }

    fileprivate var cancelled = false
    internal func cancel() {
        cancelled = true
    }

    fileprivate var hasCompletions = false

    internal init() {}

    internal func run(_ completion: ClosureNoResultNext? = nil) {
        if completion != nil {
            hasCompletions = true
            completions += [completion!]
        }

        if paused {
            paused = false
            _runNextTask()
            return
        }

        if running {
            return
        }

        running = true
        _runNextTask()
    }

    fileprivate func _runNextTask(_ result: Any? = nil) {
        if (cancelled) {
            tasks.removeAll(keepingCapacity: false)
            completions.removeAll(keepingCapacity: false)
        }

        if (numberOfActiveTasks >= maximumNumberOfActiveTasks) {
            return
        }

        lastResult = result

        if paused {
            return
        }

        var task: ClosureWithResultNext? = nil

        //fetch one task synchronized
        objc_sync_enter(self)
        if tasks.count > 0 {
            task = tasks.remove(at: 0)
            numberOfActiveTasks += 1
        }
        objc_sync_exit(self)

        if task == nil {
            if numberOfActiveTasks == 0 {
                _complete()
            }
            return
        }

        currentTask = task

        let executeTask = {
            task!(self.maximumNumberOfActiveTasks > 1 ? nil: result) {nextResult in
                self.numberOfActiveTasks -= 1
                self._runNextTask(nextResult)
            }
        }

        if maximumNumberOfActiveTasks > 1 {
            //parallel queue
            _delay(seconds: 0.001) {
                self._runNextTask(nil)
            }
            _delay(seconds: 0, completion: executeTask)
        } else {
            //serial queue
            executeTask()
        }
    }

    fileprivate func _complete() {
        paused = false
        running = false

        if hasCompletions {
            //synchronized remove completions
            objc_sync_enter(self)
            while completions.count > 0 {
                completions.remove(at: 0)()
            }
            objc_sync_exit(self)
        }
    }

    internal func skip() {
        if tasks.count>0 {
            _ = tasks.remove(at: 0)
        }
    }

    internal func removeAll() {
        tasks.removeAll(keepingCapacity: false)
    }

    internal var count: Int {
        return tasks.count
    }

    internal func pauseAndResetCurrentTask() {
        paused = true

        tasks.insert(currentTask!, at: 0)
        currentTask = nil
        self.numberOfActiveTasks -= 1
    }

    internal func retry(_ delay: Double = 0) {
        assert(maximumNumberOfActiveTasks == 1, "You can only call retry() only on serial queues")

        tasks.insert(currentTask!, at: 0)
        currentTask = nil

        _delay(seconds: delay) {
            self.numberOfActiveTasks -= 1
            self._runNextTask(self.lastResult)
        }
    }

    internal var description: String {
        let state = running ? "runing " : (paused ? "paused ": "stopped")
        let type = maximumNumberOfActiveTasks == 1 ? "serial": "parallel"

        return "[TaskQueue] type=\(type) state=\(state) \(tasks.count) tasks"
    }

    deinit {}

    fileprivate func _delay(seconds: Double, completion: @escaping () -> ()) {
        let popTime = DispatchTime.now() + Double(Int64( Double(NSEC_PER_SEC) * seconds )) / Double(NSEC_PER_SEC)

        DispatchQueue.global(qos: .background).asyncAfter(deadline: popTime) {
            completion()
        }
    }

}

//
// Add a task closure with result and next params
//
internal func += (tasks: inout [TaskQueue.ClosureWithResultNext], task: @escaping TaskQueue.ClosureWithResultNext) {
    tasks += [task]
}

//
// Add a task closure that doesn't take result/next params
//
internal func += (tasks: inout [TaskQueue.ClosureWithResultNext], task: @escaping TaskQueue.ClosureNoResultNext) {
    tasks += [{ _, next in
        task()
        next(nil)
    }]
}
