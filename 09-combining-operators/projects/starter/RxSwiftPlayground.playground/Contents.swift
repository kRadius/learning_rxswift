import Foundation
import RxSwift
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

// Start coding here!

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


example(of: "startWith") {
    // 这个东西有啥用？
    // 用来给一个 Observerable 添加一个初始状态， 比如 网络当前的状态， 或者是当前的地理位置
    let number = Observable.of(1, 2, 3)
    let observable = number.startWith(0)
    // 这里说是不用 bag 会安全？不会内存泄漏
    let _ = observable.subscribe(onNext: {
        print($0)
    }, onDisposed: {
        print("disposed")
    })
    // 那我直接给 number 一个初始化状态不就得了么？
}

example(of: "Observale.contact") {
    let first = Observable.of(1, 2, 3)
    let second = Observable.of(4, 5, 6)
    
    let observable = Observable.concat(first, second)
    // 下面这种写法也是一样的效果
    //    let observable = Observable.concat([first, second])
    observable.subscribe(onNext: {
        print($0)
    })
}

example(of: "contact") {
    let germanCities = Observable.of("Berlin", "Münich", "Frankfurt")
    let spanishCities = Observable.of("Madrid", "Barcelona", "Valencia")
    // 只能 contact 同一种类型的 Observable
    let observable = germanCities.concat(spanishCities)
    observable.subscribe(onNext: {
        print($0)
    })
}
// 和 flatMap 类似， 把一个 Observable 转换成 另一个
// 区别是啥？ 保证了一个时序
// “ The closure you pass to concatMap(_:) returns an Observable sequence which the operator first subscribes to, then relays the values it emits into the resulting sequence. concatMap(_:) guarantees that each sequence the closure produces runs to completion before subscribing to the next one. It‘s a handy way to guarantee sequential order while giving you the power of flatMap(_:).”
//  意思就是说：
example(of: "contact map") {
    let sequence = [
        "German Cities" : Observable.of("Berlin", "Münich", "Frankfurt"),
        "Spanish Cities" : Observable.of("Madrid", "Barcelona", "Valencia")
    ]
    
    let observable = Observable.of("German Cities", "Spanish Cities")
        .concatMap { country -> Observable<String> in
            print("aaa", country)
            return sequence[country] ?? .empty()
        }
    let _ = observable.subscribe(onNext: {
        print($0)
    })
}
example(of: "merge") {
    // 1
    let left = PublishSubject<String>()
    let right = PublishSubject<String>()
    
    // 2
    let source = Observable.of(left.asObserver(), right.asObserver())
    
    // 3
    
    let observable = source.merge()
    observable.subscribe(onNext: {
        print($0)
    })
    // 4
    var leftValues = ["Berlin", "Münich", "Frankfurt"]
    var rightValues = ["Madrid", "Barcelona", "Valencia"]
    
    repeat {
        switch Bool.random() {
        case true where !leftValues.isEmpty:
            left.onNext("Left:  " + leftValues.removeFirst())
        case false where !rightValues.isEmpty:
            right.onNext("Right: " + rightValues.removeFirst())
        default:
            break
        }
    } while !leftValues.isEmpty || !rightValues.isEmpty
    //“merge() completes after its source sequence completes and all inner sequences have completed.”
    // 只有当 merged 的所有 sequence 都 completed 了， merge 才能结束
    // 如果其中有任意一个 observable 发生了错误， 那么 merge 就会立即抛出这个 error，并且 ternimate
    left.onCompleted()
    right.onCompleted()
    
    // merge 还能接受一个最大并发数， 到达了最大的数量之后， 后面就会进入排队， 只有当前面的 完成了， 才会进入 merge
    // 这个可以用来限制最大的网络请求数量
}
// 只有当 combine 的所有 observable 都触发过了， 才会触发监听。之后 inner 的每一个 onNext， 都会触发整体的 subscrbe
example(of: "combineLatest") {
    let left = PublishSubject<String>()
    let right = PublishSubject<String>()
    // 等同于后面加了个 map
    let observable = Observable.combineLatest(left, right) { lastLeft, lastRight in
        "\(lastLeft)\(lastRight)"
    }
    let _ = observable.subscribe(onNext: {
        print($0)
    })
    
    print("> Sending a value to Left")
    // 这个时候 right 还没有值， 不会输出什么。如果 left 和 right 都有初始值， 比如用 startWith， 那么就可以输出
    left.onNext("Hello,")
    print("> Sending a value to Right")
    right.onNext("world")
    print("> Sending another value to Right")
    right.onNext("RxSwift")
    print("> Sending another value to Left")
    left.onNext("Have a good day,")
    
    left.onCompleted()
    right.onCompleted()
}


example(of: "Combine user choice and value") {
    let choice = Observable<DateFormatter.Style>.of(.short, .long)
    let dates = Observable.of(Date())
    
    let observable = Observable.combineLatest(choice, dates) {
        format, date -> String in
        let formatter = DateFormatter()
        formatter.dateStyle = format
        return formatter.string(from: date)
    }.subscribe(onNext: {
        print($0)
    })
    
    // combineLatest 的 complete 时机，是里面所有的 observable 都完成了
}

