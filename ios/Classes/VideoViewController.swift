import UIKit
import PortSIPVoIPSDK

class VideoViewController: UIViewController {
    var mCameraDeviceId: Int = 1 // 1 - FrontCamera 0 - BackCamera
    var speakState: Int = 0 // 1 - Headphone 0 - mic
    var mSoundService: SoundService!
    var muteState: Bool = true
    var muteMic: Bool = true
    var mLocalVideoWidth: Int = 352
    var mLocalVideoHeight: Int = 288
    var isStartVideo = false
    var isInitVideo = false
    var sessionId: Int = 0
    var otherButtonSize: CGFloat = 60
    var leftRightSpacing: CGFloat = 20
    var spacing: CGFloat = 10
    var sendState: Bool = true
    let deviceWidth = UIScreen.main.bounds.width
    var portSIPSDK: PortSIPSDK!
    var callingLabel: UILabel!
    var phoneLabel: UILabel!
    var callTimer: Timer?
    var callDuration: Int = 0
    
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
    var smallVideoCallButton: UIButton!
    
    var shareInSmallWindow = true
    
    override func viewWillAppear(_ animated: Bool) {
        // Initialize the views
        otherButtonSize = (70 / 430) * deviceWidth
        leftRightSpacing = (20 / 430) * deviceWidth
        spacing = (10 / 430) * deviceWidth
        mSoundService = SoundService()
        initVideoViews()
        initButtons()
        initCallingLabel()
    }
    
    func initVideoViews() {
        ///Khởi tạo với isVideoCall = true
        let appDelegate = MptCallkitPlugin.shared
        NSLog("isVideoCall init: \(appDelegate.isVideoCall)")
        if (appDelegate.isVideoCall) {
            viewRemoteVideo = PortSIPVideoRenderView()
            viewRemoteVideo.translatesAutoresizingMaskIntoConstraints = false
            viewRemoteVideo.backgroundColor = .black
            self.view.addSubview(viewRemoteVideo)
            viewLocalVideo = PortSIPVideoRenderView()
            viewLocalVideo.translatesAutoresizingMaskIntoConstraints = false
            viewLocalVideo.backgroundColor = .darkGray
            viewLocalVideo.layer.cornerRadius = 10
            viewLocalVideo.layer.masksToBounds = true
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
                viewLocalVideo.widthAnchor.constraint(equalToConstant: 130),
                viewLocalVideo.heightAnchor.constraint(equalToConstant: 180),
                viewLocalVideo.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: (-70 / 430) * deviceWidth - otherButtonSize),
                viewLocalVideo.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10),
                
