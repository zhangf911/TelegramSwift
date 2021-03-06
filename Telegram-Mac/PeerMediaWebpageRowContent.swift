//
//  MediaWebpageRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 27/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
class PeerMediaWebpageRowItem: PeerMediaRowItem {
    
    var textLayout:TextViewLayout?
    var linkLayout:TextViewLayout?
    
    var iconText:NSAttributedString?
    var firstCharacter:String?
    var icon:TelegramMediaImage?
    var iconArguments:TransformImageArguments?
    var thumb:CGImage? = nil
    override init(_ initialSize:NSSize, _ interface:ChatInteraction, _ account:Account, _ object: PeerMediaSharedEntry) {
        super.init(initialSize,interface,account,object)
        iconSize = NSMakeSize(50, 50)
        
        
        if let webpage = message.media.first as? TelegramMediaWebpage {
            if case let .Loaded(content) = webpage.content {
                
                var hostName: String = ""
                if let url = URL(string: content.url), let host = url.host, !host.isEmpty {
                    hostName = host
                    firstCharacter = host.prefix(1)
                } else {
                    firstCharacter = content.url.prefix(1)
                }
                
                var iconImageRepresentation:TelegramMediaImageRepresentation? = nil
                if let image = content.image {
                    iconImageRepresentation = smallestImageRepresentation(image.representations)
                } else if let file = content.file {
                    iconImageRepresentation = smallestImageRepresentation(file.previewRepresentations)
                }
                
                if let iconImageRepresentation = iconImageRepresentation {
                     icon = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [iconImageRepresentation])
                    
                    let imageCorners = ImageCorners(radius: iconSize.width/2)
                    iconArguments = TransformImageArguments(corners: imageCorners, imageSize: iconImageRepresentation.dimensions.aspectFilled(iconSize), boundingSize: iconSize, intrinsicInsets: NSEdgeInsets())
                }
                
               
                let attributedText = NSMutableAttributedString()

                let _ = attributedText.append(string: content.title ?? content.websiteName ?? hostName, color: theme.colors.text, font: .medium(.text))
                
                if let text = content.text {
                    let _ = attributedText.append(string: "\n")
                    let _ = attributedText.append(string: text, color: theme.colors.text, font: NSFont.normal(FontSize.text))
                    attributedText.detectLinks(type: [.Links, .Mentions, .Hashtags], account: account, openInfo: interface.openInfo)
                }
                
                textLayout = TextViewLayout(attributedText, maximumNumberOfLines: 6, truncationType: .end)
                
                let linkAttributed:NSMutableAttributedString = NSMutableAttributedString()
                let _ = linkAttributed.append(string: content.displayUrl, color: theme.colors.link, font: NSFont.normal(FontSize.text))
                linkAttributed.detectLinks(type: [.Links, .Mentions, .Hashtags], account: account, openInfo: interface.openInfo)
                
                linkLayout = TextViewLayout(linkAttributed, maximumNumberOfLines: 1, truncationType: .end)
            }
        } else {
            
            var link:String = ""
            let links = ObjcUtils.textCheckingResults(forText: message.text, highlightMentionsAndTags: false, highlightCommands: false)
            if let links = links, !links.isEmpty {
                let range = (links[0] as! NSValue).rangeValue
                link = message.text.nsstring.substring(with: range)
                
                let attr = NSMutableAttributedString()
                _ = attr.append(string: link, color: theme.colors.link, font: .normal(.text))
                 attr.detectLinks(type: [.Links])
                
                linkLayout = TextViewLayout(attr, maximumNumberOfLines: 1, truncationType: .end)
            }
            
            var hostName: String = link
            if let url = URL(string: link), let host = url.host, !host.isEmpty {
                hostName = host
                firstCharacter = host.prefix(1)
            } else {
                firstCharacter = link.prefix(1)
            }
            
            let attributedText = NSMutableAttributedString()

            let _ = attributedText.append(string: hostName, color: theme.colors.text, font: .medium(.text))
            if !hostName.isEmpty {
                let _ = attributedText.append(string: "\n")
            }
            let _ = attributedText.append(string: message.text, color: theme.colors.text, font: NSFont.normal(.text))

            textLayout = TextViewLayout(attributedText, maximumNumberOfLines: 6, truncationType: .end)
           
        }
        
        if icon == nil {
            thumb = generateMediaEmptyLinkThumb(color: theme.colors.border, host: firstCharacter?.uppercased() ?? "H")
        }
        
        textLayout?.interactions = globalLinkExecutor
        linkLayout?.interactions = globalLinkExecutor
        
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        
        textLayout?.measure(width: width - contentInset.left - contentInset.right)
        linkLayout?.measure(width: width - contentInset.left - contentInset.right)
        
        var textSizes:CGFloat = 0
        if let tLayout = textLayout {
            textSizes += tLayout.layoutSize.height
        }
        if let lLayout = linkLayout {
            textSizes += lLayout.layoutSize.height
        }
        contentSize = NSMakeSize(width, max(textSizes + contentInset.top + contentInset.bottom + 2.0,60))
        
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override func viewClass() -> AnyClass {
        return PeerMediaWebpageRowView.self
    }
}


class PeerMediaWebpageRowView : PeerMediaRowView {
    
    private var imageView:TransformImageView
    private var textView:TextView
    private var linkView:TextView
    
    required init(frame frameRect: NSRect) {
        imageView = TransformImageView(frame:NSMakeRect(10, 5, 50.0, 50.0))
        textView = TextView()
        linkView = TextView()
        super.init(frame: frameRect)
        
        linkView.isSelectable = false
        
        addSubview(imageView)
        addSubview(textView)
        addSubview(linkView)
        
    }
    
   override func layout() {
        super.layout()
        if let item = item as? PeerMediaWebpageRowItem {
            textView.update(item.textLayout, origin: NSMakePoint(item.contentInset.left,item.contentInset.top))
            linkView.isHidden = item.linkLayout == nil
            linkView.update(item.linkLayout, origin: NSMakePoint(item.contentInset.left,textView.frame.maxY + 2.0))
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        
        super.set(item: item,animated:animated)
        textView.backgroundColor = backdorColor
        linkView.backgroundColor = backdorColor
        if let item = item as? PeerMediaWebpageRowItem {
            
            
            let updateIconImageSignal:Signal<(TransformImageArguments) -> DrawingContext?,NoError>
            if let icon = item.icon {
                updateIconImageSignal = chatWebpageSnippetPhoto(account: item.account, photo: icon, scale: backingScaleFactor, small:true)
            } else {
                updateIconImageSignal = .single({_ in return nil})
            }
            if let arguments = item.iconArguments {
                imageView.set(arguments: arguments)
                imageView.setSignal(account: item.account, signal: updateIconImageSignal)
            }
            
            if item.icon == nil {
                imageView.layer?.contents = item.thumb
            }
            
            needsLayout = true
        }
    }
    
    override func updateSelectingMode(with selectingMode:Bool, animated:Bool = false) {
        super.updateSelectingMode(with: selectingMode, animated: animated)
        self.textView.isSelectable = !selectingMode
        self.linkView.userInteractionEnabled = !selectingMode
        self.textView.userInteractionEnabled = !selectingMode
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
