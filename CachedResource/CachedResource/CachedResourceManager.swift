 //
//  ResourceManager.swift
//  CachedResource
//
//  Created by satel on 2017/2/22.
//  Copyright © 2017年 Cached. All rights reserved.
//

import Foundation

fileprivate let memorySize = 4 * 1024 * 1024
fileprivate let diskSize = 200 * 1024 * 1024
fileprivate let path = "cached_resources"

public class CachedResourceManager: NSObject {
    
    fileprivate let cache: URLCache
    fileprivate let session: URLSession
    
    public static let `default`: CachedResourceManager = {
        return CachedResourceManager()
    }()
    
    //diskCapacity的容量至少是单个Resource大小的20倍，否则苹果默认不会缓存这个Resource
    //如果一个Resource确实很大，需要download的时候设置forceCaching为true
    //参考：https://developer.apple.com/reference/foundation/nsurlsessiondatadelegate/1411612-urlsession
    public init(memoryCapacity: Int = memorySize, diskCapacity: Int = diskSize, path: String? = path) {
        cache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: path)
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        session = URLSession(configuration: config)
    }
    
    public func cachedResource(for url: URL) -> Data? {
        let request = URLRequest(url: url)
        return cache.cachedResponse(for: request)?.data
    }
    
    public func asyncCachedResource(for url: URL, completionHandler: @escaping (Data?) -> Void ) {
        DispatchQueue.global().async {
            let request = URLRequest(url: url)
            let data = self.cache.cachedResponse(for: request)?.data
            DispatchQueue.main.async {
                completionHandler(data)
            }
        }
    }
    
    public func needsUpdate(for url: URL, completionHandler: @escaping (Bool) -> Void ) {
        let request = URLRequest(url: url)
        guard let cachedResponse = cache.cachedResponse(for: request), let response = cachedResponse.response as? HTTPURLResponse else {
            completionHandler(true)
            return
        }
        
        //检查etag或者last-modified是否存在
        var headRequest = URLRequest(url: url)
        headRequest.httpMethod = "HEAD"
        //必须设置忽略本地缓存，不然即使server返回304，URLFoundation看到304后会将cache取出包装成200返回
        headRequest.cachePolicy = .reloadIgnoringLocalCacheData
        
        if let etag = response.allHeaderFields["Etag"] as? String {
            headRequest.setValue(etag, forHTTPHeaderField: "If-None-Match")
        } else if let lastModified = response.allHeaderFields["Last-Modified"] as? String {
            headRequest.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }
        let task = session.dataTask(with: headRequest) { (data, response, error) in
            if error != nil {
                //网络请求失败认为不需要更新
                completionHandler(false)
                return
            }
            //如果服务器返回304，说明资源没有修改过，不需要重新获取
            if let response = response as? HTTPURLResponse, response.statusCode == 304 {
                completionHandler(false)
                return
            }
            completionHandler(true)
        }
        task.resume()
    }
    
    //forceCaching是为了解决苹果的一个缓存限制：The response size is small enough to reasonably fit within the cache. (For example, if you provide a disk cache, the response must be no larger than about 5% of the disk cache size.)
    //参考：https://developer.apple.com/reference/foundation/nsurlsessiondatadelegate/1411612-urlsession
    public func downloadResource(_ url: URL, ignoreCache: Bool = false, forceCaching: Bool = false,  completionHandler: @escaping (Data?) -> Void) {
        var request = URLRequest(url: url)
        if ignoreCache {
            request.cachePolicy = .reloadIgnoringLocalCacheData
        }
        let task = session.dataTask(with: request) { (data, response, error) in
            if forceCaching, let response = response, let data = data {
                let cachedResponse = CachedURLResponse(response: response, data: data)
                self.cache.storeCachedResponse(cachedResponse, for: request)
            }
            completionHandler(data)
        }
        task.resume()
    }
}
