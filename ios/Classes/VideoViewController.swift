import UIKit
import PortSIPVoIPSDK

class VideoViewController: UIViewController {
    var mCameraDeviceId: Int = 1 // 1 - FrontCamera 0 - BackCamera
    var speakState: Int = 0 // 1 - Headphone 0 - mic
    
    var muteState: Bool = true
    var mLocalVideoWidth: Int = 352
    var mLocalVideoHeight: Int = 288
    var isStartVideo = false
    var isInitVideo = false
    var sessionId: Int = 0
    var centerButtonSize: CGFloat = 70
    var otherButtonSize: CGFloat = 60
    var leftRightSpacing: CGFloat = 20
    var spacing: CGFloat = 10
    var sendState: Bool = true
    let deviceWidth = UIScreen.main.bounds.width
    var portSIPSDK: PortSIPSDK!
    
    // Create video render views and buttons programmatically
    var viewLocalVideo: PortSIPVideoRenderView!
    var viewRemoteVideo: PortSIPVideoRenderView!
    var viewRemoteVideoSmall: PortSIPVideoRenderView!
    var buttonConference: UIButton!
    var buttonSpeaker: UIButton!
    var buttonSendingVideo: UIButton!
    var buttonCamera: UIButton!
    var callButton: UIButton!
    var hangupButton: UIButton!
    var swapButton: UIButton!
    var backButton: UIButton!
    var muteButton: UIButton!
    
    var shareInSmallWindow = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Initialize the views
        centerButtonSize = (70 / 430) * deviceWidth
        otherButtonSize = (60 / 430) * deviceWidth
        leftRightSpacing = (20 / 430) * deviceWidth
        spacing = (10 / 430) * deviceWidth
        
        initVideoViews()
        initButtons()
        // Check if the outlets are properly initialized
        isInitVideo = true
        
