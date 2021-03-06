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
// ???The compactMap operator is a combination of the map and filter operators that specifically filters out nil values, similarly to its counterpart in the Swift standard library???

example(of: "compactMap") {
    let disposeBag = DisposeBag()
    Observable.of("To", "be", nil, "or", "not", "to", "be", nil)
        .compactMap { x in
            // ??? map??? ?????????????????????????????? filter?????????????????? nil            
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

// flatMap ????????????Observable??? ????????? Observable ??? Value??? ????????? flat ??????
// ???To recap, flatMap projects and transforms an observable value of an observable, and then flattens it down to a target observable.???

example(of: "flattenMap") {
    let disposeBag = DisposeBag()
    let lura = Student(score: BehaviorSubject<Int>(value: 80))
    let jane = Student(score: BehaviorSubject<Int>(value: 90))
    
    let student = PublishSubject<Student>()
    
    
    student
//        .debug()
        .flatMap { student in
            // ??????????????????????????????????????????????????????
            return student.score
        }
        .subscribe(onNext: { score in
            print(score)
        })
        .disposed(by: disposeBag)
    
    student.onNext(lura)
    // ????????????????????????
    lura.score.onNext(85)
    student.onNext(jane)
    // ?????????????????? lura ???, ????????????????????????
    // ??????????????? student.onNext(jane)??? ????????? lura ???????????????
    // ?????? ???To recap, flatMap keeps projecting changes from each observable. ???
    // flatMap ?????????????????? Observable???????????????
    lura.score.onNext(96)
    jane.score.onNext(100)
    
    // ??????????????? onNext ??????????????????????????????????????? Observable ???????????? ????????? flatMapLatest
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
    // 82 ???????????????
    lura.score.onNext(82)
    jane.score.onNext(91)
    jane.score.onNext(92)
    // ??????????????????????????? flatMapLatest ??????????????? flatMap ??????
    // Network ???????????????????????????????????????????????? ????????????????????????????????????
    // ????????????
}


example(of: "materialize and dematerialize 1") {
    enum MyError : Error {
        case anError
    }
    
    let disposeBag = DisposeBag()
    
    let lura = Student(score: BehaviorSubject(value: 80))
    let jane = Student(score: BehaviorSubject(value: 90))
    
    let student = BehaviorSubject(value: lura)
    // ?????? flatMapLatest ??????????????? ?????? student score ?????? observable
    let studentScore = student
//        .debug()
        .flatMapLatest {
//            $0.score // => studentScore ???????????? Obsrevable<Int>
            $0.score.materialize() // => studentScore ???????????? Obsrevable<Event<Int>>
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
    // ?????? observable ?????????????????????, studentScore ???????????????????????????completed/error???.
    // ??????????????? ????????? Stuent ?????????????????????????????????????????? flatMapLatest ?????????????????????????????? map ???????????? ?????????????????? materialize
    // ?????? materialize ??????????????????????????????????????????????????????????????????????????????????????????????????????
    // ???????????? Student
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
            $0.score.materialize() // => studentScore ???????????? Obsrevable<Event<Int>>
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
    // lura ??? score ?????? subject ?????? ternimated ?????? ?????????????????? 82 ???
    lura.score.onNext(82)
    
    // 4
    student.onNext(jane)
}

example(of: "Challenge 1") {
    let disposeBag = DisposeBag()
    
    let contacts = [
        "603-555-1212": "Florent",
        "212-555-1212": "Shai",
        "408-555-1212": "Marin",
        "617-555-1212": "Scott"
    ]
    
    let convert: (String) -> Int? = { value in
        if let number = Int(value),
           number < 10 {
            return number
        }
        
        let keyMap: [String: Int] = [
            "abc": 2, "def": 3, "ghi": 4,
            "jkl": 5, "mno": 6, "pqrs": 7,
            "tuv": 8, "wxyz": 9
        ]
        
        let converted = keyMap
            .filter { $0.key.contains(value.lowercased()) }
            .map(\.value)
            .first
        
        return converted
    }
    
    let format: ([Int]) -> String = {
        var phone = $0.map(String.init).joined()
        
        phone.insert("-", at: phone.index(
                        phone.startIndex,
                        offsetBy: 3)
        )
        
        phone.insert("-", at: phone.index(
                        phone.startIndex,
                        offsetBy: 7)
        )
        
        return phone
    }
    
    let dial: (String) -> String = {
        if let contact = contacts[$0] {
            return "Dialing \(contact) (\($0))..."
        } else {
            return "Contact not found"
        }
    }
    
    let input = PublishSubject<String>()
    
    // 1.Use multiple maps to perform each transformation along the way.
    // 2.Use skipWhile just like you did in Chapter 5 to skip 0s at the beginning.
    // 3.Handle the optionals returned from convert.
    
    
    //    ???Your goal for this challenge is to modify this implementation to be able to take letters as well, and convert them to their corresponding number based on a standard phone keypad (abc is 2, def is 3, and so on).???
    
    // Add your code here
    input.asObservable()
//        .debug()
        .map { convert($0) }
        .filter { $0 != nil}
        .map { $0! }
        .skipWhile { $0 == 0 }
        .take(10)
        .toArray()// Converts an Observable into a Single that emits the whole sequence as a single array and then terminates.
        .map { format($0) }
        .map {
            print($0)
            return dial($0)
        }
        .subscribe (
            onSuccess: { str in
                print(str)
            }, onError: { error in

            }
        )
        .disposed(by: disposeBag)
    
    // ????????????
//    input.asObservable()
//        .map(convert)
//        .filter { $0 != nil}
//        .map { $0! }
//        .skipWhile { $0 == 0 }
//        .take(10)
//        .toArray()
//        .map(format)
//        .map(dial)
//        .subscribe(onSuccess: {
//          print($0)
//        })
//        .disposed(by: disposeBag)
    
    input.onNext("???")
    input.onNext("0")
    input.onNext("408")
    
    input.onNext("6")
    input.onNext("???")
    input.onNext("0")
    input.onNext("3")
    
    "JKL1A1B".forEach {
        input.onNext("\($0)")
    }
    
    input.onNext("9")
}
