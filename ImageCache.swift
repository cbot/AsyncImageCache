import UIKit

public enum ImageFormat {
    case png
    case jpeg(quality: CGFloat)
}

public class AsyncImageCache {
    private let memoryCache = NSCache<NSString, AsyncImageCacheItem>()
    private let diskCacheUrl: URL
    private let syncQueue = DispatchQueue(label: "imageCache")
    private let autoCleanupDays: Int
    
    /// Initializes a new ImageCache instance
    ///
    /// - Parameters:
    ///   - name: the name of the cache. This is used to create a folder for the disk cache. Make sure to only use characters that are safe in a file system path.
    ///   - memoryCacheSize: the size of the memory cache in bytes
    ///   - autoCleanupDays: the maximum number to keep ununsed(!) cached items. Set to 0 to disable auto cleanup.
    /// - Throws: throws NSErrors if the path for the disk cache could not be determined
    public init(name: String, memoryCacheSize: Int = 32 * 1024 * 1024, autoCleanupDays: Int = 30) throws {
        memoryCache.totalCostLimit = memoryCacheSize
        
        guard let cachesPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first else {
            throw NSError(domain: "ImageCache", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to construct disk cache directory"])
        }
        
        diskCacheUrl = URL(fileURLWithPath: cachesPath).appendingPathComponent("imagecache-\(name)")
        if !FileManager.default.fileExists(atPath: diskCacheUrl.path) {
            try FileManager.default.createDirectory(at: diskCacheUrl, withIntermediateDirectories: true, attributes: nil)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(cleanup), name: Notification.Name.UIApplicationWillResignActive, object: nil)
        self.autoCleanupDays = autoCleanupDays
    }

    
    /// Stores an instance of UIImage in the cache
    ///
    /// - Parameters:
    ///   - image: The image to store
    ///   - format: either png or jpeg
    ///   - key: the key for which to store the image
    ///   - callbackQueue: a DispatchQueue on which to call the completion closure, defaults to the main queue
    ///   - completion: a completion closure that is called after the data was stored
    public func store(image: UIImage, format: ImageFormat, forKey key: String, callbackQueue: DispatchQueue = DispatchQueue.main, completion: (() -> ())? = nil) {
        syncQueue.async {
            let data: Data?
            switch format {
            case .png:
                data = UIImagePNGRepresentation(image)
            case .jpeg(let quality):
                data = UIImageJPEGRepresentation(image, quality)
            }
            
            if let data = data {
                self.store(data: data, forKey: key, image: image, callbackQueue: callbackQueue, completion: completion)
            } else {
                callbackQueue.async {
                    completion?()
                }
            }
        }
    }
    
    /// Stores a blob of data in the cache
    ///
    /// - Parameters:
    ///   - data: the data to store in the cache
    ///   - key: the key for which to store the data
    ///   - image: an optional UIImage representation of the data. This parameter is recommended (but not required) to improve performance.
    ///   - callbackQueue: a DispatchQueue on which to call the completion closure, defaults to the main queue
    ///   - completion: a completion closure that is called after the data was stored
    public func store(data: Data, forKey key: String, image: UIImage? = nil, callbackQueue: DispatchQueue = DispatchQueue.main, completion: (() -> ())? = nil) {
        syncQueue.async {
            let item = AsyncImageCacheItem(data: data, image: image)
            
            self.memoryCache.setObject(item, forKey: key as NSString, cost: data.count)
            
            let url = self.diskCacheUrl.appendingPathComponent(key)
            
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                print(error)
            }
            
            callbackQueue.async {
                completion?()
            }
        }
    }
    
    /// Asynchronously removes an item from the cache.
    ///
    /// - Parameters:
    ///   - key: the key whose item shall be removed
    ///   - callbackQueue: a DispatchQueue on which to call the completion closure, defaults to the main queue
    ///   - completion: a completion closure that is called after the item was removed from the cache
    public func remove(itemWithKey key: String, callbackQueue: DispatchQueue = DispatchQueue.main, completion: (() -> ())?) {
        syncQueue.async {
            self.memoryCache.removeObject(forKey: key as NSString)
            
            let url = self.diskCacheUrl.appendingPathComponent(key)
            try? FileManager.default.removeItem(at: url)
            
            callbackQueue.async {
                completion?()
            }
        }
    }
    
    /// Asynchronously fetches an item from the cache. This can be either the in memory cache or the disk cache.
    ///
    /// - Parameters:
    ///   - key: the key to fetch the item for
    ///   - callbackQueue: a DispatchQueue on which to call the completion closure, defaults to the main queue
    ///   - completion: a completion closure that is called with the result of the fetch process
    public func fetch(itemWithKey key: String, callbackQueue: DispatchQueue = DispatchQueue.main, completion: @escaping (_ item: AsyncImageCacheItem?) -> ()) {
        syncQueue.async {
            let url = self.diskCacheUrl.appendingPathComponent(key)
            
            if let item = self.memoryCache.object(forKey: key as NSString) { // memory cache hit
                item.lastUsed = Date()
                callbackQueue.async {
                    completion(item)
                }
            
                try? (url as NSURL).setResourceValue(item.lastUsed, forKey: URLResourceKey.contentAccessDateKey)
            } else {
                do {
                    // try to load from disk cache
                    
                    // get file creation date
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    let created = attributes[FileAttributeKey.creationDate] as? Date
                    
                    // load image data
                    let data = try Data(contentsOf: url)
                    
                    // create a new cache item
                    let item = AsyncImageCacheItem(data: data, image: UIImage(data: data), created: created)
                    
                    // update memory cache
                    self.memoryCache.setObject(item, forKey: key as NSString, cost: data.count)
                    
                    callbackQueue.async {
                        completion(item)
                    }
                    
                    try? (url as NSURL).setResourceValue(item.lastUsed, forKey: URLResourceKey.contentAccessDateKey)
                } catch { // cache miss
                    callbackQueue.async {
                        completion(nil)
                    }
                }
            }
        }
    }
    
    // MARK: - Utility
    /// This method is automatically called when the app transitions away from the active state
    /// The files in the disk cache folder are enumerated and all files whose last access date is older than 30 days are deleted.
    /// This is to make sure the disk cache does not keep growing and growing over time.
    @objc private func cleanup() {
        if autoCleanupDays == 0 { return } // cleanup disabled
        
        syncQueue.sync {
            memoryCache.removeAllObjects()
            
            do {
                let filesArray = try FileManager.default.contentsOfDirectory(atPath: diskCacheUrl.path)
                let now = Date()
                for file in filesArray {
                    let url = diskCacheUrl.appendingPathComponent(file)
                    var lastAccess: AnyObject?
                    do {
                        try (url as NSURL).getResourceValue(&lastAccess, forKey: URLResourceKey.contentAccessDateKey)
                        if let lastAccess = lastAccess as? Date {
                            if (now.timeIntervalSince(lastAccess) > autoCleanupDays * 24 * 3600) {
                                try FileManager.default.removeItem(at: url)
                            }
                        }
                    } catch {
                        continue
                    }
                    
                }
            } catch {}
        }
    }
    
    // MARK: - Memory
    deinit {
        NotificationCenter.default.removeObserver(self)
        cleanup()
    }
}
