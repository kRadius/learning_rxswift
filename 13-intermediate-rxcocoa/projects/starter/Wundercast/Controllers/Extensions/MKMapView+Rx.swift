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
import MapKit
import RxSwift
import RxCocoa


extension MKMapView: HasDelegate {}

class RxMKMapViewDelegateProxy: DelegateProxy<MKMapView, MKMapViewDelegate>, DelegateProxyType, MKMapViewDelegate {
    weak public private(set) var mapView: MKMapView?
    
    public init(mapView: ParentObject) {
        self.mapView = mapView
        super.init(parentObject: mapView, delegateProxy: RxMKMapViewDelegateProxy.self)
    }
    
    static func registerKnownImplementations() {
        register { parent in
            RxMKMapViewDelegateProxy(mapView: parent)
        }

    }
}

public extension Reactive where Base: MKMapView {
    var delegate: DelegateProxy<MKMapView, MKMapViewDelegate> {
        RxMKMapViewDelegateProxy.proxy(for: base)
    }
    // 对于 Rx 来说，要保持订阅的风格，还要实现有返回值的代理方法， 是很困难的，因为
    // 1. 有返回值的代理方法， 是用来自定义行为的，不是用来订阅的
    // 2. 就算定一个默认值，想要保证在任何的时候都有效，不是一件容易的事情
    // 最好的解决办法，应该是把这些行为的实现， 转发给别的类
    // 这种方式：让你既可以按照 UIKit 的方式使用代理，也能让你拥有 Rx 的链式监听
    
    func setDelegate(_ delegate: MKMapViewDelegate) -> Disposable {
        // 这个方法返回一个 Disposable 是为啥？
        // 作用：can be used to unset the forward to delegate
        RxMKMapViewDelegateProxy.installForwardDelegate(delegate, retainDelegate: false, onProxyForObject: self.base)
    }
    // 这都是啥啥啥啥？
    // “Using Binder not only allows you to use the bind(to:) or drive methods but also makes sure you have a properly retained reference to the base - in this case, the MapView. Very convenient!”
    // 可以用来绑定， 还能有 base 的引用
    // 我要的是这个说明吗？
    var overlay: Binder<MKOverlay> {
        Binder(base) { mapView, overlay in
            mapView.removeOverlays(mapView.overlays)
            mapView.addOverlay(overlay)
        }
    }
    
    var regioneDidChangeAnimated: ControlEvent<Bool> {
        let source = delegate.methodInvoked(#selector(MKMapViewDelegate.mapView(_:regionDidChangeAnimated:)))
            .map { parameters in
                return (parameters[1] as? Bool) ?? false
            }
        return ControlEvent(events: source)
    }
    
}
