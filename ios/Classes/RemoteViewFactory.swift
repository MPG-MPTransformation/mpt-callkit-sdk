import Flutter
import UIKit
import PortSIPVoIPSDK

class RemoteViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger
    var remoteViewController: RemoteViewController!
    
    init(messenger: FlutterBinaryMessenger, remoteViewController: RemoteViewController) {
        self.messenger = messenger
        self.remoteViewController = remoteViewController
        super.init()
    }
    
    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return RemoteView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger,
            remoteViewController: remoteViewController)
    }
    
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class RemoteView: NSObject, FlutterPlatformView {
    private var _view: UIView
    var remoteViewController: RemoteViewController!
    
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?,
        remoteViewController: RemoteViewController
    ) {
        _view = UIView()
        super.init()
        createNativeView(view: _view, arguments: args, remoteViewController: remoteViewController)
    }
    
    func view() -> UIView {
        return _view
    }
    
    func createNativeView(view _view: UIView, arguments args: Any?, remoteViewController: RemoteViewController) {
        let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first
        let topController = keyWindow?.rootViewController
        let flutterView = remoteViewController
        
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