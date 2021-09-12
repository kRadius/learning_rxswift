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


example(of: "ToArray") {
    let disposeBag = DisposeBag()
    Observable.of("1", "2", "3")
        .toArray()
        .subscribe (onSuccess: {
            print($0)
        })
        .disposed(by: disposeBag)
}

example(of: "Map") {
    let disposeBag = DisposeBag()
    let formatter = NumberFormatter()
    formatter.numberStyle = .spellOut
    
    Observable.of(123, 4, 56)
        .map { x in
            formatter.string(for: x) ?? ""
        }
        .subscribe (onNext: {
            print($0)
        })
        .disposed(by: disposeBag)
}

example(of: "emurated") {
    let disposeBag = DisposeBag()
    
    Observable.of(1, 2, 3, 4, 5, 6)

        .enumerated()
        .map { index, value in
            index > 2 ? value * 2 : value
        }
        .subscribe(onNext: {
            print($0)
        })
        .disposed(by: disposeBag)
}
// “The compactMap operator is a combination of the map and filter operators that specifically filters out nil values, similarly to its counterpart in the Swift standard library”

example(of: "compactMap") {
    let disposeBag = DisposeBag()
    Observable.of("To", "be", nil, "or", "not", "to", "be", nil)
        .compactMap { x in
            // 先 map， 然后后面有一个默认的 filter，判断是否为 nil            
            x
        }
        .toArray()
        .map { value in
            value.joined(separator: " ")
        }
        .subscribe(onSuccess: {
            print($0)
        })
        .disposed(by: disposeBag)
}

struct Student {
    let score: BehaviorSubject<Int>
}

// flatMap 输入是：Observable， 输出是 Observable 的 Value。 所以叫 flat 拍平
// “To recap, flatMap projects and transforms an observable value of an observable, and then flattens it down to a target observable.”

example(of: "flattenMap") {
    let disposeBag = DisposeBag()
    let lura = Student(score: BehaviorSubject<Int>(value: 80))
    let jane = Student(score: BehaviorSubject<Int>(value: 90))
    
    let student = PublishSubject<Student>()
    
    
    student
        .debug()
        .flatMap { student in
            // 这里为什么连打印语句都不能写？？？？
            return student.score
        }
        .subscribe(onNext: { score in
            print(score)
        })
        .disposed(by: disposeBag)
    
    student.onNext(lura)
    // 外部可以监听变化
    lura.score.onNext(85)
    student.onNext(jane)
    // 这个时候改变 lura 的, 依旧可以监听到？
    // 这是为什么 student.onNext(jane)， 取消对 lura 的监听么？
    // 因为 “To recap, flatMap keeps projecting changes from each observable. ”
    // flatMap 会持续从每个 Observable，投射变化
    lura.score.onNext(96)
    jane.score.onNext(100)
    
    // 如果你想让 onNext 的时候，真正的取消了上一个 Observable 的监听， 需用用 flatMapLatest
    // flatMapLatest = map + switchLatest
}

example(of: "FlatMap Latest") {
    let disposeBag = DisposeBag()
    let lura = Student(score: BehaviorSubject(value: 80))
    let jane = Student(score: BehaviorSubject(value: 90))
    
    let student = PublishSubject<Student>()
    
    student
        .flatMapLatest {
            $0.score
        }
        .subscribe(onNext: { score in
            print(score)
        })
        .disposed(by: disposeBag)
    
    student.onNext(lura)
    
    lura.score.onNext(81)
    student.onNext(jane)
    // 82 将会收不到
    lura.score.onNext(82)
    jane.score.onNext(91)
    jane.score.onNext(92)
    // 那么什么时候可以用 flatMapLatest 什么使用用 flatMap 呢？
    // Network 是最典型的场景，一个请求发出去， 应该取消上一个请求的监听
    // 搜索也是
}


example(of: "materialize and dematerialize 1") {
    enum MyError : Error {
        case anError
    }
    
    let disposeBag = DisposeBag()
    
    let lura = Student(score: BehaviorSubject(value: 80))
    let jane = Student(score: BehaviorSubject(value: 90))
    
    let student = BehaviorSubject(value: lura)
    // 创建 flatMapLatest 的作用是， 获取 student score 这个 observable
    let studentScore = student
//        .debug()
        .flatMapLatest {
//            $0.score // => studentScore 的类型是 Obsrevable<Int>
            $0.score.materialize() // => studentScore 的类型是 Obsrevable<Event<Int>>
        }
        
    studentScore
        .subscribe(onNext: {
                print($0)
            }, onError: { error in
                print(error)
            }
        )
        .disposed(by: disposeBag)
    // 3
    lura.score.onNext(81)
    // 如果 observable 发出了一个错误, studentScore 的状态就是终止了（completed/error）.
    // 与此同时， 还会把 Stuent 也给干没了（？为什么，应该是 flatMapLatest 的时候，错误事件一样 map 了？）。 所以需要使用 materialize
    // 使用 materialize 操作符，你可以将一个可观察对象发出的每个事件包装在一个可观察对象中。
    // 这个时候 Student
    lura.score.onError(MyError.anError)
    lura.score.onNext(82)
    
    // 4
    student.onNext(jane)
}

example(of: "materialize and dematerialize ") {
    enum MyError : Error {
        case anError
    }
    
    let disposeBag = DisposeBag()
    
    let lura = Student(score: BehaviorSubject(value: 80))
    let jane = Student(score: BehaviorSubject(value: 90))
    
    let student = BehaviorSubject(value: lura)

    let studentScore = student
        .flatMapLatest {
            $0.score.materialize() // => studentScore 的类型是 Obsrevable<Event<Int>>
        }
        
    studentScore
        .filter({ event in
            guard event.error == nil else {
                print(event.error!)
                return false
            }
            return true
        })
        .dematerialize()
        .subscribe(onNext: {
                print($0)
            }, onError: { error in
                print(error)
            }
        )
        .disposed(by: disposeBag)
    // 3
    lura.score.onNext(81)
    lura.score.onError(MyError.anError)
    // lura 的 score 这个 subject 已经 ternimated 了， 所以不会打印 82 了
    lura.score.onNext(82)
    
    // 4
    student.onNext(jane)
}


