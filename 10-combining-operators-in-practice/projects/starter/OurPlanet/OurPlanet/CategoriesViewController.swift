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

class CategoriesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

  @IBOutlet var tableView: UITableView!
  private let indicator = UIActivityIndicatorView(style: .gray)
  private let downloadView = DownloadView()

  let disposeBag = DisposeBag()
  // 每次订阅这个 relay，都会重新触发 tableView 的 update，当有新的数据 arrival 的时候
  // 这个东西一般都是用来做数据源
  let categories = BehaviorRelay<[EOCategory]>(value: [])
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // 为什么要 asObservable, categories 不是能够直接监听么？
    // 这应该是一个比较好的习惯：如果把原先的 observable 返回回去， 如果是 subject 或者是 relay， 外部就可以触发他们的 onNext 或者是说 accept 方法
    // 这种写法可以隐藏 source sequence
    categories.asObservable()
      .subscribe(onNext: { [weak self] _ in
        DispatchQueue.main.async {
          self?.tableView.reloadData()
        }
      }, onDisposed: {
        print("disposed")
      })
      .disposed(by: disposeBag)

    self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: indicator)
    indicator.startAnimating()
    
    
    view.addSubview(downloadView)
    view.layoutIfNeeded()
    
    startDownload()
  }

  func startDownload() {
    
    // challenge1: 在 右上角添加 indicator，表示还在下载
    // challenge2: 在 view 的底部，添加上一个下载的状态，标志当前的下载进度
    
    
    let eoCategories = EONET.categories
    // 第一版代码:  直接拉去过去 360 所有的 open 和 close 事件
    // let downloadedEvents = EONET.events(forLast: 360)
//    //“bind(to:) connects a source observable (EONET.categories) to an observer (the categories relay).”
//    // 这个应该是单向的绑定， 绑定有意味着什么？
//    eoCategories.bind(to: categories).disposed(by: disposeBag)
    
    // 第二版代码
    // 需求：并发下载每一个 Category 数据。第一版的时候， 是先下载 Category， 然后在一个请求里下载所有的 Category 数据
    // 为什么用 flatMap？
    // flatMap 的作用是把一个 包装的 Observable 的值取出来，之后你可以用它的值转换成另外一个东西
    // 比如 Observable<Observable<Int>> -> Int
    
    // 在这里输入 Observable<[EOCategory]> 输出 Observable<Observable<[Event]>>
    // 为什么不能用 map？
    // map 是对 sequence 里的每一个元素做一次变化，最后还是返回原来的类型。这里使用 map
    // 结果会变成 输入 Observable<[EOCategory]> 输出 Observable<Observable<Observable<[EOEvent]>>>
    
    let downloadEvents = eoCategories.flatMap { categories -> Observable<Observable<[EOEvent]>> in
      // Observable.from() 把传入的 元素 x，变成了一个 Observable<[x]>
      // 此处，根据每一个 Category，map 成了 EOEvent 下载事件 Observable<[EOEvent]>
      // 所以变成了 Observable<Observable<[EOEvent]>>
      return Observable.from( categories.map({ category -> Observable<[EOEvent]> in
        EONET.events(forLast: 360, category: category)
      }))
    }
    // 这里 merge 是什么意思？哪里有多个 source 可以 merge
    // 上面一大串的操作，返回值是 Observable<Observable<[EOEvent]>>
    // merge 之后变成了 Observable<[EOEvent]>, 为什么是这样？
    // Observable<Observable<[EOEvent]>>，当成数组理解就好了。 这是个二级数组， 数组里的每一个元素回来之后，都要 relay 一次。
    // 最终的效果： 25 的 categries，每一个 Category 都会去请求 open和 close 的 events （在 EONET.events 里）
    // 所以一下  50 个 API 请求就发出去了。这个有点儿太多，所以我们可以使用 merge 来控制一下最大的并发数量
    // 到达了最大的数量之后， 后面就会进入排队，
    .merge(maxConcurrent: 2)

    
    // 第一版代码
    // 直接拉去过去 360 所有的 open 和 close 事件
//    // 需求是先下载 category， 然后展示出来， 接着去下载每一个 category 里的数据。 保证用户体验。
//    // 可以在 combineLatest 的 map 里，返回 combine 之后的类型
//    let updateCategories = Observable
//      .combineLatest(eoCategories, downloadEvents) { (categories, events) -> [EOCategory] in
//        return categories.map { category in
//          var cat = category
//          cat.events = events.filter({ event in
//            event.categories.contains(where: { $0.id == category.id })
//          })
//          return cat
//        }
//    }
    
    
    // 第二版代码
    let updateCategories = eoCategories.flatMap { categories -> Observable<(Int, [EOCategory])> in
      // scan 也是累积总和，但是每一次 source emit element 时候，都会调用 closure, 并且向 closure 传入 累积的值 updated
      // 目的：每一个下载请求回来的时候， 都需要累积更新的 category
      return downloadEvents.scan((0, categories)) { tuple, events -> (Int, [EOCategory]) in
        // challenge 2 解法 1 - 直接让 scan 返回一个元组， 然后在 do(onNext：) 里操作
        // : 为什么这里是 加 1？因为这里是 downloadEvents，记录的是请求回来的数量。不用记录 event 的数量， 只需要记录 请求回来的数量，和 category 总数就行
        return (tuple.0 + 1, tuple.1.map { category -> EOCategory in
            let eventFactory = EONET.filteredEvents(events: events, forCategory: category)
            if !eventFactory.isEmpty {
              var cat = category
              cat.events = category.events + eventFactory
              return cat
            }
            return category
          }// end map
        )// end tuple
      }// end scan
    }// end flatMap
    // challenge
    .do(
      onNext: { [weak self] tuple in
        DispatchQueue.main.async {
          let progress = Float(tuple.0) / Float(tuple.1.count)
          self?.downloadView.progress.progress = progress
          let percent = Int(progress * 100)
          self?.downloadView.textLabel.text = "Download: \(percent)%"
        }
      },
      onCompleted: {
        DispatchQueue.main.async { [weak self] in
          self?.indicator.stopAnimating()
          self?.downloadView.isHidden = true
        }
        print("onComplete")
      })
    
//    // challange 2 解法二：新建一个 flatMap ( 需要复原解法1修改的元组)
//    // 原先长这样：
//    let originUpdatedCategories = eoCategories.flatMap { categories in
//          downloadEvents.scan(categories) { updated, events in
//            return updated.map { category in
//              let eventsForCategory = EONET.filteredEvents(events: events, forCategory: category)
//              if !eventsForCategory.isEmpty {
//                var cat = category
//                cat.events = cat.events + eventsForCategory
//                return cat
//              }
//              return category
//            }
//          }
//    }
//    eoCategories.flatMap { categories -> Observable<(Int, Int)> in
//      return originUpdatedCategories.scan(0) { count, _ -> Int in
//        return count + 1
//      }
//      // start with 0 是为了初始进度
//      .startWith(0)
//      .map { ($0, categories.count) }
//    }
//    .subscribe(onNext: {[weak self] tuple in
//      DispatchQueue.main.async {
//        let progress = Float(tuple.0) / Float(tuple.1)
//        self?.downloadView.progress.progress = progress
//        let percent = Int(progress * 100)
//        self?.downloadView.textLabel.text = "Download: \(percent)%"
//      }
//    })
//    .disposed(by: disposeBag)
    
    // 第一版注释：
    // 结果上， 我是需要 类目以及后面的具体 Events. 这是两步请求回来的，所以可以 contact，并且他们的类型一定要一样，都是 Observable<EOCategory>
    // 需要注意的是: contact 执行任务的时候， 是串行的，只有当第一个结束了， 然后才会有第二个
    
    // 第二版注释：
    eoCategories
      // Challene 2: updateCategories map 成第一个元素，[EOCategory]
      .concat(updateCategories.map(\.1))
      .bind(to: categories)
      .disposed(by: disposeBag)

  }
  
  // MARK: UITableViewDataSource
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return categories.value.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "categoryCell")!
    let category = categories.value[indexPath.row]
    cell.textLabel?.text = "\(category.name)(\(category.events.count))"
    cell.detailTextLabel?.text = category.description
    cell.accessoryType = (category.events.count > 0 ? .disclosureIndicator : .none)
    return cell
  }
  // MARK: - UITableView Delegate

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let category = categories.value[indexPath.row]
    tableView.deselectRow(at: indexPath, animated: true)
    guard !category.events.isEmpty else {
      return
    }
    
    let eventsController = storyboard!.instantiateViewController(withIdentifier: "events") as! EventsViewController
    eventsController.title =  category.name
    eventsController.events.accept(category.events)
    navigationController?.pushViewController(eventsController, animated: true)
  }
}

