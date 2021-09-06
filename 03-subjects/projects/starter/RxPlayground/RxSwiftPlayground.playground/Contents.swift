import Foundation
import RxSwift
import RxRelay



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

example(of: "Publish Subject") {
    let subject = PublishSubject<String>()

    subject.on(.next("news"))
    let subscriptionOne = subject
      .subscribe(onNext: { string in
        print("1)", string)
      })
    
    subject.on(.next("1"))
    subject.onNext("2")

    let subscribeTwo = subject.subscribe { event in
        print("2)", event.element ?? event)
    }
    subject.onNext("3")
    // subscriptionOne terminate
    subscriptionOne.dispose()

    subject.onNext("4")
    // 为什么 这个 onCompleted 消息, 还没监听的 3) 也能收到
    //  However, it will re-emit its stop event to future subscribers
    // 也合理, 告诉后面的监听者, 别监听了, 我结束了
    subject.onCompleted()
    
    subject.on(.next("5"))
    
    subscriptionOne.dispose()
    
    let disposeBag = DisposeBag()
    
    subject.subscribe{
        print("3)", $0.element ?? $0)
    }.disposed(by: disposeBag)
    
    subject.subscribe{
        print("4)", $0.element ?? $0)
    }.disposed(by: disposeBag)
    
    subject.onNext("?")

}

enum MyError: Error {
    case anError
}
func print<T: CustomStringConvertible>(label: String, event: Event<T>) {
    print(label, (event.element ?? event.error) ?? event)
}

example(of: "BehaviorSubject") {
    // 因为 Behavior 总是需要提供最新的 onNext, 所以需要提供一个默认值
    // 如果你不想提供, 那么意味着你可能不需要 BehaviorSubject, PublichSubject 就行
    let subject = BehaviorSubject<String>(value: "Initial Value")
    let disposeBag = DisposeBag()
    
    subject.onNext("1")
    subject.subscribe { event in
        print(label: "1)", event: event)
    }.disposed(by: disposeBag)
    
    subject.onError(MyError.anError)
    
    subject.subscribe {
        print(label: "2)", event: $0)
    }
}

example(of: "ReplaySubject") {
    let subject = ReplaySubject<String>.create(bufferSize: 2)
    let disposeBag = DisposeBag()
    
    subject.onNext("1")
    subject.onNext("2")
    subject.onNext("3")
    
    subject.subscribe {
        print(label: "1)", event: $0)
    }.disposed(by: disposeBag)
    
    
    subject.subscribe {
        print(label: "2)", event: $0)
    }.disposed(by: disposeBag)
    
    subject.onNext("4")
    subject.onError(MyError.anError)
    // subject.dispose()
    // 在没有 dipose 之前, 会先重放 <=2 个, 然后在接受 error. 可以让你知道发生错误之前, 最后的状态是啥
    // 如果 dispose 了, 那么会报错
    // Object `RxSwift.(unknown context at $10a297990).ReplayMany<Swift.String>` was already disposed.
    subject.subscribe {
        print(label: "3)", event: $0)
    }.disposed(by: disposeBag)
}


example(of: "PublishRelay") {
    let relay = PublishRelay<String>()
    let disposeBag = DisposeBag()
    
    relay.accept("knock knock, anyone home?")
    
    relay.subscribe {
        print(label: "1)", event: $0)
    }.disposed(by: disposeBag)
    
    relay.accept("1")
    
}

example(of: "BehaviorRelay") {
    let relay = BehaviorRelay<String>.init(value: "Initial Value")
    let disposeBag = DisposeBag()
    
    relay.accept("New initial value")
    
    relay.subscribe { event in
        print(label: "1)", event: event)
    }.disposed(by: disposeBag)
    
    relay.accept("1")
    
    relay.subscribe{ event in
        print(label: "2)", event: event)
    }.disposed(by: disposeBag)
    
    relay.accept("2")
    
    print(relay.value)
}


example(of: "Challenge1") {
    let disposeBag = DisposeBag()

    let dealtHand = PublishSubject<[(String, Int)]>()

    func deal(_ cardCount: UInt) {
        var deck = cards
        var cardsRemaining = deck.count
        var hand = [(String, Int)]()

        for _ in 0..<cardCount {
            let randomIndex = Int.random(in: 0..<cardsRemaining)
            hand.append(deck[randomIndex])
            deck.remove(at: randomIndex)
            cardsRemaining -= 1
        }
      
      // Add code to update dealtHand here
      // evaluate the result returned from calling points(for:), passing the hand array.
        let points = points(for: hand)
        if points > 21 {
            dealtHand.onError(HandError.busted(points: points))
        } else {
            dealtHand.onNext(hand)
        }
        
    }
    
    // Add subscription to dealtHand here
    dealtHand.subscribe(
        onNext: { value in
            print(cardString(for: value))
            print(points(for: value))
        },
        onError: { error in
            print("Error", error)
        }
    ).disposed(by: disposeBag)
    
    deal(3)
}

example(of: "Change 2") {
    enum UserSession {
        case loggedIn, loggedOut
    }

    enum LoginError: Error {
        case invalidCredentials
    }

    let disposeBag = DisposeBag()

    // Create userSession BehaviorRelay of type UserSession with initial value of .loggedOut
    let userSessionRelay = BehaviorRelay<UserSession>.init(value: .loggedOut)
    // Subscribe to receive next events from userSession
    userSessionRelay.subscribe { event in
        print("Log:", event)
    }.disposed(by: disposeBag)
    func logInWith(username: String, password: String, completion: (Error?) -> Void) {
        guard username == "johnny@appleseed.com",
              password == "appleseed" else {
            completion(LoginError.invalidCredentials)
            return
        }

        // Update userSession
        userSessionRelay.accept(.loggedIn)
    }

    func logOut() {
        // Update userSession
        userSessionRelay.accept(.loggedOut)
    }

    func performActionRequiringLoggedInUser(_ action: () -> Void) {
        // Ensure that userSession is loggedIn and then execute action()
        guard .loggedIn == userSessionRelay.value else {
            return
        }
        action()
    }

    for i in 1...2 {
        let password = i % 2 == 0 ? "appleseed" : "password"

        logInWith(username: "johnny@appleseed.com", password: password) { error in
            guard error == nil else {
                print(error!)
                return
            }
      
            print("User logged in.")
        }

        performActionRequiringLoggedInUser {
          print("Successfully did something only a logged in user can do.")
        }
    }
}
