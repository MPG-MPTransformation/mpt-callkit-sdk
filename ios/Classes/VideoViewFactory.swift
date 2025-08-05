import Flutter
import SwiftUI
import UIKit

class FLNativeViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger
    var videoViewController: VideoViewController!

    init(messenger: FlutterBinaryMessenger, videoViewController: VideoViewController) {
        self.messenger = messenger
        self.videoViewController = videoViewController
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return FLNativeView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger, videoViewController: videoViewController)
    }

    /// Implementing this method is only necessary when the `arguments` in `createWithFrame` is not `nil`.
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
          return FlutterStandardMessageCodec.sharedInstance()
    }
}

class FLNativeView: NSObject, FlutterPlatformView {
    private var _view: UIView
    var videoViewController: VideoViewController!

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?,
        videoViewController: VideoViewController
    ) {
        _view = UIView()
        super.init()
        createNativeView(view: _view, arguments: args, videoViewController: videoViewController)
    }

    func view() -> UIView {
        return _view
    }

    func createNativeView(view _view: UIView, arguments args: Any?, videoViewController: VideoViewController) {
               // Fix: Use modern window access pattern for iOS 13+
       let keyWindow: UIWindow?
       if #available(iOS 13.0, *) {
           keyWindow = UIApplication.shared.connectedScenes
               .compactMap { $0 as? UIWindowScene }
               .flatMap { $0.windows }
               .first(where: { $0.isKeyWindow }) ?? UIApplication.shared.connectedScenes
               .compactMap { $0 as? UIWindowScene }
               .flatMap { $0.windows }
               .first
       } else {
           keyWindow = UIApplication.shared.keyWindow
       }
       let topController = keyWindow?.rootViewController
        let flutterView = videoViewController
        
        let view = flutterView.view
        view?.translatesAutoresizingMaskIntoConstraints = false

        topController?.addChild(flutterView)
        _view.addSubview(view!)

        NSLayoutConstraint.activate([
            view!.leadingAnchor.constraint(equalTo: _view.leadingAnchor),
            view!.trailingAnchor.constraint(equalTo: _view.trailingAnchor),
            view!.topAnchor.constraint(equalTo: _view.topAnchor),
            view!.bottomAnchor.constraint(equalTo: _view.bottomAnchor)
        ])

        flutterView.didMove(toParent: topController)
    }
}