        viewLocalVideo.initVideoRender()
        viewRemoteVideo.initVideoRender()
        viewRemoteVideo.contentMode = .scaleAspectFit
        viewRemoteVideoSmall.initVideoRender()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onSwichShareScreenClick(action:)))
        viewRemoteVideoSmall.addGestureRecognizer(tapGesture)
        
        updateLocalVideoPosition(UIScreen.main.bounds.size)
    }
    
    func initVideoViews() {
        viewRemoteVideo = PortSIPVideoRenderView()
        viewRemoteVideo.translatesAutoresizingMaskIntoConstraints = false
        viewRemoteVideo.backgroundColor = .black
        self.view.addSubview(viewRemoteVideo)
        viewLocalVideo = PortSIPVideoRenderView()
        viewLocalVideo.translatesAutoresizingMaskIntoConstraints = false
        viewLocalVideo.backgroundColor = .darkGray
        self.view.addSubview(viewLocalVideo)
        viewRemoteVideoSmall = PortSIPVideoRenderView()
        viewRemoteVideoSmall.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(viewRemoteVideoSmall)
        
        NSLayoutConstraint.activate([
            // Constraints for the remote video (full screen)
            viewRemoteVideo.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            viewRemoteVideo.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            viewRemoteVideo.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            viewRemoteVideo.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            
            // Constraints for the local video (custom size) - change the size here
            viewLocalVideo.widthAnchor.constraint(equalToConstant: 150),
            viewLocalVideo.heightAnchor.constraint(equalToConstant: 200),
            viewLocalVideo.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            viewLocalVideo.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10),
            
            // Constraints for the small remote video (top right corner)
            viewRemoteVideoSmall.widthAnchor.constraint(equalToConstant: 144),
            viewRemoteVideoSmall.heightAnchor.constraint(equalTo: viewRemoteVideoSmall.widthAnchor),
            viewRemoteVideoSmall.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            viewRemoteVideoSmall.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10)
        ])
    }
    
    func initButtons() {
        addBackButton()
        hangUpButton()
        swapUIButton()
        speakButton()
        sendingVideo()
        initMuteButton()
        // Create a horizontal stack view to hold the buttons
        let buttonStackView = UIStackView(arrangedSubviews: [buttonSendingVideo, swapButton, hangupButton, buttonSpeaker, muteButton])
        buttonStackView.axis = .horizontal
        buttonStackView.distribution = .equalSpacing
        buttonStackView.alignment = .center
        buttonStackView.spacing = spacing  // Adjust spacing between buttons if needed
        
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(buttonStackView)
        
        // Set constraints for the stack view directly to the main view with padding
        NSLayoutConstraint.activate([
            buttonStackView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: leftRightSpacing),
            buttonStackView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -leftRightSpacing),
            buttonStackView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -40), // Bottom padding
            buttonStackView.heightAnchor.constraint(equalToConstant: centerButtonSize) // Set height for stack view
        ])
    }
    
    func addBackButton() {
        let backButton = UIButton(type: .system)
        backButton.setImage(UIImage(systemName: "arrow.left", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
        backButton.tintColor = .white
        
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        
        backButton.translatesAutoresizingMaskIntoConstraints = false
        
        self.view.addSubview(backButton)
        
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    func hangUpButton() {
        hangupButton = UIButton(type: .system)
        hangupButton.setImage(UIImage(systemName: "phone.down.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
        hangupButton.tintColor = .white
        hangupButton.backgroundColor = .red
        
        hangupButton.frame = CGRect(x: 0, y: 0, width: centerButtonSize, height: centerButtonSize)
        hangupButton.layer.cornerRadius = centerButtonSize / 2
        hangupButton.translatesAutoresizingMaskIntoConstraints = false
        hangupButton.widthAnchor.constraint(equalToConstant: CGFloat(centerButtonSize)).isActive = true
        hangupButton.heightAnchor.constraint(equalToConstant: centerButtonSize).isActive = true
        hangupButton.imageView?.contentMode = .scaleAspectFit
        hangupButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        hangupButton.addTarget(self, action: #selector(hangup(_:)), for: .touchUpInside)
    }
    
    func swapUIButton() {
        swapButton = UIButton(type: .system)
        swapButton.setImage(UIImage(systemName: "camera.rotate", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
        swapButton.tintColor = .white
        swapButton.backgroundColor = UIColor.gray.withAlphaComponent(0.5)
        
        swapButton.frame = CGRect(x: 0, y: 0, width: otherButtonSize, height: otherButtonSize)
        swapButton.layer.cornerRadius = otherButtonSize / 2
        swapButton.addTarget(self, action: #selector(onSwitchCameraClick(_:)), for: .touchUpInside)
        
        swapButton.translatesAutoresizingMaskIntoConstraints = false
        swapButton.widthAnchor.constraint(equalToConstant: otherButtonSize).isActive = true
        swapButton.heightAnchor.constraint(equalToConstant: otherButtonSize).isActive = true
        swapButton.imageView?.contentMode = .scaleAspectFit
        swapButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    }
    
    func initMuteButton() {
        muteButton = UIButton(type: .system)
        muteButton.setImage(UIImage(systemName: "speaker.2.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
        muteButton.tintColor = .white
        muteButton.backgroundColor = UIColor.gray.withAlphaComponent(0.5)
        
        muteButton.frame = CGRect(x: 0, y: 0, width: otherButtonSize, height: otherButtonSize)
        muteButton.layer.cornerRadius = otherButtonSize / 2
        muteButton.addTarget(self, action: #selector(onMuteClick(_:)), for: .touchUpInside)
        
        muteButton.translatesAutoresizingMaskIntoConstraints = false
        muteButton.widthAnchor.constraint(equalToConstant: otherButtonSize).isActive = true
        muteButton.heightAnchor.constraint(equalToConstant: otherButtonSize).isActive = true
        muteButton.imageView?.contentMode = .scaleAspectFit
        muteButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    }
    
    func speakButton() {
        buttonSpeaker = UIButton(type: .system)
        buttonSpeaker.setImage(UIImage(systemName: "mic.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
        buttonSpeaker.tintColor = .white
        buttonSpeaker.backgroundColor = UIColor.gray.withAlphaComponent(0.5)
        
        buttonSpeaker.frame = CGRect(x: 0, y: 0, width: otherButtonSize, height: otherButtonSize)
        buttonSpeaker.layer.cornerRadius = otherButtonSize / 2
        buttonSpeaker.addTarget(self, action: #selector(onSwitchSpeakerClick(_:)), for: .touchUpInside)
        
        buttonSpeaker.translatesAutoresizingMaskIntoConstraints = false
        buttonSpeaker.widthAnchor.constraint(equalToConstant: otherButtonSize).isActive = true
        buttonSpeaker.heightAnchor.constraint(equalToConstant: otherButtonSize).isActive = true
        buttonSpeaker.imageView?.contentMode = .scaleAspectFit
        buttonSpeaker.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    }
    
    func sendingVideo() {
        buttonSendingVideo = UIButton(type: .system)
        buttonSendingVideo.setImage(UIImage(systemName: "video.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
        buttonSendingVideo.tintColor = .white
        buttonSendingVideo.backgroundColor = UIColor.gray.withAlphaComponent(0.5)
        
        buttonSendingVideo.frame = CGRect(x: 0, y: 0, width: otherButtonSize, height: otherButtonSize)
        buttonSendingVideo.layer.cornerRadius = otherButtonSize / 2
        buttonSendingVideo.addTarget(self, action: #selector(onSendingVideoClick(_:)), for: .touchUpInside)
        
        buttonSendingVideo.translatesAutoresizingMaskIntoConstraints = false
        buttonSendingVideo.widthAnchor.constraint(equalToConstant: otherButtonSize).isActive = true
        buttonSendingVideo.heightAnchor.constraint(equalToConstant: otherButtonSize).isActive = true
        buttonSendingVideo.imageView?.contentMode = .scaleAspectFit
        buttonSendingVideo.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    }
    
    @objc func onSwitchSpeakerClick(_ sender: AnyObject) {
        if speakState == 0 {
            speakState = 1
            self.portSIPSDK.setLoudspeakerStatus(false)
            self.buttonSpeaker.setImage(UIImage(systemName: "headphones", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
        } else {
            speakState = 0
            self.portSIPSDK.setLoudspeakerStatus(true)
            self.buttonSpeaker.setImage(UIImage(systemName: "mic.slash.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
        }
    }
    
    @objc func onSwitchCameraClick(_ sender: AnyObject) {
        if mCameraDeviceId == 0 {
            if portSIPSDK.setVideoDeviceId(1) == 0 {
                mCameraDeviceId = 1
                swapButton.setImage(UIImage(systemName: "camera.rotate.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
            }
        } else {
            if portSIPSDK.setVideoDeviceId(0) == 0 {
                mCameraDeviceId = 0
                swapButton.setImage(UIImage(systemName: "camera.rotate", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
            }
        }
    }
    
    @objc func onSwichShareScreenClick(action: UITapGestureRecognizer) {
        self.shareInSmallWindow = !self.shareInSmallWindow
        checkDisplayVideo()
    }
    
    @objc func onSendingVideoClick(_ sender: AnyObject) {
        if !sendState {
            sendState = true
            portSIPSDK.sendVideo(sessionId, sendState: sendState)
            buttonSendingVideo.setImage(UIImage(systemName: "video.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
        } else {
            sendState = false
            portSIPSDK.sendVideo(sessionId, sendState: sendState)
            buttonSendingVideo.setImage(UIImage(systemName: "video.slash.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
        }
    }
    
    @objc func onMuteClick(_ sender: AnyObject) {
        let sessionId = MptCallkitPlugin.shared.activeSessionid
        if (sessionId == nil) {
            return
        }
        if muteState {
            muteState = false
            portSIPSDK.muteSession(sessionId!, muteIncomingAudio: true, muteOutgoingAudio: true, muteIncomingVideo: false, muteOutgoingVideo: false)
            muteButton.setImage(UIImage(systemName: "speaker.slash.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
        } else {
            muteState = true
            portSIPSDK.muteSession(sessionId!, muteIncomingAudio: false, muteOutgoingAudio: false, muteIncomingVideo: false, muteOutgoingVideo: false)
            muteButton.setImage(UIImage(systemName: "speaker.2.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
        }
    }
    
    @objc func onConference(_ sender: AnyObject) {
        let appDelegate = MptCallkitPlugin.shared
        if buttonConference.titleLabel!.text == "Conference" {
            appDelegate.createConference(viewRemoteVideo)
            buttonConference.setTitle("UnConference", for: .normal)
        } else {
            appDelegate.destoryConference(viewRemoteVideo)
            portSIPSDK.setRemoteVideoWindow(sessionId, remoteVideoWindow: viewRemoteVideo)
            buttonConference.setTitle("Conference", for: .normal)
        }
    }
    
    func updateLocalVideoPosition(_ screenSize: CGSize) {
        DispatchQueue.main.async {
            if self.viewLocalVideo == nil {
                return
            }
            
            if screenSize.width > screenSize.height {
                // Landscape
                var rectLocal: CGRect = self.viewLocalVideo.frame
                rectLocal.size.width = 176
                rectLocal.size.height = CGFloat(Int(rectLocal.size.width) * self.mLocalVideoHeight / self.mLocalVideoWidth)
                rectLocal.origin.x = screenSize.width - rectLocal.size.width - 10
                rectLocal.origin.y = 10
                self.viewLocalVideo.frame = rectLocal
            } else {
                // Portrait
                var rectLocal: CGRect = self.viewLocalVideo.frame
                rectLocal.size.width = 144
                rectLocal.size.height = CGFloat(Int(rectLocal.size.width) * self.mLocalVideoWidth / self.mLocalVideoHeight)
                rectLocal.origin.x = screenSize.width - rectLocal.size.width - 10
                rectLocal.origin.y = 30
                self.viewLocalVideo.frame = rectLocal
            }
        }
    }
    
    func checkDisplayVideo() {
        let appDelegate = MptCallkitPlugin.shared
        guard let result = appDelegate._callManager.findCallBySessionID(sessionId) else {
            return
        }
        
        if isInitVideo {
            if isStartVideo {
                self.viewRemoteVideoSmall.isHidden = !result.session.screenShare
                if self.shareInSmallWindow {
                    portSIPSDK.setRemoteScreenWindow(sessionId, remoteScreenWindow: viewRemoteVideoSmall)
                    if appDelegate.isConference! {
                        portSIPSDK.setRemoteVideoWindow(sessionId, remoteVideoWindow: nil)
                        portSIPSDK.setConferenceVideoWindow(viewRemoteVideo)
                    } else {
                        portSIPSDK.setRemoteVideoWindow(sessionId, remoteVideoWindow: viewRemoteVideo)
                        portSIPSDK.setConferenceVideoWindow(nil)
                    }
                } else {
                    portSIPSDK.setRemoteScreenWindow(sessionId, remoteScreenWindow: viewRemoteVideo)
                    if appDelegate.isConference! {
                        portSIPSDK.setRemoteVideoWindow(sessionId, remoteVideoWindow: nil)
                        portSIPSDK.setConferenceVideoWindow(viewRemoteVideoSmall)
                    } else {
                        portSIPSDK.setRemoteVideoWindow(sessionId, remoteVideoWindow: viewRemoteVideoSmall)
                        portSIPSDK.setConferenceVideoWindow(nil)
                    }
                }
                
                portSIPSDK.displayLocalVideo(true, mirror: mCameraDeviceId == 0, localVideoWindow: viewLocalVideo)
                portSIPSDK.sendVideo(sessionId, sendState: true)
            } else {
                self.viewRemoteVideoSmall.isHidden = true
                portSIPSDK.displayLocalVideo(false, mirror: false, localVideoWindow: nil)
                portSIPSDK.setRemoteVideoWindow(sessionId, remoteVideoWindow: nil)
                portSIPSDK.setRemoteScreenWindow(sessionId, remoteScreenWindow: nil)
            }
        }
    }
    
    func onStartVideo(_ sessionID: Int) {
        DispatchQueue.main.async {
            self.isStartVideo = true
            self.sessionId = sessionID
            self.shareInSmallWindow = true
            self.checkDisplayVideo()
        }
    }
    
    func onStopVideo(_: Int) {
        DispatchQueue.main.async {
            self.isStartVideo = false
            self.checkDisplayVideo()
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.updateLocalVideoPosition(size)
        })
    }
    
    @objc func hangup(_ sender: AnyObject) {
        onClearState()
        MptCallkitPlugin.shared.hungUpCall()
        MptCallkitPlugin.shared.loginViewController.unRegister()
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func backButtonTapped() {
        onClearState()
        MptCallkitPlugin.shared.hungUpCall()
        MptCallkitPlugin.shared.loginViewController.unRegister()
        self.dismiss(animated: true, completion: nil)
    }
    
func onClearState() {
    if isStartVideo {
        portSIPSDK.displayLocalVideo(false, mirror: false, localVideoWindow: nil)
        portSIPSDK.setRemoteVideoWindow(sessionId, remoteVideoWindow: nil)
        portSIPSDK.setRemoteScreenWindow(sessionId, remoteScreenWindow: nil)

        // Stop sending video
        portSIPSDK.sendVideo(sessionId, sendState: false)
    }

    // Remove the video views from the screen
    viewLocalVideo.removeFromSuperview()
    viewRemoteVideo.removeFromSuperview()
    viewRemoteVideoSmall.removeFromSuperview()

    isStartVideo = false
    isInitVideo = false
    }
}
