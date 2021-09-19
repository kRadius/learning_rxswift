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

class EONET {
  static let API = "https://eonet.sci.gsfc.nasa.gov/api/v2.1"
  static let categoriesEndpoint = "/categories"
  static let eventsEndpoint = "/events"

  static func jsonDecoder(contentIdentifier: String) -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.userInfo[.contentIdentifier] = contentIdentifier
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }

  static func filteredEvents(events: [EOEvent], forCategory category: EOCategory) -> [EOEvent] {
    return events.filter { event in
      return event.categories.contains(where: { $0.id == category.id }) && !category.events.contains {
        $0.id == event.id
      }
      }
      .sorted(by: EOEvent.compareDates)
  }
  
  static func request<T: Decodable>(endpoint: String, query: [String : Any] = [:], contentIdentifier: String) -> Observable<T> {
    do {

      guard let url = URL(string: API)?.appendingPathComponent(endpoint), var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
       throw EOError.invalidURL(endpoint)
      }
      components.queryItems = try query.compactMap({ (key: String, value: Any) in
        guard let v = value as? CustomStringConvertible else {
          throw EOError.invalidParameter(key, value)
        }
        return URLQueryItem(name: key, value: v.description)
      })
      guard let finalURL = components.url else {
        throw EOError.invalidURL(endpoint)
      }
      
      let request = URLRequest(url: finalURL)
      
      return URLSession.shared.rx.response(request: request)
        .map { (response: HTTPURLResponse, data: Data) in
          let decoder = self.jsonDecoder(contentIdentifier: contentIdentifier)
          let envelope = try decoder.decode(EOEnvelope<T>.self, from: data)
          return envelope.content
        }
    } catch {
      return Observable.empty()
    }
  }

  static var categories: Observable<[EOCategory]> = {
    let request: Observable<[EOCategory]> = EONET.request(endpoint: categoriesEndpoint, contentIdentifier: "categories")
    
    return request.map { categories in
      categories.sorted { $0.name < $1.name }
    }
    .catchErrorJustReturn([])
    .share(replay: 1, scope: .forever)
    
    // 这里为什么用 share(replay: 1, scope: .forever)
    // 因为 categories 是一个单例，所有的订阅都应该返回同一个结果。
    // share(replay: 1, scope: .forever)，就会 relay 第一个 订阅着的结果，而不会重新请求 data
  }()
  
  private static func events(forLast days: Int, closed: Bool, endPoint: String) -> Observable<[EOEvent]> {
    let query: [String: Any] = [
      "days" : days,
      "status": (closed ? "closed" : "open")
    ]
    
    let request: Observable<[EOEvent]> = EONET.request(endpoint: endPoint, query: query, contentIdentifier: "events")
    return request.catchErrorJustReturn([])
  }
  
//  static func events(forLast days: Int = 360) -> Observable<[EOEvent]> {
//    let openEvents = events(forLast: days, closed: false)
//    let closeEvents = events(forLast: days , closed: true)
//    // contact 做了什么？
//    // 创建了一个新的 observable，首先运行 openEvents 到完成。 然后订阅 closeEvents，直到结束。
//    // 最后 relay 所有的他们俩 emits 出来的 events。 一旦有任意一个 error 发生，  relay it and terminate
//    // 但是这种做法， 要求 openEvents 先执行完成(onCompleted)，然后才是 closeEvents，这是个串行的过程
//    // 最合适的办法， 应该是 merge ，并行请求，然后 merge 一下结果， 和 contact 一样
//    // 参考下面的方法
//    return openEvents.concat(closeEvents)
//  }
  
  static func events(forLast days: Int = 360, category: EOCategory) -> Observable<[EOEvent]> {
    let openEvents = events(forLast: days, closed: false, endPoint: category.endpoint)
    let closeEvents = events(forLast: days , closed: true, endPoint: category.endpoint)
    
    return Observable.of(openEvents, closeEvents)
      .merge()
      .reduce([]) { running, newEvent in
        // running 取的很精髓，因为无论谁先回来都可以
        running + newEvent
      }
  }
  
}
