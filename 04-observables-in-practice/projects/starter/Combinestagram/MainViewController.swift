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
import RxRelay

class MainViewController: UIViewController {

  @IBOutlet weak var imagePreview: UIImageView!
  @IBOutlet weak var buttonClear: UIButton!
  @IBOutlet weak var buttonSave: UIButton!
  @IBOutlet weak var itemAdd: UIBarButtonItem!
  // MainVC 释放的时候, 被 bag 管理的 subscrition 都会释放
  // 但是 MainVC 因为是 Root, 所以不会被释放
  private let bag = DisposeBag()
  private let images = BehaviorRelay<[UIImage]>(value: [])
  
  override func viewDidLoad() {
    super.viewDidLoad()
    images.subscribe(
      onNext: { [weak imagePreview] photos in
        guard let preview = imagePreview else {
            return
        }
        preview.image = photos.collage(size: preview.frame.size)
      }
    ).disposed(by: bag)
    
    images.subscribe(
      onNext: { [weak self] photos in
        self?.updateUI(photos: photos)
      }
    ).disposed(by: bag)
  }
  
  private func updateUI(photos: [UIImage]) {
    buttonSave.isEnabled = photos.count > 0 && photos.count % 2 == 0
    buttonClear.isEnabled = photos.count > 0
    itemAdd.isEnabled = photos.count < 6
    title = photos.count > 0 ? "\(photos.count) photos" : "Collage"

  }
  
  @IBAction func actionClear() {
    images.accept([])
  }

  @IBAction func actionSave() {
    guard let image = imagePreview.image else { return }
    PhotoWriter.save(image)
      .asSingle()
      .subscribe(
        onSuccess: { [weak self] id in
          self?.showMessage("Save with id:\(id)")
          self?.actionClear()
        }, onError: { error in
          self.showMessage("Error: ", description: error.localizedDescription)
        }
      ).disposed(by: bag)

  }

  @IBAction func actionAdd() {
    // With RxSwift, however, you have a universal way to talk between any two classes — an Observable! There is no need to define a special protocol, because an Observable can deliver any kind of message to any one or more interested parties — the observers.
    let photoVC = storyboard!.instantiateViewController(withIdentifier: "PhotosViewController") as! PhotosViewController
    navigationController!.pushViewController(photoVC, animated: true)
    
    photoVC.selectedPhotos.subscribe(
      onNext: {[weak self] image in
        guard let images = self?.images else { return }
        images.accept(images.value + [image])
      },
      onDisposed: {
        print("Completed photo select")
      }
    ).disposed(by: bag)
  }

  func showMessage(_ title: String, description: String? = nil) {
//    let alert = UIAlertController(title: title, message: description, preferredStyle: .alert)
//    alert.addAction(UIAlertAction(title: "Close", style: .default, handler: { [weak self] _ in self?.dismiss(animated: true, completion: nil)}))
//    present(alert, animated: true, completion: nil)
    alert(title, description: description)
      .subscribe()
      .disposed(by: bag)
  }
}

extension UIViewController {
  func alert(_ title: String, description: String? = nil) -> Completable {
    return Completable.create {[weak self] subsribe in
      let alert = UIAlertController(title: title, message: description, preferredStyle: .alert)
      alert.addAction(
        UIAlertAction(title: "Close", style: .default, handler: { _ in
          subsribe(.completed)
        })
      )
      self?.present(alert, animated: true, completion: nil)
      return Disposables.create {
        self?.dismiss(animated: true, completion: nil)
      }
    }
  }
}
