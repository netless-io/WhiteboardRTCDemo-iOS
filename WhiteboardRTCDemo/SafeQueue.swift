import Foundation

class SafeQueue<T> {
    internal init(maxSize: Int) {
        self.maxSize = maxSize
    }
    
    private var queue = [T]()
    private let semaphore = DispatchSemaphore(value: 1)
    let maxSize: Int
    
    func enqueue(_ elements: [T]) {
        semaphore.wait()
        queue.append(contentsOf: elements)
        if queue.count > maxSize {
            queue.removeFirst(queue.count - maxSize)
        }
        semaphore.signal()
    }

    func dequeue(count: Int) -> [T]? {
        semaphore.wait()
        defer { semaphore.signal() }
        if queue.count >= count {
            let result = Array(queue.prefix(count))
            queue.removeFirst(count)
            return result
        } else {
            return nil
        }
    }
}
