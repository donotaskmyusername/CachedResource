//
//  ViewController.swift
//  Example
//
//  Created by satel on 2017/2/22.
//  Copyright © 2017年 Cached. All rights reserved.
//

import UIKit
import CachedResource

class ViewController: UIViewController {

    fileprivate let resourceManager = CachedResourceManager.default
    //http://cn.bing.com/sa/simg/speechIcon.png
    //http://10.0.4.2:82/app/wifi.json
    fileprivate let resourceUrl = URL(string: "http://10.0.4.2:82/app/wifi.json")!
    
    @IBOutlet var cacheLabel: UILabel!
    @IBOutlet var needsUpdateLabel: UILabel!
    @IBOutlet var downloadLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    @IBAction func onButtonPressed() {
        loadCacheData()
        checkAndUpdate()
    }
    
    @IBAction func onDownloadButtonPressed() {
        forceDownload()
    }
    
    fileprivate func loadCacheData() {
        resourceManager.asyncCachedResource(for: resourceUrl) { (data) in
            DispatchQueue.main.async {
                if let data = data {
                    self.cacheLabel.text = "cache exists,data len: \(data.count)"
                } else {
                    self.cacheLabel.text = "cache does not exist"
                }
            }

        }
    }
    
    fileprivate func checkAndUpdate() {
        resourceManager.needsUpdate(for: resourceUrl) { (needsUpdate) in
            if needsUpdate {
                DispatchQueue.main.async {
                    self.needsUpdateLabel.text = "需要更新"
                }
                
                self.resourceManager.downloadResource(self.resourceUrl, completionHandler: { (data) in
                    DispatchQueue.main.async {
                        if let data = data {
                            self.downloadLabel.text = "成功下载\(data.count)"
                        } else {
                            self.downloadLabel.text = "下载失败"
                        }
                    }

                })
            } else {
                DispatchQueue.main.async {
                    self.needsUpdateLabel.text = "不需要更新"
                }
            }
        }
    }
    
    fileprivate func forceDownload() {
        resourceManager.downloadResource(resourceUrl, ignoreCache: true) { (data) in
            DispatchQueue.main.async {
                if let data = data {
                    self.downloadLabel.text = "成功更新\(data.count)"
                } else {
                    self.downloadLabel.text = "下载失败"
                }
            }
        }
    }
}

