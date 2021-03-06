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
  // ?????????????????? relay????????????????????? tableView ??? update????????????????????? arrival ?????????
  // ??????????????????????????????????????????
  let categories = BehaviorRelay<[EOCategory]>(value: [])
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // ???????????? asObservable, categories ??????????????????????????????
    // ????????????????????????????????????????????????????????? observable ??????????????? ????????? subject ????????? relay??? ?????????????????????????????? onNext ???????????? accept ??????
    // ???????????????????????? source sequence
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
    
    // challenge1: ??? ??????????????? indicator?????????????????????
    // challenge2: ??? view ????????????????????????????????????????????????????????????????????????
    
    
    let eoCategories = EONET.categories
    // ???????????????:  ?????????????????? 360 ????????? open ??? close ??????
    // let downloadedEvents = EONET.events(forLast: 360)
//    //???bind(to:) connects a source observable (EONET.categories) to an observer (the categories relay).???
//    // ????????????????????????????????? ???????????????????????????
//    eoCategories.bind(to: categories).disposed(by: disposeBag)
    
    // ???????????????
    // ?????????????????????????????? Category ?????????????????????????????? ???????????? Category??? ??????????????????????????????????????? Category ??????
    // ???????????? flatMap???
    // flatMap ????????????????????? ????????? Observable ????????????????????????????????????????????????????????????????????????
    // ?????? Observable<Observable<Int>> -> Int
    
    // ??????????????? Observable<[EOCategory]> ?????? Observable<Observable<[Event]>>
    // ?????????????????? map???
    // map ?????? sequence ??????????????????????????????????????????????????????????????????????????????????????? map
    // ??????????????? ?????? Observable<[EOCategory]> ?????? Observable<Observable<Observable<[EOEvent]>>>
    
    let downloadEvents = eoCategories.flatMap { categories -> Observable<Observable<[EOEvent]>> in
      // Observable.from() ???????????? ?????? x?????????????????? Observable<[x]>
      // ???????????????????????? Category???map ?????? EOEvent ???????????? Observable<[EOEvent]>
      // ??????????????? Observable<Observable<[EOEvent]>>
      return Observable.from( categories.map({ category -> Observable<[EOEvent]> in
        EONET.events(forLast: 360, category: category)
      }))
    }
    // ?????? merge ????????????????????????????????? source ?????? merge
    // ??????????????????????????????????????? Observable<Observable<[EOEvent]>>
    // merge ??????????????? Observable<[EOEvent]>, ?????????????????????
    // Observable<Observable<[EOEvent]>>????????????????????????????????? ???????????????????????? ???????????????????????????????????????????????? relay ?????????
    // ?????????????????? 25 ??? categries???????????? Category ??????????????? open??? close ??? events ?????? EONET.events ??????
    // ????????????  50 ??? API ???????????????????????????????????????????????????????????????????????? merge ????????????????????????????????????
    // ????????????????????????????????? ???????????????????????????
    .merge(maxConcurrent: 2)

    
    // ???????????????
    // ?????????????????? 360 ????????? open ??? close ??????
//    // ?????????????????? category??? ????????????????????? ???????????????????????? category ??????????????? ?????????????????????
//    // ????????? combineLatest ??? map ???????????? combine ???????????????
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
    
    
    // ???????????????
    let updateCategories = eoCategories.flatMap { categories -> Observable<(Int, [EOCategory])> in
      // scan ???????????????????????????????????? source emit element ????????????????????? closure, ????????? closure ?????? ???????????? updated
      // ???????????????????????????????????????????????? ???????????????????????? category
      return downloadEvents.scan((0, categories)) { tuple, events -> (Int, [EOCategory]) in
        // challenge 2 ?????? 1 - ????????? scan ????????????????????? ????????? do(onNext???) ?????????
        // : ?????????????????? ??? 1?????????????????? downloadEvents??????????????????????????????????????????????????? event ???????????? ??????????????? ??????????????????????????? category ????????????
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
    
//    // challange 2 ???????????????????????? flatMap ( ??????????????????1???????????????)
//    // ??????????????????
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
//      // start with 0 ?????????????????????
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
    
    // ??????????????????
    // ???????????? ???????????? ??????????????????????????? Events. ?????????????????????????????????????????? contact???????????????????????????????????????????????? Observable<EOCategory>
    // ??????????????????: contact ???????????????????????? ????????????????????????????????????????????? ????????????????????????
    
    // ??????????????????
    eoCategories
      // Challene 2: updateCategories map ?????????????????????[EOCategory]
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

