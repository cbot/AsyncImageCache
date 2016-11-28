# AsyncImageCache
AsyncImageCache is a fast cache implementation that stores UIImage instances in both memory and on disk. All operations are asynchronously executed on a background thread for maximum performance. The features are rather low level on purpose, this allows AsyncImageCache to be used as a basis for higher level implementations.

## Installation
Use CocoaPods to add AsyncImageCache to your project. Just add the following line to your Podfile.
```
pod 'AsyncImageCache', '~> 1.0.1'
```
