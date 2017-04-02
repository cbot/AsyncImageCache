Pod::Spec.new do |s|
  s.name         = "AsyncImageCache"
  s.version      = "1.1.0"
  s.summary      = "AsyncImageCache is a fast, low level cache implementation that stores UIImage instances in both memory and on disk"
  s.description  = "AsyncImageCache is a fast cache implementation that stores UIImage instances in both memory and on disk. All operations are asynchronously executed on a background thread for maximum performance. The features are rather low level on purpose, this allows AsyncImageCache to be used as a basis for higher level implementations."
  s.homepage     = "https://github.com/cbot/AsyncImageCache"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author    = "Kai Straßmann"
  s.social_media_url   = "http://twitter.com/kaimoringen"
  s.platform     = :ios, "9.0"
  s.source       = { :git => "https://github.com/cbot/AsyncImageCache.git", :tag => "#{s.version}" }
  s.source_files  = "*.swift"
  s.frameworks = "UIKit", "Foundation"
  s.requires_arc = true
end
