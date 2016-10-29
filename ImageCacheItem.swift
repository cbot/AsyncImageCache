import UIKit

/// This class represents a sigle cached item in an ImageCache
/// it basically wraps an UIImage and adds two date properties
public class ImageCacheItem {
    public internal(set) var lastUsed: Date
    let created: Date
    let image: UIImage
    
    init(data: Data, image: UIImage?, created: Date? = nil) {
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
