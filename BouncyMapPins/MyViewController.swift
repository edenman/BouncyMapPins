import UIKit
import GoogleMaps
import PureLayout
import pop

class MyViewController: UIViewController {
  private let mapView = GMSMapView()
  private var markers = [GMSMarker]()

  override func viewDidLoad() {
    super.viewDidLoad()

    view.addSubview(mapView)

    mapView.autoPinEdgesToSuperviewEdges()
    mapView.camera = GMSCameraPosition.camera(withTarget: CLLocationCoordinate2D(latitude: 37.785663, longitude: -122.405869), zoom: 13)
    mapView.isMyLocationEnabled = true
    mapView.settings.tiltGestures = false
    mapView.settings.rotateGestures = false
    mapView.settings.indoorPicker = false
    mapView.paddingAdjustmentBehavior = .never // We manage the safe area ourselves.
    markers.append(MyMapPin.build(CLLocationCoordinate2D(latitude: 37.7508961, longitude: -122.4180867), name: "La Taqueria", mapView: mapView, size: .large))
    markers.append(MyMapPin.build(CLLocationCoordinate2D(latitude: 37.777171, longitude: -122.4129187), name: "Cellarmaker", mapView: mapView, size: .medium))
    markers.append(MyMapPin.build(CLLocationCoordinate2D(latitude: 37.7698262, longitude: -122.4204105), name: "Crafty Fox", mapView: mapView, size: .small))
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: {
      NSLog("HI HI HI HI HI HIHI HI HI HI HI HIHI HI HI HI HI HIHI HI HI HI HI HIHI HI HI HI HI HI")
      (self.markers[0].iconView as! MyMapPin).setSize(.small)
      (self.markers[1].iconView as! MyMapPin).setSize(.large)
    })

  }
}


class MyMapPin: UIView {
  private let debug = true

  private func dbg(_ message: String) {
    NSLog("MMP: \(message)")
  }

  private let outerCircleContainer = UIView()
  private let outerCircle = UIView()
  private let innerCircle = UIView()

  private var outerCircleSizeConstraint: NSLayoutConstraint!
  private var innerCircleSizeConstraint: NSLayoutConstraint!

  enum Size {
    case tiny
    case small
    case medium
    case large
  }

  private var currentSize: Size
  private var attached: Bool = false
  private var name: String
  private var marker: GMSMarker!
  private let sizeChangeAnimationDuration = 0.3
  private let pulseAnimationDuration = 1.6

  static func build(_ loc: CLLocationCoordinate2D, name: String, mapView: GMSMapView, size: Size) -> GMSMarker {
    let marker = GMSMarker(position: loc)
    let mapPinView = MyMapPin(name: name)
    mapPinView.frame = CGRect(x: 0, y: 0, width: 38, height: 38)
    marker.map = mapView
    marker.tracksViewChanges = true
    marker.isTappable = true
    marker.iconView = mapPinView
    marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
    mapPinView.marker = marker
    mapPinView.setSize(size)
    return marker
  }

