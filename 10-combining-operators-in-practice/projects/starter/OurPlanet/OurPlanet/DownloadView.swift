//
//  Download.swift
//  OurPlanet
//
//  Created by kRadius on 2021/9/19.
//  Copyright © 2021 Ray Wenderlich. All rights reserved.
//

import UIKit

class DownloadView: UIStackView {
  let textLabel = UILabel(frame: .zero)
  let progress = UIProgressView(frame: .zero)
  
  // 作用是当父 view 发生变化的时候，做一些事情
  // 为什么会在这个地方布局约束？约束不应该是由外部指定么？
  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    translatesAutoresizingMaskIntoConstraints = false
    
    axis = .horizontal
    distribution = .fillEqually
    spacing = 0
    
    if let superview = superview {
      backgroundColor = .white
      
      // 添加自己的约束
      leftAnchor.constraint(equalTo: superview.leftAnchor).isActive = true
      rightAnchor.constraint(equalTo: superview.rightAnchor).isActive = true
      bottomAnchor.constraint(equalTo: superview.bottomAnchor).isActive = true
      heightAnchor.constraint(equalToConstant: 38).isActive = true
      
      // 布局子元素
      textLabel.text = "Download"
      textLabel.translatesAutoresizingMaskIntoConstraints = false
      textLabel.backgroundColor = .lightGray
      textLabel.textAlignment = .center
      
      progress.translatesAutoresizingMaskIntoConstraints = false
      
      let progressWrap = UIView()
      progress.translatesAutoresizingMaskIntoConstraints = false
      progress.backgroundColor = .lightGray
      progressWrap.addSubview(progress)
      
      progress.leftAnchor.constraint(equalTo: progressWrap.leftAnchor).isActive = true
      progress.rightAnchor.constraint(equalTo: progressWrap.rightAnchor).isActive = true
      progress.centerYAnchor.constraint(equalTo: progressWrap.centerYAnchor).isActive = true
      progress.heightAnchor.constraint(equalToConstant: 4).isActive = true
      
      addArrangedSubview(textLabel)
      addArrangedSubview(progressWrap)
    }
  }
}
