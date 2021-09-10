//
//  PHLibrary+Rx.swift
//  Combinestagram
//
//  Created by kRadius on 2021/9/9.
//  Copyright © 2021 Underplot ltd. All rights reserved.
//

import RxSwift
import Photos


extension PHPhotoLibrary {
  static var authorized: Observable<Bool> {
    return Observable.create { observer in
      // “A note on the usage of DispatchQueue.main.async {...}: generally, your observables should not block the current thread because that could block your UI, prevent other subscriptions, or have other nasty consequences.”
      // 意思是不要阻塞 UI
      DispatchQueue.main.async {
        if authorizationStatus() == .authorized {
          observer.onNext(true)
          observer.onCompleted()
        } else {
          observer.onNext(false)
          requestAuthorization { status in
            observer.onNext(status == .authorized)
            observer.onCompleted()
          }
        }
      }
      return Disposables.create()
    }
  }
}
