import UIKit

/// This class represents a sigle cached item in an ImageCache
/// it basically wraps an UIImage and adds two date properties
public class AsyncImageCacheItem {
    public internal(set) var lastUsed: Date
    public let created: Date
    public let image: UIImage
    public let data: Data
    
    init(data: Data, image: UIImage?, created: Date? = nil) {
        self.data = data
        if let image = image {
            self.image = image
        } else {
            self.image = UIImage(data: data) ?? UIImage()
        }
        
        let now = Date()
        self.lastUsed = now
        self.created = created ?? now
    }
}
