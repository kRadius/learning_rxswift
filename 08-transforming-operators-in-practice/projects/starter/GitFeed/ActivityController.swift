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
      // ???????????? flatMap ??????????????????????????????????????????????????????
      .flatMap { response -> Observable<String> in
        guard let dict = response as? [String: Any],
              let items = dict["items"] as? [[String: Any]] else {
          return Observable.empty()
        }
        // ???????????????????????? Observable.from???????????? items.full_name ??????????????????????????? Observable<[String]>
        // ??????????????? Observable ?????? sequence ??????
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
    // ?????????????????? Share???
    // Share ???????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
    // ?????? relay ??????????????????????????? emit ????????? event
    // ?????????????????????????????? .share(replay: 1) ??????????????? Observable??? ????????????????????????????????????????????????????????? .share(replay: 1) ????????? Observable
    
    //share(replay: 1, scope: xxx),
    // if xxx = .forever, ?????? subscribe ??????????????????
    // if xxx = .whileConnected, ??????????????? subscriber ????????? ???????????????
    
    //  ??????????????????????????? share(replay: scope:)? ????????????????????? Observable
    // 1.??????????????? Observerable ??? complte
    // 2. ?????? observerable ??????????????????????????????????????????????????????????????????????????????
    // 3. ????????????????????????????????? n ??? emit ????????????
    
    response.filter { response, _ in
      200...300 ~= response.statusCode
    }
    // map & filter {$0 != nil}
    // ????????????1. ?????????????????? response 2. ??????????????? response 3. ???????????????????????????????????????
    .compactMap { (response: HTTPURLResponse, data: Data) -> [Event]? in
      // ??? data ????????? [Event].self ??????
      return try? JSONDecoder().decode([Event].self, from: data)
    }
    // Rxswfit ????????????????????? ?????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
    .subscribe(onNext: { [weak self] newEvents in
      self?.processEvents(newEvents)
    })
    .disposed(by: bag)
    // ????????? share(replay: scope:) ???????????????????????? ????????????????????????????????????
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
    // ????????????????????????????????? ????????? sequences ?????? bind ??? subjects??? relay ??? accept
    var updateEvents = newEvents + events.value
    if updateEvents.count > 50 {
      // ????????? 50 ???
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
