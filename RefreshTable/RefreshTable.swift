//
//  RefreshTable.swift
//  RefreshTable
//
//  Created by Bang Nguyen on 23/09/2014.
//  Copyright (c) Năm 2014 Bang Nguyen. All rights reserved.
//

// This class is based on EGORefreshTableHeaderView (Copyright 2009 enormego, MIT)

// This code is distributed under the terms and conditions of the MIT license.

// Copyright (c) 2014 Bang Nguyen
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import UIKit
import QuartzCore

/*
* RefreshTable is a control that display a view on the top of UITableView. It helps
* user to refresh data of UITableView. This class is based on EGORefreshTableHeaderView
*/

/* 
* State of RefreshTable
*/
enum RefreshTableState {
    case
    Pulling,
    Normal,
    Loading
}

/*
* Style of RefreshTable
* You can define your style here
*/
enum RefreshTableStyle {
    case
    // Default style - actually first style
    CircleWave
    
    // Other style here
    
}

// MARK:
// MARK: RefreshTableDelegate

/*
* RefreshTableDelegate, like EGORefreshTableHeaderViewDelegate
*/
protocol RefreshTableDelegate: NSObjectProtocol {
    
    func refreshTableDidRefresh(view: RefreshTable)
    func refreshTableDataSourceIsLoading(view: RefreshTable) -> Bool
    
}

// MARK:
// MARK: RefreshTable Class

class RefreshTable: UIView {
    
    var delegate : RefreshTableDelegate?
    
    private var _currentState : RefreshTableState = .Normal
    
    private var _currentStyle : RefreshTableStyle = .CircleWave
    
    private var _iconColor : UIColor = UIColor.whiteColor()
    
    private var _refreshLayer : CAShapeLayer?
    
    private var _loadingLayer : CAShapeLayer?

    // MARK:
    // MARK: Public functions
    
    required init(coder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    init(tableView: UITableView, refreshStyle: RefreshTableStyle, backgroundColor: UIColor, iconColor: UIColor) {
        
        _iconColor = iconColor
        _currentStyle = refreshStyle
        
        super.init(frame: CGRectMake(tableView.frame.origin.x, tableView.frame.origin.y - tableView.bounds.height, tableView.bounds.width, tableView.bounds.height))
        
        self.autoresizingMask = .FlexibleWidth
        self.backgroundColor = backgroundColor
        
        _refreshLayer = createRefreshLayer()
        self.layer.addSublayer(_refreshLayer)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "loadAnimation:", name: UIApplicationWillEnterForegroundNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "removeAnimation:", name: UIApplicationDidEnterBackgroundNotification, object: nil)
        
    }
    
    class func addTo(#tableView: UITableView, refreshStyle: RefreshTableStyle, backgroundColor: UIColor, iconColor: UIColor) -> RefreshTable {
        
        var refreshView : RefreshTable = RefreshTable(tableView: tableView, refreshStyle: refreshStyle, backgroundColor: backgroundColor, iconColor: iconColor)
        tableView.addSubview(refreshView)
        
        return refreshView
    }
    
    func refreshTableDidScroll(#scrollView: UIScrollView) {
        
        if _currentState == .Loading {
            
            var offset = max(scrollView.contentOffset.y * -1, 0)
            offset = min(offset, 60)
            scrollView.contentInset = UIEdgeInsetsMake(offset, 0.0, 0.0, 0.0)
            
        } else if scrollView.dragging {
            
            var offset = -scrollView.contentOffset.y
            
            if offset < 60 {
                _refreshLayer!.timeOffset = CFTimeInterval(offset/60)
            } else {
                _refreshLayer!.timeOffset = 1
            }
            
            var loading = false
            if delegate!.respondsToSelector("refreshTableDataSourceIsLoading:") {
                loading = delegate!.refreshTableDataSourceIsLoading(self)
            }
            
            if _currentState == .Pulling && scrollView.contentOffset.y > -65.0 && scrollView.contentOffset.y < 0.0 && !loading {
                setState(.Normal)
            } else if _currentState == .Normal && scrollView.contentOffset.y < -65.0 && !loading {
                setState(.Pulling)
            }
            
            if scrollView.contentInset.top != 0 {
                scrollView.contentInset = UIEdgeInsetsZero
            }
            
        }
    }
    
    func refreshTableDidEndDragging(#scrollView: UIScrollView) {
        
        var loading = false
        
        if delegate!.respondsToSelector("refreshTableDataSourceIsLoading:") {
            loading = delegate!.refreshTableDataSourceIsLoading(self)
        }
        
        if scrollView.contentOffset.y <= -65.0 && !loading {
            
            if delegate!.respondsToSelector("refreshTableDidRefresh:") {
                delegate?.refreshTableDidRefresh(self)
            }
            
            setState(.Loading)
            
            UIView.beginAnimations(nil, context: nil)
            UIView.setAnimationDuration(0.2)
            scrollView.contentInset = UIEdgeInsetsMake(60, 0, 0, 0)
            _refreshLayer!.timeOffset = 1
            UIView.commitAnimations()
            
            
            _loadingLayer = createLoadingLayer()
            self.layer.addSublayer(_loadingLayer)
            
        }
        
    }
    
