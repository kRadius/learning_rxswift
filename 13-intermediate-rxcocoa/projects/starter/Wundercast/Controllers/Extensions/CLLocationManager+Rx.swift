/// Copyright (c) 2019 Razeware LLC
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
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import Foundation
import CoreLocation
import RxSwift
import RxCocoa

// 完全没明白，这个类是在干什么？这里的 API 又是什么意思？
// 应该是扩展那些需要 delegate 的类，并且让他们的使用方式，符合 Rx 的习惯
// “By using these two methods, you can initialize the delegate and register all implementations, which will be the proxy used to drive the data from the CLLocationManager instance to the connected observables. This is how you expand a class to use the delegate proxy pattern from RxCocoa”
// 通过使用这两个方法，你可以初始化 delegate 和注册所有的实现，这将是用来驱动数据从CLLocationManager实例到连接的可观察对象的代理。这是如何扩展一个类来使用RxCocoa的委托代理模式"
extension CLLocationManager : HasDelegate {}
//“RxCLLocationManagerDelegateProxy is going to be your proxy that attaches to the CLLocationManager instance right after an observable is created and has a subscription”
class RxCLLocatoinManagerDelegateProxy : DelegateProxy<CLLocationManager, CLLocationManagerDelegate>, DelegateProxyType, CLLocationManagerDelegate {
    weak public private(set) var locationManager: CLLocationManager?
    
    public init(locationManager: ParentObject) {
        self.locationManager = locationManager
        super.init(parentObject: locationManager, delegateProxy: RxCLLocatoinManagerDelegateProxy.self)
    }
    
    static func registerKnownImplementations() {
        register { parent in
            RxCLLocatoinManagerDelegateProxy(locationManager: parent)
        }
    }
}

public extension Reactive where Base: CLLocationManager {
    var delegate: DelegateProxy<CLLocationManager, CLLocationManagerDelegate> {
        RxCLLocatoinManagerDelegateProxy.proxy(for: base)
    }
    
    var didUpdateLocations: Observable<[CLLocation]> {
        delegate.methodInvoked(#selector(CLLocationManagerDelegate.locationManager(_:didUpdateLocations:)))
            .map { parameters in
                parameters[1] as! [CLLocation]
            }
    }
    
    var authorizationStatus: Observable<CLAuthorizationStatus> {
        delegate.methodInvoked(#selector(CLLocationManagerDelegate.locationManager(_:didChangeAuthorization:)))
            .map { parameters in
                CLAuthorizationStatus(rawValue: parameters[1] as! Int32)!
            }
            .startWith(CLLocationManager.authorizationStatus())
    }
    // 把 viewDidLoad 里的请求权限以及获取位置，合成了一个
    func getCurrentLocation() -> Observable<CLLocation> {
        // “How elegant! This is exactly where RxSwift shines — taking several smaller pieces and composing them into a single, cohesive and useful piece.”
        
        let location = authorizationStatus
            .filter { status in
                status == .authorizedAlways || status == .authorizedWhenInUse
            }
            .flatMap { _ in
                self.didUpdateLocations.compactMap { $0.first }
            }
            .take(1)
            // Neat！
            .do(onDispose: {[weak base] in
                base?.stopUpdatingLocation()
            })
        
        // base 指代的就是你为谁创建的 rx extension
        base.requestWhenInUseAuthorization()
        base.startUpdatingLocation()
        
        return location
    }
}
