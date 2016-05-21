//
//  ImageMessageCell.swift
//  ReTxt
//
//  Created by Kevin Wooten on 10/14/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import MessagesKit
import ImageIO
import CocoaLumberjack


public class ImageMessageCell : MessageCell {
  
  
  @IBOutlet var thumbnailImageView : AnimatedImageView!
  @IBOutlet var loadingView : UIActivityIndicatorView!
  @IBOutlet var maxWidthConstraint : NSLayoutConstraint!
  
  override func willBeginDisplaying() {
    super.willBeginDisplaying()
  }
  
  override public func updateWithMessage(message: Message) {

    guard let message = message as? ImageMessage else {
      fatalError("invalid message class")
    }
    
    super.updateWithMessage(message)
    
    let thumbnailKey = message.id.UUIDString + "@thumb"

    listenForMediaAvailableWithKey(thumbnailKey)
    
    
    if let image = delegate?.loadCachedMediaForKey(thumbnailKey, loader: { resolve, fail in
      
      DDLogDebug("Caching message thumbnail \(message.id.UUIDString)")
    
      do {
    
        let imageData = message.thumbnailOrImageData
        let imageSource = try imageData.createImageSource().takeRetainedValue()
        
        let image : AnyObject
        
        if let animatedImage = AnimatedImage(source: imageSource) {
          
          image = animatedImage
          
        }
        else if let stillImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
          
          image = UIImage(CGImage: stillImage)
          
        }
        else {
          
          image = UIImage(id: .ImageError)
          
        }
        
        resolve(image, try imageData.dataSize().integerValue)
        
      }
      catch let error {
        fail(error as NSError)
      }
    
    }) {
      
      updateImage(image)
      
      loadingView.stopAnimating()
    }
    else {
      
      thumbnailImageView.snp_makeConstraints { make in
        make.size.equalTo(message.thumbnailSize)
      }
      
      loadingView.startAnimating()
      
    }
    
  }
  
  func updateImage(image: AnyObject) {

    thumbnailImageView.anyImage = image
    
    let size = thumbnailImageView.intrinsicContentSize()
    thumbnailImageView.snp_remakeConstraints { make in
      make.width.equalTo(thumbnailImageView.snp_height).multipliedBy(size.width/size.height)
    }

  }
  
  override public func mediaAvailableWithInfo(info: [String : AnyObject]) {
    
    if let thumbnail = info[MessageCellMediaDataAvailableNotificationImage] {
      updateImage(thumbnail)
    }
    
    loadingView.stopAnimating()    
  }
  
  override public func preferredLayoutAttributesFittingAttributes(layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
    
    maxWidthConstraint.constant = (superview?.frame.width ?? layoutAttributes.size.width) * 0.70

    return super.preferredLayoutAttributesFittingAttributes(layoutAttributes)
  }
  
}