// 一对一对的出现“ (1st with 1st, 2nd with 2nd, etc.)”
example(of: "zip") {
    enum Weather {
        case cloudy
        case sunny
    }
    let left = Observable<Weather>.of(.sunny, .cloudy, .cloudy, .sunny)
    
    let right = Observable.of("Lisbon", "Copenhagen", "London", "Madrid", "Vienna")
    let observable = Observable.zip(left, right) { weather, city in
        return "It is \(weather) in \(city)"
    }
    let _ = observable.subscribe(onNext: {
        print($0)
    })
    // 最后这个 Vienna 不会输出
    // zip 做了什么
    // 1. 订阅你传入的 observable 2. 等待每一个 observable emit 一个 值 3. 调用你的你的闭包
    
    // 虽然他可能会提前停止输出， 但是你还是需要保证那些 sequence 能正常完成
}

// 作用是你想当获取某些 observable 的输出，但是仅当是在某些其他的 Action 触发的时候
// A.withLatest(B): A 是 trigger， A.onNext 时候， 输出 B
example(of: "withlatest") {
    let textfield = PublishSubject<String>()
    let button = PublishSubject<Void>()
    
    let observable = button.withLatestFrom(textfield)
    observable.subscribe(onNext: {
        print($0)
    })
    
    textfield.onNext("Pa")
    textfield.onNext("pair")
    textfield.onNext("Pairs")
    
    button.onNext(())
    button.onNext(())
}

// 作用是: 和 withLatest 反过来了
// A.sample(B): B 是 trigger， A.onNext 之后，如果 B.onNext，才输出 A。而且需要一次一次的匹配
// 有点儿：withLatest + distinctUntilChange 的意思，
example(of: "sample") {
    let textfield = PublishSubject<String>()
    let button = PublishSubject<Void>()
    
    let observable = textfield.sample(button)
    observable.subscribe(onNext: {
        print($0)
    })
    
    textfield.onNext("Pa")
    textfield.onNext("pair")
    textfield.onNext("Pairs")
    
    button.onNext(())
    textfield.onNext("Pairs")
    textfield.onNext("Pairs1")
    button.onNext(())
    textfield.onNext("new Pairs")
    
    textfield.onCompleted()
    button.onCompleted()
}
// amb = ambiguous
// 取消监听后 onNext 的
// 作用：你不知道你感兴趣哪个，只有当他们确定的时候才能决定。这个经常被忽视，在实际中可以用来避免重复连接到 server
example(of: "amb") {
    let left = PublishSubject<String>()
    let right = PublishSubject<String>()
    
    let observable = left.amb(right)
    
    let _ = observable.subscribe(onNext: {
        print($0)
    }, onDisposed: {
        print("diposed")
    })
    
    left.onNext("Libson")
    right.onNext("Copenhagen")
    left.onNext("London")
    left.onNext("Madrid")
    right.onNext("Vienna")
    
    left.onCompleted()
    right.onCompleted()
}

// 有个很热门的操作
// 是啥：对于 Element 是 Observable 的 Observable 才能够使用
// 作用：切换最新的 sequence(observable)
example(of: "SwitchLatest") {
    let one = PublishSubject<String>()
    let two = PublishSubject<String>()
    let three = PublishSubject<String>()
    // one.switchLatest()????
    
    let source = PublishSubject<Observable<String>>()
    
    // 2
    let observable = source.switchLatest()
    let diposable = observable.subscribe(onNext: { value in
        print(value)
    }, onDisposed: {
        print("diposed")
    })
    
    // 3
    source.onNext(one)
    one.onNext("Text from one")
    two.onNext("Text from two")
    
    source.onNext(two)
    one.onNext("More Text from one")
    two.onNext("More Text from two")
    
    source.onNext(three)
    one.onNext("you cannot see me")
    two.onNext("please help me")
    three.onNext("Hi I'm three ")
    // 为什么这个需要 手动 dipose？
    diposable.dispose()
}
// 和 collection 的一样，
// 注意，只有当 observable completed 的时候， 才会输出值， 如果是一个 never， 那么不会输出什么
example(of: "reduce") {
    let observable = Observable.of(1, 2, 3)
//    observable
//        .reduce(0, accumulator: +)
//        .subscribe(onNext: {
//            print($0)
//        })
    // 等同于
    observable
        .reduce(0) { summary, newValue in
            return summary + newValue
        }
        .subscribe(onNext: {
            print($0)
        })
}
// scan 也是 累积 acculator 的操作， 不过他是每一次累积都会输出， reduce 只会输出一次
example(of: "scan") {
    let observable = Observable.of(1, 3, 5, 7, 9)
    observable.scan(0, accumulator: +)
        .subscribe(onNext: {
            print($0)
        })
}

// challenge
//Take the code from the scan(_:accumulator:) example above and improve it so as to display both the current value and the running total at the same time.
example(of: "challenge solution 1") {
    let left = Observable.of(1, 3, 5, 7, 9)
    let right = Observable.of(1, 3, 5, 7, 9).scan(0, accumulator: +)
    
    let observable = Observable.zip(left, right)
    observable.subscribe(
        onNext: { left, right in
            print("left \(left), right \(right)")
        },
        onDisposed: {
            print("diposed")
        }
    )
}

example(of: "challenge solution 2") {
    
    Observable.of(1, 3, 5, 7, 9).scan((0, 0)) { seed, current in
        return (current, seed.1 + current)
    }
    .subscribe(onNext: {
        print($0)
    })

}
