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

import Foundation

import RxSwift
import RxCocoa
import RxRealm

import RealmSwift
import Reachability
import Unbox
///“The class TimelineFetcher in TimelineFetcher.swift is responsible to automatically refetch the latest tweets while the app is connected”

class TimelineFetcher {

  private let timerDelay = 30
  private let bag = DisposeBag()
  private let feedCursor = BehaviorRelay<TimelineCursor>(value: .none)

  // MARK: input
  let paused = BehaviorRelay<Bool>(value: false)

  // MARK: output
  let timeline: Observable<[Tweet]>
  // MARK: Init with list or user

  //provide list id to fetch list's tweets
  convenience init(account: Driver<TwitterAccount.AccountStatus>, list: ListIdentifier, apiType: TwitterAPIProtocol.Type) {
    self.init(account: account, jsonProvider: apiType.timeline(of: list))
  }

  //provide username to fetch user's tweets
  convenience init(account: Driver<TwitterAccount.AccountStatus>, username: String, apiType: TwitterAPIProtocol.Type) {
    self.init(account: account, jsonProvider: apiType.timeline(of: username))
  }
  // 这个 jsonprovier 其实是给 flatMapLatest 用的。
  // 上面不同的 convenience 是暴露给不同的 API 请求调用的，这样避免了在 init 方法里 做 if else
  private init(account: Driver<TwitterAccount.AccountStatus>,
               jsonProvider: @escaping (AccessToken, TimelineCursor) -> Observable<[JSONObject]>) {
    //
    // subscribe for the current twitter account
    //
    let currentAccount: Observable<AccessToken> = account
      .filter { account in
        switch account {
        case .authorized: return true
        default: return false
        }
      }
      .map { account -> AccessToken in
        switch account {
        case .authorized(let acaccount):
          return acaccount
        default: fatalError()
        }
      }
      .asObservable()

    // timer that emits a reachable logged account
    let reachableTimerWithAccount = Observable.combineLatest(
      // 定时触发拉取的任务
      // 所以结构上， viewModel 负责逻辑，发起网络请求的 Fetecher + TwitterAPI
      Observable<Int>.timer(.seconds(0), period: .seconds(timerDelay), scheduler: MainScheduler.instance),
      Reachability.rx.reachable,
      currentAccount,
      paused.asObservable(),
      resultSelector: { _, reachable, account, paused in
        return (reachable && !paused) ? account : nil
      })
      .filter { $0 != nil }
      .map { $0! }

    let feedCursor = BehaviorRelay<TimelineCursor>(value: .none)

    // Re-fetch the timeline
    // 以 reachableTimerWithAccount（r） 为基准，当 r emit 的时候，看一下 from（x） x 最新的是啥
    // 这里的意思是：每次可以触发请求时候，检查一下 feedCursor 最新的什么
    // 为什么不能用 combineLatest？因为优先级问题吧，要时刻以 r 为准。combineLatest 是双方任意一方 emit 都能触发
    timeline = reachableTimerWithAccount.withLatestFrom(feedCursor.asObservable()) { account, cursor in
      return (account: account, cursor: cursor)
    }
    .flatMapLatest(jsonProvider)
    .map(Tweet.unboxMany)
    .share(replay: 1)

    // Store the latest position through timeline
    // 每次 timeline 请求回来了，记录一下 cursor
    timeline.scan(.none) { cursor, tweets in
      TimelineFetcher.currentCursor(lastCursor: cursor, tweets: tweets)
    }
    .bind(to: feedCursor)
    .disposed(by: bag)
  }

  static func currentCursor(lastCursor: TimelineCursor, tweets: [Tweet]) -> TimelineCursor {
    return tweets.reduce(lastCursor) { status, tweet in
      let max: Int64 = tweet.id < status.maxId ? tweet.id-1 : status.maxId
      let since: Int64 = tweet.id > status.sinceId ? tweet.id : status.sinceId
      return TimelineCursor(max: max, since: since)
    }
  }
}
