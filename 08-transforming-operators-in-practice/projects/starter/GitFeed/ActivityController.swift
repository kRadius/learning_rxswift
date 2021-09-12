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

import UIKit
import RxSwift
import RxCocoa
import Kingfisher

class ActivityController: UITableViewController {
  private let repo = "ReactiveX/RxSwift"
  
  private let events = BehaviorRelay<[Event]>(value: [])
  private let lastModified = BehaviorRelay<String?>(value: nil)
  private let bag = DisposeBag()
  
  private let eventsFileURL = cachedFileURL("events.json")
  private let modifiedFileURL = cachedFileURL("modified.txt")
  
  static func cachedFileURL(_ name: String) -> URL {
    return FileManager.default
      .urls(for: .cachesDirectory, in: .allDomainsMask)
      .first!
      .appendingPathComponent(name)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    title = repo
    
    self.refreshControl = UIRefreshControl()
    let refreshControl = self.refreshControl!
    
    refreshControl.backgroundColor = UIColor(white: 0.98, alpha: 1.0)
    refreshControl.tintColor = UIColor.darkGray
    refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
    refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
    
    let decoder = JSONDecoder()
    
    if let data = try? Data(contentsOf: eventsFileURL), let persistedEvents = try? decoder.decode([Event].self, from: data) {
      events.accept(persistedEvents)
    }
    
    if let data = try? String(contentsOf: modifiedFileURL, encoding: .utf8) {
      lastModified.accept(data)
    }
    
    tableView.reloadData()
    refresh()
  }
  
