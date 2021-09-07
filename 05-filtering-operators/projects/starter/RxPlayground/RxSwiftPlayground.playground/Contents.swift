import Foundation
import RxSwift



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

example(of: "ignore events") {
    let strikes = PublishSubject<String>()
    let bag = DisposeBag()
    // “The ignoreElements operator is useful when you only want to be notified when an observable has terminated, via a completed or error event”
    strikes
        .ignoreElements()
        .subscribe { _ in
        print("Ignore")
    }
    .disposed(by: bag)
    
    strikes.onNext("X")
    strikes.onNext("X")
    strikes.onNext("X")
    
    strikes.onCompleted()
}

example(of: "elementAt") {
    let strikes = PublishSubject<String>()
    let bag = DisposeBag()
    
    // 一旦 elementAt 找到了对应的 event， 直接就 completed 了。
    strikes
        .elementAt(2)
        .subscribe() { x in
            print(x)
        }
        .disposed(by: bag)
    
    strikes.onNext("X")
    strikes.onNext("Y")
    strikes.onNext("Z")
//    strikes.onCompleted()
}

example(of: "fileter") {
    let disposeBag = DisposeBag()
    
    Observable.of(1, 2, 3, 4, 5, 6)
        .filter({
            $0.isMultiple(of: 2)
        })
        .subscribe(
            onNext:{ x in
                print(x)
            }
        )
        .disposed(by: disposeBag)
}

//“It lets you ignore the first n elements, where n is the number you pass as its parameter. ”
example(of: "Skip") {
    let disposeBag = DisposeBag()
    
    Observable.of("A", "B", "C", "D", "E", "F")
        .skip(3)
        .subscribe(
            onNext: { x in
                print(x)
            }
        )
        .disposed(by: disposeBag)
}

// “And with skipWhile, returning true will cause the element to be skipped, and returning false will let it through. It’s the opposite of filter.”

// filter 是过滤掉为 true 的。
// skipWhile 是过滤掉 false 的，直到 true 出现， 那么后面的所有就都能打出来
example(of: "SkipWhile") {
    let disposeBag = DisposeBag()
    // 当出现第一个奇数的时候， 开始打印
    Observable.of(2, 2, 3, 4, 5, 6)
        .skipWhile({ $0.isMultiple(of: 2) })
        .subscribe( onNext: {
            print($0)
        })
        .disposed(by: disposeBag)
        
}

// 直到 trigger 发送了消息，subject 才会停止 skip
example(of: "SkipUntil") {
    let disposeBag = DisposeBag()
    
    let subject = PublishSubject<String>()
    let trigger = PublishSubject<String>()
    
    subject
        .skipUntil(trigger)
        .subscribe(
            onNext:{ x in
                print(x)
            }
        )
        .disposed(by: disposeBag)
    
    subject.onNext("A")
    subject.onNext("B")
    
    trigger.onNext("trigger")
    
    subject.onNext("C")
}

// take 是 skip 的反操作。他会一直输出， 直到有人叫他别输出了
// take 接受的是一个的 int 类型。 所以是弱水三千， 只取前 X 瓢
example(of: "Take") {
    let disposeBag = DisposeBag()
    Observable
        .of(1, 2, 3, 4, 5)
        .take(3)
        .subscribe(onNext: {
            print($0)
        })
        .disposed(by: disposeBag)
}
// takeWhile 来了， 但是不依赖其他的 observable
example(of: "TakeWhile") {
    let bag = DisposeBag()
    Observable.of(1, 2, 3, 4, 5)
        .enumerated()
        .takeWhile { index, vlaue in
            vlaue < 3
        }
        .map(\.element)
        .subscribe(onNext: {
            print($0)
        })
        .disposed(by: bag)
}
// takeUntil 第一个参数是类型， 第二个参数是 block
example(of: "TakeUntil") {
    let disposeBag = DisposeBag()
    Observable.of(1, 2, 3, 4, 5)
        .takeUntil(.exclusive) { $0.isMultiple(of: 4) }
        .subscribe(onNext: {
            print($0)
        })
        .disposed(by: disposeBag)
}

// takeUntil 还有一个变体， 参数是别的 Source, 需要一个 Trigger
example(of: "TakeUntil Trigger") {
    let bag = DisposeBag()
    let subject = PublishSubject<String>()
    let trigger = PublishSubject<String>()
    
    
    subject.takeUntil(trigger)
        .subscribe(onNext:{
            print($0)
        })
        .disposed(by: bag)
    
    subject.onNext("1")
    subject.onNext("2")
    
    trigger.onNext("1")
    
    subject.onNext("3")
}

// “The next couple of operators let you prevent duplicate contiguous items from getting through. ”
// 可以用来阻止连续的 Event, 元素需要是可比较的
// distinct Until Changed = 直到改变
example(of: "Distinct") {
    let disposeBag = DisposeBag()
    Observable.of(1, 2, 2, 3, 3, 3, 4, 3, 5)
        .distinctUntilChanged()
        .subscribe(onNext: {
            print($0)
        })
        .disposed(by: disposeBag)
}
// 如果不是 Equatable 的， 那么可以自己判断
// 这个比较的逻辑原来是： 如果 block 里的逻辑不满足，就一直用一个元素去比较。
// 想想一下自己如果实现这个算法， 肯定是用双指针
example(of: "Distinct Equtable?") {
    let disposeBag = DisposeBag()
    Observable.of(1, 2, 2, 3, 3, 3, 4, 3, 5)
        .distinctUntilChanged({ a, b in
            return a == b
        })
        .subscribe(onNext: {
            print($0)
        })
        .disposed(by: disposeBag)
}

example(of: "distinctUntilChanged(_:)") {
    let disposeBag = DisposeBag()
    
    let formatter = NumberFormatter()
    formatter.numberStyle = .spellOut
    Observable<NSNumber>.of(10, 110, 20, 200, 210, 310)
        .distinctUntilChanged { a, b in
//            print(a, b)
            // 4
          guard
            let aWords = formatter
              .string(from: a)?
              .components(separatedBy: " "),
            let bWords = formatter
              .string(from: b)?
              .components(separatedBy: " ")
            else {
              return false
          }

          var containsMatch = false
            print(aWords, bWords)
          // 5
          for aWord in aWords where bWords.contains(aWord) {
            print(aWord)
            containsMatch = true
            break
          }

          return containsMatch
        }
        .subscribe(onNext: {
            print($0)
//            $0
        })
        .disposed(by: disposeBag)
}