  init(name: String) {
    currentSize = .tiny
    self.name = name
    super.init(frame: CGRect.zero)

    addSubview(outerCircleContainer)
    addSubview(innerCircle)

    outerCircleContainer.autoCenterInSuperview()
    outerCircleContainer.addSubview(outerCircle)
    outerCircleContainer.clipsToBounds = false

    outerCircle.autoPinEdgesToSuperviewEdges()
    outerCircleSizeConstraint = outerCircle.autoSetDimension(.width, toSize: 6)
    outerCircle.autoMatch(.height, to: .width, of: outerCircle)
    outerCircle.backgroundColor = UIColor.white

    innerCircle.autoCenterInSuperview()
    innerCircleSizeConstraint = innerCircle.autoSetDimension(.width, toSize: 2)
    innerCircle.autoMatch(.height, to: .width, of: innerCircle)
    innerCircle.backgroundColor = UIColor.green

    outerCircleContainer.layer.cornerRadius = outerCircleSizeConstraint.constant / 2
    outerCircle.layer.cornerRadius = outerCircleSizeConstraint.constant / 2
    innerCircle.layer.cornerRadius = innerCircleSizeConstraint.constant / 2
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("Not implemented")
  }

  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    if !attached {
      attached = true
      if marker != nil {
        // Kick off this animation on the main thread: this avoids a deadlock.
        __dispatch_async(.main, {
          self.startNewSizeAnimation()
        })
      }
    }
  }

  func setSize(_ size: Size) {
    self.currentSize = size
    if (attached) {
      __dispatch_async(.main, {
        self.startNewSizeAnimation()
      })
    }
  }

  private func startNewSizeAnimation() {
    if !marker.tracksViewChanges {
      marker.tracksViewChanges = true
    }
    let cancelledPrevious = recursiveCancelAnimations()
    if cancelledPrevious {
      dbg("\(name): cancelled previous animations")
    }
    let sizeTarget = currentSize
    dbg("\(name): starting animation to size \(sizeTarget)")
    animateToCurrentState({ finished in
      if finished {
        if sizeTarget == .large && self.pulseAnimationDuration > 0 {
          self.dbg("\(self.name): Done with animation to size \(sizeTarget): start pulsing!")
          self.pulse()
        } else {
          self.dbg("\(self.name): Done with animation to size \(sizeTarget).  outerCircle scale: \(self.outerCircle.transform.a)")
          self.marker.tracksViewChanges = false
        }
      } else {
        self.dbg("\(self.name): Animation cancelled to size \(sizeTarget).")
      }
    })
  }

  private func pulse() {
    self.marker.tracksViewChanges = true
    self.animateToState(.medium, duration: pulseAnimationDuration, completionBlock: { finished in
      guard finished else {
        self.dbg("\(self.name): pulse cancelled en route to Medium")
        return
      }
      self.dbg("\(self.name): pulsing back to Large")
      self.animateToState(.large, duration: self.pulseAnimationDuration, completionBlock: { finished in
        guard finished else {
          self.dbg("\(self.name): pulse cancelled en route to Large")
          return
        }
        self.dbg("\(self.name): pulsing back to Medium")
        self.pulse()
      })
    })
  }

  private func animateToCurrentState(_ completionBlock: @escaping (Bool) -> Void) {
    animateToState(currentSize, duration: sizeChangeAnimationDuration, completionBlock: completionBlock)
  }

  private func animateToState(_ size: Size, duration: Double, completionBlock: @escaping (Bool) -> Void) {
    let outerCircleSize = outerCircleSizeFor(size)
    dbg("\(name): Applying size to outer circle: \(outerCircleSize)")
    animateCircleToSize(outerCircle, constraint: outerCircleSizeConstraint, size: outerCircleSize, duration: duration, completionBlock: completionBlock)
    animateCircleToSize(innerCircle, constraint: innerCircleSizeConstraint, size: outerCircleSize - 4, duration: duration, completionBlock: nil)
  }

  private func animateCircleToSize(_ view: UIView, constraint: NSLayoutConstraint, size: CGFloat, duration: Double, completionBlock: ((Bool) -> Void)?) {
    let scaleFactor = size / constraint.constant
    if view.transform != CGAffineTransform.identity {
      self.dbg("\(name): Previous scale was \(view.transform.a), new scale is \(scaleFactor)")
    } else {
      self.dbg("\(name): Scaling to scale \(scaleFactor)")
    }
    view.pop_scale(to: scaleFactor, duration: duration, completionBlock: completionBlock)
  }

  private func outerCircleSizeFor(_ size: Size) -> CGFloat {
    switch size {
      case .tiny:
        return 6
      case .small:
        return 10
      case .medium:
        return 16
      case .large:
        return 22
    }
  }

  private func zIndexFor(_ size: Size, isBookable: Bool) -> Int32 {
    switch size {
      case .tiny:
        return isBookable ? 1 : 0
      case .small:
        return 2
      case .medium:
        return 3
      case .large:
        return 4
    }
  }
}

extension UIView {
  @discardableResult
  func recursiveCancelAnimations() -> Bool {
    var cancelled = false
    if let keys = layer.animationKeys(), !keys.isEmpty {
      // DDLogDebug("Cancelling \(keys.count) animations on \(accessibilityIdentifier.orNil)")
      cancelled = true
    }
    layer.removeAllAnimations()

    if let popKeys = pop_animationKeys(), !popKeys.isEmpty {
      // NSLog("Cancelling \(popKeys.count) POP animations on \(accessibilityIdentifier.orNil)")
      cancelled = true
    }
    pop_removeAllAnimations()

    for view in subviews {
      cancelled = view.recursiveCancelAnimations() || cancelled
    }
    return cancelled
  }

  func pop_scale(to: CGFloat, duration: TimeInterval = 0.3, completionBlock: AnimationCompletionBlock? = nil) {
    pop_add(createPOPBasicAnimation(property: kPOPViewScaleXY,
                                    to: CGPoint(x: to, y: to),
                                    duration: duration,
                                    completionBlock: completionBlock),
            forKey: NSUUID().uuidString)
  }
}

private func createPOPBasicAnimation(property: String,
                                     to: Any,
                                     duration: TimeInterval,
                                     completionBlock: AnimationCompletionBlock?) -> POPBasicAnimation {
  let animation = POPBasicAnimation(propertyNamed: property)!
  animation.toValue = to
  animation.duration = duration
  if let completionBlock = completionBlock {
    animation.completionBlock = { anim, finished in
      completionBlock(finished)
    }
  }
  return animation
}

typealias AnimationCompletionBlock = (Bool) -> Void