  @objc func refresh() {
    DispatchQueue.global(qos: .default).async { [weak self] in
      guard let self = self else { return }
//      self.fetchEvents(repo: self.repo)
      self.fetchEventChallenge(repo: self.repo)
    }
  }
  func fetchEventChallenge(repo: String) {
    
    let response = Observable.from(["https://api.github.com/search/repositories?q=language:swift&per_page=5"])
      .map { URL(string: $0)!}
      .map { URLRequest(url: $0) }
      .flatMap { request in
        URLSession.shared.rx.json(request: request)
      }
      // 如果要在 flatMap 里写其他的代码，需要明确一下返回类型
      .flatMap { response -> Observable<String> in
        guard let dict = response as? [String: Any],
              let items = dict["items"] as? [[String: Any]] else {
          return Observable.empty()
        }
        // 为什么我没有想到 Observable.from？所有的 items.full_name 不是数组么？不应该 Observable<[String]>
        // 因为忽略了 Observable 就是 sequence 啊！
        return Observable.from(items.map { $0["full_name"] as! String})
      }
      .map { urlString in
        return URL(string: "https://api.github.com/repos/\(urlString)/events")!
      }
      .map { [weak self] url -> URLRequest in
        var request = URLRequest(url: url)
        if let modifiedValue = self?.lastModified.value {
          request.addValue(modifiedValue, forHTTPHeaderField: "Last-Modified")
        }
        return request
      }
      .flatMap { request -> Observable<(response: HTTPURLResponse, data: Data)> in
        return URLSession.shared.rx.response(request: request)
      }
      .share(replay: 1)
    
    
    response.filter { response, _ in
      200...300 ~= response.statusCode
    }
    .compactMap { (response: HTTPURLResponse, data: Data) -> [Event]? in
      
      return try? JSONDecoder().decode([Event].self, from: data)
    }
    .subscribe(onNext: { [weak self] newEvents in
      self?.processEvents(newEvents)
    })
    .disposed(by: bag)
    
    response.filter { response, _ in
      return 200...400 ~= response.statusCode
    }
    .flatMap { (response: HTTPURLResponse, data: Data) -> Observable<String> in
      guard let value = response.allHeaderFields["Last-Modified"] as? String else {
        return Observable.empty()
      }
      return Observable.just(value)
    }
    .subscribe(onNext: { [weak self] modifiedHeader in
      guard let self = self else {
        return
      }
      self.lastModified.accept(modifiedHeader)
      try? modifiedHeader.write(to: self.modifiedFileURL, atomically: true, encoding: .utf8)
    })
    .disposed(by: bag)
    
  }
  func fetchEvents(repo: String) {
    let response = Observable.from([repo])
      .map { urlString in
        return URL(string: "https://api.github.com/repos/\(urlString)/events")!
      }
      .map { [weak self] url -> URLRequest in
        var request = URLRequest(url: url)
        if let modifiedValue = self?.lastModified.value {
          request.addValue(modifiedValue, forHTTPHeaderField: "Last-Modified")
        }
        return request
      }
      .flatMap { request -> Observable<(response: HTTPURLResponse, data: Data)> in
        return URLSession.shared.rx.response(request: request)
      }
      .share(replay: 1)
    // 此处为什么要 Share？
    // Share 的作用是为了避免创建重复的新的订阅，此处是为了避免重新发请求给服务器（啥？我就是想请求的怎么办）。
    // 加了 relay 之后，会缓存上一次 emit 出来的 event
    // 这样，如果有人订阅了 .share(replay: 1) 之后产生的 Observable， 就会立即得到上次的结果。当然你可以订阅 .share(replay: 1) 之后的 Observable
    
    //share(replay: 1, scope: xxx),
    // if xxx = .forever, 新的 subscribe 也会使用缓存
    // if xxx = .whileConnected, 在没有新的 subscriber 之前， 会一直使用
    
    //  那么什么时候需要用 share(replay: scope:)? 来避免创建多个 Observable
    // 1.前提：这个 Observerable 会 complte
    // 2. 这个 observerable 做的事情比较繁重（比如网络请求），而且会被订阅多次。
    // 3. 如果你想让订阅者知道前 n 次 emit 出来结果
    
    response.filter { response, _ in
      200...300 ~= response.statusCode
    }
    // map & filter {$0 != nil}
    // 这样写：1. 过滤了错误的 response 2. 过滤了空的 response 3. 在搞搞事情可以只输出最新的
    .compactMap { (response: HTTPURLResponse, data: Data) -> [Event]? in
      // 把 data 转换成 [Event].self 类型
      return try? JSONDecoder().decode([Event].self, from: data)
    }
    // Rxswfit 这种链式风格， 让你将原本离散的操作封装在了一起。另外还有个好处，你可以保证每个节点的输入输出都是有类型检查的
    .subscribe(onNext: { [weak self] newEvents in
      self?.processEvents(newEvents)
    })
    .disposed(by: bag)
    // 这时候 share(replay: scope:) 的作用就出现了， 他不会重新再发送一个请求
    response.filter { response, _ in
      return 200...400 ~= response.statusCode
    }
    .flatMap { (response: HTTPURLResponse, data: Data) -> Observable<String> in
      guard let value = response.allHeaderFields["Last-Modified"] as? String else {
        return Observable.empty()
      }
      return Observable.just(value)
    }
    .subscribe(onNext: { [weak self] modifiedHeader in
      guard let self = self else {
        return
      }
      self.lastModified.accept(modifiedHeader)
      try? modifiedHeader.write(to: self.modifiedFileURL, atomically: true, encoding: .utf8)
    })
    .disposed(by: bag)
  }
  
  func processEvents(_ newEvents: [Event]) {
    // 拿到了数据我要存起来， 怎么把 sequences 直接 bind 到 subjects？ relay 的 accept
    var updateEvents = newEvents + events.value
    if updateEvents.count > 50 {
      // 取前面 50 个
      updateEvents = [Event](updateEvents.prefix(upTo: 50))
    }
    events.accept(newEvents)
    DispatchQueue.main.async {
      self.tableView.reloadData()
      self.refreshControl?.endRefreshing()
    }
    let jsonEncoder = JSONEncoder()
    if let eventData = try? jsonEncoder.encode(updateEvents) {
      try? eventData.write(to: eventsFileURL, options: .atomicWrite)
    }
  }
  
  // MARK: - Table Data Source
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return events.value.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let event = events.value[indexPath.row]
    
    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!
    cell.textLabel?.text = event.actor.name
    cell.detailTextLabel?.text = event.repo.name + ", " + event.action.replacingOccurrences(of: "Event", with: "").lowercased()
    cell.imageView?.kf.setImage(with: event.actor.avatar, placeholder: UIImage(named: "blank-avatar"))
    return cell
  }
}
