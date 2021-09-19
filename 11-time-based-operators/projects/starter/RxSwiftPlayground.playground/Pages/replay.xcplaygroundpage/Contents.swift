import UIKit
import RxSwift
import RxCocoa


// Start coding here
let elementsPerSecond = 1
let maxElements = 58
let replayedElements = 1
let replayDelay: TimeInterval = 3
let sourceObservable = Observable<Int>.create { observer in
    var value = 1
    let timer = DispatchSource.timer(interval: 1.0 / Double(elementsPerSecond), queue: .main) {
        if value <= maxElements {
            observer.onNext(value)
            value += 1
        }
    }
    return Disposables.create {
        timer.suspend()
    }
}
// 每一个新的 subscriber 都能立即收到 replayedElements，如果以前有人触发过监听
//.replay(replayedElements)
.replayAll()

let sourceTimeline = TimelineView<Int>.make()
let replayedTimeline = TimelineView<Int>.make()

let stackView = UIStackView.makeVertical([
    UILabel.make("replay"),
    UILabel.make("Emit \(elementsPerSecond) per second"),
    sourceTimeline,
    UILabel.make("Replay \(replayedElements) after \(replayDelay) sec"),
    replayedTimeline
])
// 订阅另外一个 sourceTimeline 是什么意思？
// sourceTimeline 实现了 ObserverType 协议， 他可以被一个其他的 observable 订阅。
// 意思是，sourceObservable onNext 的时候， 交给 sourceTimeline 处理
// 这里没有 disponse， 因为 playground 重新运行的时候， 啥都给 remove 了。 但是在 app 里， 对于一个 long-running 的 observable，记得一定要 dispose
let _ = sourceObservable.subscribe(sourceTimeline)
DispatchQueue.main.asyncAfter(deadline: .now() + replayDelay) {
    _ = sourceObservable.subscribe(replayedTimeline)
}
//“Since replay(_:) creates a connectable observable, you need to connect it to its underlying source to start receiving items. If you forget this, subscribers will never receive anything”
// 意思是：ConnectableObservable 这种类型的 Observable，在你调用 connect() 之前, 即使他们有好多的 subscribe，subscriber 也不会收到任何消息。
// 如下几个操作，返回的就是 ConnectableObservable
// replay(_:) / replayAll() / multicast(_:) / publish()

_ = sourceObservable.connect()

let hostView = setupHostView()
hostView.addSubview(stackView)
hostView

// Support code -- DO NOT REMOVE
class TimelineView<E>: TimelineViewBase, ObserverType where E: CustomStringConvertible {
  static func make() -> TimelineView<E> {
    return TimelineView(width: 400, height: 100)
  }
  public func on(_ event: Event<E>) {
    switch event {
    case .next(let value):
      add(.next(String(describing: value)))
    case .completed:
      add(.completed())
    case .error(_):
      add(.error())
    }
  }
}
/// Copyright (c) 2020 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.