                // Constraints for the small remote video (top right corner)
                viewRemoteVideoSmall.widthAnchor.constraint(equalToConstant: 144),
                viewRemoteVideoSmall.heightAnchor.constraint(equalTo: viewRemoteVideoSmall.widthAnchor),
                viewRemoteVideoSmall.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
                viewRemoteVideoSmall.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10)
            ])
            // Check if the outlets are properly initialized
            isInitVideo = true
            
            viewLocalVideo.initVideoRender()
            viewRemoteVideo.initVideoRender()
            viewRemoteVideo.contentMode = .scaleAspectFit
            viewRemoteVideoSmall.initVideoRender()
            updateLocalVideoPosition(UIScreen.main.bounds.size)

            portSIPSDK.displayLocalVideo(true, mirror: mCameraDeviceId == 0, localVideoWindow: viewLocalVideo)
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onSwichShareScreenClick(action:)))
            viewRemoteVideoSmall.addGestureRecognizer(tapGesture)
            
            updateLocalVideoPosition(UIScreen.main.bounds.size)
            return;
        }
    }
    
    func initRemoteVideo() {
        ///Khởi tạo với isVideoCall = true
        let appDelegate = MptCallkitPlugin.shared
        print(appDelegate.isVideoCall)
        if (appDelegate.isVideoCall) {
            viewRemoteVideo = PortSIPVideoRenderView()
            viewRemoteVideo.translatesAutoresizingMaskIntoConstraints = false
            viewRemoteVideo.backgroundColor = .black
            self.view.addSubview(viewRemoteVideo)
            viewRemoteVideoSmall = PortSIPVideoRenderView()
            viewRemoteVideoSmall.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(viewRemoteVideoSmall)
            self.view.addSubview(viewLocalVideo)
            NSLayoutConstraint.activate([
                // Constraints for the remote video (full screen)
                viewRemoteVideo.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                viewRemoteVideo.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
                viewRemoteVideo.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                viewRemoteVideo.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                
                // Constraints for the local video (custom size) - change the size here
                viewLocalVideo.widthAnchor.constraint(equalToConstant: 130),
                viewLocalVideo.heightAnchor.constraint(equalToConstant: 180),
                viewLocalVideo.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: (-70 / 430) * deviceWidth - otherButtonSize),
                viewLocalVideo.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10),
                
                // Constraints for the small remote video (top right corner)
                viewRemoteVideoSmall.widthAnchor.constraint(equalToConstant: 144),
                viewRemoteVideoSmall.heightAnchor.constraint(equalTo: viewRemoteVideoSmall.widthAnchor),
                viewRemoteVideoSmall.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
                viewRemoteVideoSmall.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10)
            ])
            // Check if the outlets are properly initialized
            isInitVideo = true
            
            viewRemoteVideo.initVideoRender()
            viewRemoteVideo.contentMode = .scaleAspectFit
            viewRemoteVideoSmall.initVideoRender()
            updateLocalVideoPosition(UIScreen.main.bounds.size)
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onSwichShareScreenClick(action:)))
            viewRemoteVideoSmall.addGestureRecognizer(tapGesture)
            
            updateLocalVideoPosition(UIScreen.main.bounds.size)
            return;
        }
    }
    
    func initCallingLabel() {
        let appDelegate = MptCallkitPlugin.shared
        phoneLabel?.removeFromSuperview()
        callingLabel?.removeFromSuperview()
        
        // Initialize phoneLabel
        phoneLabel = UILabel()
        phoneLabel.text = appDelegate.phone
        phoneLabel.textColor = .white
        phoneLabel.font = UIFont.boldSystemFont(ofSize: 26)
        phoneLabel.textAlignment = .center
        phoneLabel.translatesAutoresizingMaskIntoConstraints = false

        // Initialize callingLabel
        callingLabel = UILabel()
        callingLabel.text = "Đang kết nối..."
        callingLabel.textColor = .white
        callingLabel.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        callingLabel.textAlignment = .center
        callingLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Add labels to the view
        view.addSubview(phoneLabel)
        view.addSubview(callingLabel)
        
        // Constraints
        NSLayoutConstraint.activate([
            // Center phoneLabel horizontally and align it to the top with some padding
            phoneLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            phoneLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 70),
            // Center callingLabel horizontally and place it below phoneLabel with a smaller gap
            callingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            callingLabel.topAnchor.constraint(equalTo: phoneLabel.bottomAnchor, constant: 20) // Reduced spacing
        ])
    }
    
    func initButtons() {
        let appDelegate = MptCallkitPlugin.shared
        let isVideoCall = appDelegate.isVideoCall
        
        // Initialize Back Button
        addBackButton()
        
        // Initialize Swap Button (Only if Video Call)
        swapUIButton()
        
        // Initialize Small Video Call Button (Only if Audio Call)
        videoCallButton()
        
        // Initialize Other Buttons
        hangUpButton()
        speakButton()
        sendingVideo()
        initMuteButton()
        
        // Top Button Stack View
        var topButtonStackView: UIStackView
        if isVideoCall {
            // Create stack view with backButton and swapButton
            topButtonStackView = UIStackView(arrangedSubviews: [backButton, swapButton])
        } else {
            // Create stack view with backButton and smallVideoCallButton
            topButtonStackView = UIStackView(arrangedSubviews: [backButton])
        }
        
        topButtonStackView.axis = .horizontal
        topButtonStackView.alignment = .center
        topButtonStackView.spacing = 20
        topButtonStackView.distribution = .equalCentering
        topButtonStackView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(topButtonStackView)
        
        // Constraints for the Top Button Stack View
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            backButton.widthAnchor.constraint(equalToConstant: otherButtonSize),
            backButton.heightAnchor.constraint(equalToConstant: otherButtonSize),
        ])

        if isVideoCall {
            NSLayoutConstraint.activate([
                swapButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10),
                swapButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
                swapButton.widthAnchor.constraint(equalToConstant: (50 / 430) * deviceWidth),
                swapButton.heightAnchor.constraint(equalToConstant: (50 / 430) * deviceWidth)
            ])
        }
        
        // Bottom Button Stack View
        let bottomButtonStackView: UIStackView
        if isVideoCall {
            bottomButtonStackView = UIStackView(arrangedSubviews: [buttonSendingVideo, muteButton, buttonSpeaker, hangupButton])
        } else {
            bottomButtonStackView = UIStackView(arrangedSubviews: [smallVideoCallButton, muteButton, buttonSpeaker, hangupButton])
        }
        
        bottomButtonStackView.axis = .horizontal
        bottomButtonStackView.distribution = .equalSpacing
        bottomButtonStackView.alignment = .center
        bottomButtonStackView.spacing = spacing
        bottomButtonStackView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(bottomButtonStackView)
        
        // Constraints for the Bottom Button Stack View
        NSLayoutConstraint.activate([
            bottomButtonStackView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: leftRightSpacing),
            bottomButtonStackView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -leftRightSpacing),
            bottomButtonStackView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: (-40 / 430) * deviceWidth),
            bottomButtonStackView.heightAnchor.constraint(equalToConstant: otherButtonSize)
        ])
    }
    
    
    func addBackButton() {
        backButton?.removeFromSuperview()

        backButton = UIButton(type: .system)
        backButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
        backButton.tintColor = .white
        backButton.frame = CGRect(x: 0, y: 0, width: otherButtonSize, height: otherButtonSize)
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.widthAnchor.constraint(equalToConstant: otherButtonSize).isActive = true
        backButton.heightAnchor.constraint(equalToConstant: otherButtonSize).isActive = true
        backButton.imageView?.contentMode = .scaleAspectFit
        backButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    }
    
    func hangUpButton() {
        hangupButton?.removeFromSuperview()

        hangupButton = UIButton(type: .system)
        hangupButton.setImage(UIImage(systemName: "phone.down.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
        hangupButton.tintColor = .white
        hangupButton.backgroundColor = .red
        
        hangupButton.frame = CGRect(x: 0, y: 0, width: otherButtonSize, height: otherButtonSize)
        hangupButton.layer.cornerRadius = otherButtonSize / 2
        hangupButton.translatesAutoresizingMaskIntoConstraints = false
        hangupButton.widthAnchor.constraint(equalToConstant: CGFloat(otherButtonSize)).isActive = true
        hangupButton.heightAnchor.constraint(equalToConstant: otherButtonSize).isActive = true
        hangupButton.imageView?.contentMode = .scaleAspectFit
        hangupButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        hangupButton.addTarget(self, action: #selector(hangup(_:)), for: .touchUpInside)
    }
    
    func swapUIButton() {
        swapButton?.removeFromSuperview()

        swapButton = UIButton(type: .system)
        swapButton.setImage(UIImage(systemName: "camera.rotate.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
        swapButton.tintColor = .white
        swapButton.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        
        swapButton.frame = CGRect(x: 0, y: 0, width: otherButtonSize, height: otherButtonSize)
        swapButton.layer.cornerRadius = (50 / 430) * deviceWidth / 2
        swapButton.addTarget(self, action: #selector(onSwitchCameraClick(_:)), for: .touchUpInside)
        
        swapButton.translatesAutoresizingMaskIntoConstraints = false
        swapButton.widthAnchor.constraint(equalToConstant: otherButtonSize).isActive = true
        swapButton.heightAnchor.constraint(equalToConstant: otherButtonSize).isActive = true
        swapButton.imageView?.contentMode = .scaleAspectFit
        swapButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
    }
    
    func videoCallButton() {
        smallVideoCallButton?.removeFromSuperview()

        smallVideoCallButton = UIButton(type: .system)
        smallVideoCallButton.setImage(UIImage(systemName: "video.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
        smallVideoCallButton.tintColor = .white
        smallVideoCallButton.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        
        smallVideoCallButton.frame = CGRect(x: 0, y: 0, width: otherButtonSize, height: otherButtonSize)
        smallVideoCallButton.layer.cornerRadius = otherButtonSize / 2
        smallVideoCallButton.addTarget(self, action: #selector(activeVideoCall(_:)), for: .touchUpInside)
        
        smallVideoCallButton.translatesAutoresizingMaskIntoConstraints = false
        smallVideoCallButton.widthAnchor.constraint(equalToConstant: otherButtonSize).isActive = true
        smallVideoCallButton.heightAnchor.constraint(equalToConstant: otherButtonSize).isActive = true
        smallVideoCallButton.imageView?.contentMode = .scaleAspectFit
        smallVideoCallButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    }
    
    func initMuteButton() {
        if speakState == 0 {
            portSIPSDK.setLoudspeakerStatus(true)
        } else {
            portSIPSDK.setLoudspeakerStatus(false)
        }

        muteButton?.removeFromSuperview()
        muteButton = UIButton(type: .system)
        muteButton.setImage(UIImage(systemName: "speaker.3.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
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
        buttonSpeaker?.removeFromSuperview()
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
        buttonSendingVideo?.removeFromSuperview()
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
        let sessionId = MptCallkitPlugin.shared.activeSessionid
        if (sessionId == nil) {
            return
        }
        if muteMic {
            muteMic = false
            portSIPSDK.muteSession(sessionId!, muteIncomingAudio: false, muteOutgoingAudio: true, muteIncomingVideo: false, muteOutgoingVideo: false)
            buttonSpeaker.setImage(UIImage(systemName: "mic.slash.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
        } else {
            muteMic = true
            portSIPSDK.muteSession(sessionId!, muteIncomingAudio: false, muteOutgoingAudio: false, muteIncomingVideo: false, muteOutgoingVideo: false)
            buttonSpeaker.setImage(UIImage(systemName: "mic.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
        }
    }
    
    @objc func backButtonTapped() {
        let alert = UIAlertController(title: "Kết thúc cuộc gọi", message: "Bạn có muốn dừng cuộc gọi không?", preferredStyle: UIAlertController.Style.alert)
        // Add "Cancel" action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { action in
            print("Cancel button tapped")
        }
        alert.addAction(cancelAction)
        
        // Add a custom action
        let customAction = UIAlertAction(title: "OK", style: .destructive) { action in
            self.onClearState()
            MptCallkitPlugin.shared.hungUpCall()
            MptCallkitPlugin.shared.loginViewController.unRegister()
            self.dismiss(animated: true, completion: nil)
        }
        alert.addAction(customAction)
        present(alert, animated: true, completion: nil)
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
        if sendState {
            viewLocalVideo.isHidden = true
            portSIPSDK.sendVideo(sessionId, sendState: false)
            buttonSendingVideo.setImage(UIImage(systemName: "video.slash.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
            sendState = false
        } else {
            portSIPSDK.sendVideo(sessionId, sendState: true)
            viewLocalVideo.isHidden = false
            buttonSendingVideo.setImage(UIImage(systemName: "video.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
            sendState = true
        }
    }
    
    @objc func onMuteClick(_ sender: AnyObject) {
        let sessionId = MptCallkitPlugin.shared.activeSessionid
        if (sessionId == nil) {
            return
        }
        if speakState == 0 {
            speakState = 1
            portSIPSDK.setLoudspeakerStatus(false)
            muteButton.setImage(UIImage(systemName: "speaker.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
        } else {
            speakState = 0
            portSIPSDK.setLoudspeakerStatus(true)
            muteButton.setImage(UIImage(systemName: "speaker.3.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
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
                portSIPSDK.sendVideo(sessionId, sendState: true)
            } else {
                self.viewRemoteVideoSmall?.isHidden = true
                portSIPSDK.setRemoteVideoWindow(sessionId, remoteVideoWindow: nil)
                portSIPSDK.setRemoteScreenWindow(sessionId, remoteScreenWindow: nil)
            }
        }
    }
    
    func onStartVideo(_ sessionID: Int) {
        DispatchQueue.main.async {
            self.isStartVideo = true
            self.isInitVideo = true
            self.sessionId = sessionID
            self.shareInSmallWindow = true
            // Hide calling label when remote video starts
            self.callingLabel.isHidden = false
            self.startCallTimer()
            self.viewRemoteVideo.isHidden = false
            self.viewRemoteVideoSmall.isHidden = false
            
            self.initializeVideoViews()
            self.viewRemoteVideo.initVideoRender()
            self.viewRemoteVideoSmall.initVideoRender()
            
            // Display local video and set remote video windows
            self.checkDisplayVideo()
        }
    }
    
    @objc func activeVideoCall(_ sender: AnyObject) {
        NSLog("updateCall...")
        let appDelegate = MptCallkitPlugin.shared
        appDelegate.isVideoCall = true
        initVideoViews()
        initButtons()
        appDelegate.updateCall()
    }
    
    func onStartVoiceCall(_ sessionID: Int) {
        DispatchQueue.main.async {
           self.isStartVideo = false
            self.isInitVideo = false
            self.sessionId = sessionID
            self.shareInSmallWindow = false
            // Hide calling label when remote video starts
            self.callingLabel.isHidden = false
            self.startCallTimer()
            
            self.initializeVideoViews()
            self.checkDisplayVideo()
        }
    }
    
    func onStopVideo(_: Int) {
        DispatchQueue.main.async {
            self.isStartVideo = false
            self.checkDisplayVideo()
            self.callingLabel.isHidden = false
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
    
    func initializeVideoViews() {
        // Remove previous views if they exist (in case cleanup wasn’t complete)
        viewRemoteVideo?.removeFromSuperview()
        viewRemoteVideoSmall?.removeFromSuperview()
        
        // Re-add and initialize views
        initRemoteVideo() // This will reset and add constraints
        initButtons()
        // Check if the outlets are properly initialized
        isInitVideo = true
        callingLabel.isHidden = true
        
        let appDelegate = MptCallkitPlugin.shared
        let isVideoCall = appDelegate.isVideoCall
        if isVideoCall {
            viewRemoteVideo.initVideoRender()
            viewRemoteVideo.contentMode = .scaleAspectFit
            viewRemoteVideoSmall.initVideoRender()
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onSwichShareScreenClick(action:)))
            viewRemoteVideo.isHidden = false
            viewRemoteVideoSmall.isHidden = false
        }
    }
    
    func onClearState() {
        stopCallTimer() // Stop the timer

        viewLocalVideo?.releaseVideoRender()
        viewLocalVideo?.removeFromSuperview()
        viewLocalVideo?.isHidden = true

        let appDelegate = MptCallkitPlugin.shared
        let isVideoCall = appDelegate.isVideoCall
        if isVideoCall {
            portSIPSDK.displayLocalVideo(false, mirror: false, localVideoWindow: nil)
            viewLocalVideo.releaseVideoRender()
            if isStartVideo {
                portSIPSDK.setRemoteVideoWindow(sessionId, remoteVideoWindow: nil)
                portSIPSDK.setRemoteScreenWindow(sessionId, remoteScreenWindow: nil)
                
                viewRemoteVideo.releaseVideoRender()
                viewRemoteVideoSmall.releaseVideoRender()
                
                viewRemoteVideo.removeFromSuperview()
                viewRemoteVideoSmall.removeFromSuperview()
            }
            portSIPSDK.sendVideo(sessionId, sendState: false)
            
            isStartVideo = false
            sessionId = 0
        }
        
        self.dismiss(animated: true, completion: nil)
    }
    
    func startCallTimer() {
        // Reset duration
        callDuration = 0
        
        // Invalidate existing timer
        callTimer?.invalidate()
        
        // Create a new timer
        callTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.callDuration += 1
            
            // Calculate hours, minutes, and seconds
            let hours = self.callDuration / 3600
            let minutes = (self.callDuration % 3600) / 60
            let seconds = self.callDuration % 60
            
            // Format duration as HH:MM:SS
            self.callingLabel.text = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }

    func stopCallTimer() {
        callTimer?.invalidate()
        callTimer = nil
    }
}