    func refreshTableDataFinishedLoading(#scrollView: UIScrollView) {
        
        UIView.beginAnimations(nil, context: nil)
        UIView.setAnimationDuration(0.3)
        scrollView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0)
        UIView.commitAnimations()
        
        _loadingLayer?.removeFromSuperlayer()
        
        setState(.Normal)
        
    }
    
    func loadAnimation(notification: NSNotification) {
        
        _refreshLayer?.timeOffset = 0
        _refreshLayer?.addAnimation(pullingAnimations()!, forKey: "anim")
    
    }
    
    func removeAnimation(notification: NSNotification) {
        
        _refreshLayer?.removeAllAnimations()
        _loadingLayer?.removeAllAnimations()
        _loadingLayer?.removeFromSuperlayer()
        
    }
    
    // MARK:
    // MARK: Private functions
    
    private func setState(state: RefreshTableState) {
        
        // some config if needed
        
        _currentState = state
    }
    
    private func createRefreshLayer() -> CAShapeLayer? {
        
        var shape = CAShapeLayer()
        shape.anchorPoint = CGPointMake(0.5, 0.5)
        shape.frame = CGRectMake(0, 0, 30.0, 30.0)
        shape.position = CGPointMake(self.bounds.size.width/2, self.bounds.size.height - 30)
        
        switch _currentStyle {
        case .CircleWave:
            var aCenter = CGPointMake(15, 15)
            
            var circlePath = UIBezierPath(arcCenter: aCenter, radius: CGFloat(15), startAngle: CGFloat(-M_PI/2), endAngle: CGFloat(3*M_PI/2), clockwise: true)
            
            shape.path = circlePath.CGPath
            shape.strokeColor = _iconColor.CGColor
            shape.lineWidth = 3.0
            shape.fillColor = UIColor.clearColor().CGColor
            shape.lineCap = kCALineCapRound
            shape.lineJoin = kCALineJoinRound
            
            // TODO: your custom refresh layer here
            
        default:
            return nil
        }
        
        shape.addAnimation(pullingAnimations()!, forKey: "anim")
        shape.speed = 0
        
        return shape
    }
    
    private func pullingAnimations() -> CAAnimationGroup? {
        
        switch _currentStyle {
        case .CircleWave:
            
            var moveAnim = CABasicAnimation(keyPath: "position.y")
            moveAnim.fromValue = self.bounds.size.height
            moveAnim.toValue = self.bounds.size.height - 30
            
            var sizeAnim = CABasicAnimation(keyPath: "transform.scale")
            sizeAnim.fromValue = 0
            sizeAnim.toValue = 1
            
            var strokeAnim = CABasicAnimation(keyPath: "strokeEnd")
            strokeAnim.fromValue = 0
            strokeAnim.toValue = 1
            
            var group = CAAnimationGroup()
            group.animations = [ moveAnim, sizeAnim, strokeAnim ]
            group.duration = 1
            
            return group
            
            // TODO: your custom pulling style here
            
        default:
            return nil
        }
        
    }
    
    private func createLoadingLayer() -> CAShapeLayer? {
        var shape = CAShapeLayer()
        shape.anchorPoint = CGPointMake(0.5, 0.5)
        shape.frame = CGRectMake(0, 0, 30.0, 30.0)
        shape.position = CGPointMake(self.bounds.size.width/2, self.bounds.size.height - 30)
        
        switch _currentStyle {
        case .CircleWave:
            var aCenter = CGPointMake(15, 15)
            
            var circlePath = UIBezierPath(arcCenter: aCenter, radius: CGFloat(15), startAngle: CGFloat(-M_PI/2), endAngle: CGFloat(3*M_PI/2), clockwise: true)
            
            shape.path = circlePath.CGPath
            shape.strokeColor = _iconColor.CGColor
            shape.lineWidth = 3.0
            shape.fillColor = UIColor.clearColor().CGColor
            shape.lineCap = kCALineCapRound
            shape.lineJoin = kCALineJoinRound
            
            // TODO: your custom loading layer here
            
        default:
            return nil
        }
        
        shape.addAnimation(loadingAnimations()!, forKey: "anim")
        
        return shape
    }
    
    private func loadingAnimations() -> CAAnimationGroup? {
        
        switch _currentStyle {
        case .CircleWave:
            
            var sizeAnim = CABasicAnimation(keyPath: "transform.scale")
            sizeAnim.fromValue = 1
            sizeAnim.toValue = 1.5
            
            var opacityAnim = CABasicAnimation(keyPath: "opacity")
            opacityAnim.fromValue = 1
            opacityAnim.toValue = 0
            
            var group = CAAnimationGroup()
            group.animations = [ sizeAnim, opacityAnim ]
            group.duration = 0.8
            group.repeatCount = HUGE
            group.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
            
            return group
            
            // TODO: your custom loading style here
            
        default:
            return nil
        }
        
    }
    
}
