import Flutter
import UIKit
import PortSIPVoIPSDK

class LocalViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger
    var localViewController: LocalViewController!
    
    init(messenger: FlutterBinaryMessenger, localViewController: LocalViewController) {
        self.messenger = messenger
        self.localViewController = localViewController
        super.init()
    }
    
    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return LocalView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger,
            localViewController: localViewController)
    }
    
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class LocalView: NSObject, FlutterPlatformView {
    private var _view: UIView
    var localViewController: LocalViewController!
    
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?,
        localViewController: LocalViewController
    ) {
        _view = UIView()
        super.init()
        createNativeView(view: _view, arguments: args, localViewController: localViewController)
    }
    
    func view() -> UIView {
        return _view
    }
    
    func createNativeView(view _view: UIView, arguments args: Any?, localViewController: LocalViewController) {
        let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first
        let topController = keyWindow?.rootViewController
        let flutterView = localViewController
        
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