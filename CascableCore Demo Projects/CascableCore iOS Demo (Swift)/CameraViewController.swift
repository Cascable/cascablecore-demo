//
//  CameraViewController.swift
//  CascableCore iOS Demo (Swift)
//
//  Created by Daniel Kennett (Cascable) on 2021-06-22.
//  Copyright © 2021 Cascable AB. All rights reserved.
//

import UIKit
import CascableCore

func CurrentFileName(_ fileName: String = #file) -> String {
    return fileName.components(separatedBy: "/").last ?? fileName
}

protocol CameraViewController: UIViewController {
    func setupUI(for camera: (Camera & NSObject)?)
    var camera: (Camera & NSObject)? { get set }
}
