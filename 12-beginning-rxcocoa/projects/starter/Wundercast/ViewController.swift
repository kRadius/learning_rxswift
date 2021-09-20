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

class ViewController: UIViewController {
    @IBOutlet private var searchCityName: UITextField!
    @IBOutlet private var tempLabel: UILabel!
    @IBOutlet private var humidityLabel: UILabel!
    @IBOutlet private var iconLabel: UILabel!
    @IBOutlet private var cityNameLabel: UILabel!
    @IBOutlet weak var tempSwitch: UISwitch!
    
    
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
            
        // Do any additional setup after loading the view, typically from a nib.
//        ApiController.shared.currentWeather(for: "RxSwift")
//            .observeOn(MainScheduler.instance)
//            .subscribe(onNext: { [weak self] weather in
//                self?.tempLabel.text = "\(weather.temperature) ° C"
//                self?.iconLabel.text = weather.icon
//                self?.humidityLabel.text = "\(weather.humidity) ° C"
//                self?.cityNameLabel.text = "\(weather.cityName)"
//            })
//            .disposed(by: disposeBag)
        // orEmpty 返回了空字符串。 等同于 .map { $0 ?? ""}
        // 没有 RxCocoa Trait 之前的用法
//        let search = searchCityName.rx.text.orEmpty
//            .filter { !$0.isEmpty }
//            // Lastest 可以取消掉之前的请求。如果使用 flatMap，那么每一次 type，都请求-response
//            .flatMapLatest { text -> Observable<ApiController.Weather> in
//                ApiController.shared
//                    .currentWeather(for: text)
//                    // 如果不加这个，一旦发生了错误，那么订阅就被终止了，然后就被 dispose 了
//                    .catchErrorJustReturn(.empty)
//            }
//            // 为啥这个也要共享？？？？
//            // 在这，共享意味着什么？ 1. 共享订阅 2. 输出变成了 single（onsuccess/onerror）
//            // 在说直白一点： search 的结果，可以被多个 label 一起使用，而不会创建多个 订阅者.
//            // 而且本来一份数据，不同的使用方，需要的结果可能都不一样，map 的操作返回的结果也不一样。
//            // 一般来说只能自己订阅自己的。或者不 map，把代码的修改都写在一起。像 Example1
//            .share(replay: 1)
//            .observeOn(MainScheduler.instance)
//
        // 有了 RxCocoa Trait 用法之后
//        let search = searchCityName.rx.text.orEmpty
//            .filter { !$0.isEmpty }
//            .flatMapLatest { text -> Observable<ApiController.Weather> in
//                ApiController
//                    .shared
//                    .currentWeather(for: text)
//                    .catchErrorJustReturn(.empty)
//            }
//            .asDriver(onErrorJustReturn: .empty)
        
        // Example 4: 别发那么多的请求
        let `switch` = tempSwitch.rx.controlEvent(.valueChanged).map{ self.tempSwitch.isOn }
        
        let search = searchCityName.rx.controlEvent(.editingDidEndOnExit)
            .map { self.searchCityName.text ?? "" }
            .filter { !$0.isEmpty }
            .flatMapLatest { text -> Observable<ApiController.Weather> in
                ApiController.shared
                    .currentWeather(for: text)
                    .catchErrorJustReturn(.empty)
            }
            .asDriver(onErrorJustReturn: .empty)
            
        // Example 1
//        search.subscribe(onNext: {[weak self] weather in
//                self?.tempLabel.text = "\(weather.temperature) ° C"
//                self?.iconLabel.text = weather.icon
//                self?.humidityLabel.text = "\(weather.humidity) ° C"
//                self?.cityNameLabel.text = "\(weather.cityName)"
//            })
//            .disposed(by: disposeBag)
        // Example 2:
        // 思考：但是这样写四个订阅真的有啥牛逼的地方么？
        // 可能的好处：对扩展开放，对修改关闭， 不用担心新增 监听， 会破坏了原来的逻辑
//        search.map { "\($0.temperature)° C" }
//            .bind(to: tempLabel.rx.text)
//            .disposed(by: disposeBag)
//
//        search.map { "\($0.icon) "}
//            .bind(to: iconLabel.rx.text)
//            .disposed(by: disposeBag)
//
//        search.map { "\($0.humidity)" }
//            .bind(to: humidityLabel.rx.text)
//            .disposed(by: disposeBag)
//
//        search.map { "\($0.cityName)" }
//            .bind(to: cityNameLabel.rx.text)
//            .disposed(by: disposeBag)
        
        // Example 3: driver 用法
        search
            .map { "\($0.temperature)° C" }
            .drive(tempLabel.rx.text)
            .disposed(by: disposeBag)
        
        // challenge：我自己的解法。不会每次请求，但是，会和上面的 driver 重复修改 label
        Observable.combineLatest(search.asObservable(), `switch`)
            .flatMapLatest { weather, isOn -> Observable<String> in
                if isOn {
                    return Observable<String>.of("\(weather.temperature * Int(1.8) + 32)° F")
                }
                return Observable<String>.of("\(weather.temperature) ° C")
            }
            .bind(to: tempLabel.rx.text)
            .disposed(by: disposeBag)

        
        search.map { "\($0.icon) "}
            .drive(iconLabel.rx.text)
            .disposed(by: disposeBag)
        
        search.map { "\($0.humidity)" }
            .drive(humidityLabel.rx.text)
            .disposed(by: disposeBag)
        
        search.map { "\($0.cityName)" }
            .drive(cityNameLabel.rx.text)
            .disposed(by: disposeBag)
        
        
        style()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        Appearance.applyBottomLine(to: searchCityName)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Style
    
    private func style() {
        view.backgroundColor = UIColor.aztec
        searchCityName.attributedPlaceholder = NSAttributedString(string: "City's Name",
                                                                  attributes: [.foregroundColor: UIColor.textGrey])
        searchCityName.textColor = UIColor.ufoGreen
        tempLabel.textColor = UIColor.cream
        humidityLabel.textColor = UIColor.cream
        iconLabel.textColor = UIColor.cream
        cityNameLabel.textColor = UIColor.cream
    }
}
