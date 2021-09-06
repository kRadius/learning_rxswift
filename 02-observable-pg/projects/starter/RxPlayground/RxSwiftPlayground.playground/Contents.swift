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

// observable
//public enum Observable<Element> {
//    case next(Element)
//    case error(Swift.error)
//    case complete
//}

enum MyError: Error {
    case anError
}


example(of: "just, of, from") {
    // 1
    let one = 1
    let two = 2
    let three = 3

    //
    let observable = Observable<Int>.just(one)
    // <Int>
    let observable2 = Observable.of(one, two, three)
    // <[Int]>
    let observable3 = Observable.of([one, two, three])
    // same with observable2
    let observable4 = Observable.from([one, two, three])
    // Notification 和 Observable 的区别是什么?
    // 1. 用法 2. Observable 是懒加载的, 直到他有订阅者之前, 他不会产生数据
    // Observable 在形式上, 就是一个 Swift 标准库的 sequence. 订阅 更像是调用 next
}

example(of: "subscribe") {
    let one = 1
    let two = 2
    let three = 3

    let observable = Observable.of(one, two, three)
    // 调用 subscribe 就像是在 调用了 sequence 的 next 方法. 所以这种方式基本没啥用?
//    observable.subscribe{ event in
//        if let element = event.element {
//            print(element)
//        }
//    }
    observable.subscribe(onNext: { element in
        print(element)
    })
}

example(of: "empty") {
    //  就算是空,也要指定类型
    // 空 Observable 的作用, 是返回立即结束或者没有元素的 Observable 会比较方便
 
    let observable = Observable<Void>.empty()
    observable.subscribe(
        onNext: { element in
            
        },
        onCompleted: {
            print("Complete")
        }
    )
}

example(of: "never") {
    // the never operator creates an observable that doesn’t emit anything and never terminates
    // It can be use to represent an infinite duration.
    let observable = Observable<Void>.never()
    observable.do { _ in
        print("onNext")
    } afterNext: { _ in
        print("afterNext")
    } onError: { error in
        print("onError: \(error)")
    } afterError: { error in
        print("afterError: \(error)")
    } onCompleted: {
        print("onCompleted")
    } afterCompleted: {
        print("afterCompleted")
    } onSubscribe: {
        print("onSubscribe")
    } onSubscribed: {
        print("onSubscribed")
    } onDispose: {
        print("onDisposed")
    }
    .subscribe(
        onNext: { element in
            print(element)
        },
        onCompleted: {
            print("Complete")
        },
        onDisposed: {
            print("Disposed")
        }
    ).disposed(by: DisposeBag())
}

example(of: "debug") {
    let observable = Observable<Void>.never()
    observable.debug("Debuging", trimOutput: true)
        .subscribe {
            print("neven")
        } onError: { error in
            print("onError")
        } onCompleted: {
            print("onCompleted")
        } onDisposed: {
            print("onDisposed")
        }.disposed(by: DisposeBag())

}

example(of: "range") {
  // 1
  let observable = Observable<Int>.range(start: 1, count: 10)

  observable
    .subscribe(onNext: { i in
      // 2
      let n = Double(i)

      let fibonacci = Int(
        ((pow(1.61803, n) - pow(0.61803, n)) /
          2.23606).rounded()
      )

      print(fibonacci)
  })

}

example(of: "despose") {
    let observable = Observable<String>.of("A", "B", "C")
    
    let subscription = observable.subscribe(
        onNext: { element in
            print(element)
        },
        onCompleted: {
            print("Complete")
        }
    )
    print("Is that asynchrous?")
    subscription.dispose()
}

example(of: "DisposeBag") {
    let disposeBag = DisposeBag()
    // This is the pattern you’ll use most frequently: creating and subscribing to an observable, and immediately adding the subscription to a dispose bag.
    

    Observable.of("A", "B").subscribe(
        onNext: {
            print($0)
        },
        onCompleted: {
            print("Complete")
        }
    ).disposed(by: disposeBag)
}

example(of: "create") {
    let disposeBag = DisposeBag()
    Observable<String>.create { observer in
        // 还可以写成
        // observer.on(.next("1"))
        // 因为 observer 是一个枚举?
        observer.onNext("1")
        observer.onError(MyError.anError)
        observer.onCompleted()
        observer.onNext("?")
        return Disposables.create()
    }
    .subscribe(
        onNext: {
            print($0)
        },
        onError: {
            print($0)
        },
        onCompleted: {
            print("Complete")
        },
        onDisposed: {
            print("Dispose")
        }
    )
    .disposed(by: disposeBag)
    
}

example(of: "deferred") {
    let disposeBag = DisposeBag()

    // 1
    var flip = false

    // 2
    let factory: Observable<Int> = Observable.deferred {

        // 3
        flip.toggle()

        // 4
        if flip {
          return Observable.of(1, 2, 3)
        } else {
          return Observable.of(4, 5, 6)
        }
    }
    for _ in 0..<3 {
        factory.subscribe(
            onNext: {
                print($0, terminator: "")
            }
        )
        .disposed(by: disposeBag)
        print()
    }
    
}

example(of: "Single") {
    // disposeBag
    let disposeBag = DisposeBag()
    // error
    enum FileLoadingError: Error {
        case fileNotFound, unreadable, encodingFail
    }
    // load, 感觉把 Single 当成 Sequence 来理解好多了
    func loadFileContents(from name: String) -> Single<String> {
        return Single.create { single in
            // 1. dispose
            let dispose = Disposables.create()
            // 2. path
            guard let path = Bundle.main.path(forResource: name, ofType: "txt") else {
                single(.error(FileLoadingError.fileNotFound))
                return dispose
            }
            // 3. load data
            guard let data = FileManager.default.contents(atPath: path) else {
                single(.error(FileLoadingError.unreadable))
                return dispose
            }
            // 4. load content
            guard let contents = String(data: data, encoding: .utf8) else {
                single(.error(FileLoadingError.encodingFail))
                return dispose
            }
            single(.success(contents))
            return dispose
        }
    }
    
    loadFileContents(from: "Copyright")
        .subscribe{ content in
            switch content {
            case .success(let value):
                print(value)
            case .error(let error):
                print(error)
            }
        }
        .disposed(by: disposeBag)
}
