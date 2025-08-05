import UIKit
import PortSIPVoIPSDK

// MARK: - Safe CoreGraphics Extensions
extension CGFloat {
    var safeValue: CGFloat {
        return isFinite ? self : 0.0
    }
    
    static func safeDivision(_ numerator: CGFloat, _ denominator: CGFloat) -> CGFloat {
        guard denominator != 0 && denominator.isFinite && numerator.isFinite else {
            return 0.0
        }
        let result = numerator / denominator
        return result.isFinite ? result : 0.0
    }
}

extension CGRect {
    var isSafe: Bool {
        return origin.x.isFinite && origin.y.isFinite && 
               size.width.isFinite && size.height.isFinite &&
               size.width >= 0 && size.height >= 0
    }
    
    var safeRect: CGRect {
        return CGRect(
            x: origin.x.safeValue,
            y: origin.y.safeValue,
            width: max(0, size.width.safeValue),
            height: max(0, size.height.safeValue)
        )
    }
}

class VideoViewController: UIViewController {
    var mCameraDeviceId: Int = 1 // 1 - FrontCamera 0 - BackCamera
    var speakState: Int = 0 // 1 - Headphone 0 - speaker
    var mSoundService: SoundService!
    var muteState: Bool = true
    var muteMic: Bool = true
    var mLocalVideoWidth: Int = 352 {
        didSet {
            // Validate video width to prevent invalid calculations
            if mLocalVideoWidth <= 0 {
                NSLog("VideoViewController - Invalid video width: \(mLocalVideoWidth), resetting to 352")
                mLocalVideoWidth = 352
            }
        }
    }
    var mLocalVideoHeight: Int = 288 {
        didSet {
            // Validate video height to prevent invalid calculations
            if mLocalVideoHeight <= 0 {
                NSLog("VideoViewController - Invalid video height: \(mLocalVideoHeight), resetting to 288")
                mLocalVideoHeight = 288
            }
        }
    }
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
    // var viewRemoteVideoSmall: PortSIPVideoRenderView!
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
        // Initialize the views with safe calculations
        
        // Validate deviceWidth to prevent NaN calculations
        guard deviceWidth > 0 && deviceWidth.isFinite else {
            NSLog("VideoViewController - Invalid device width: \(deviceWidth)")
            otherButtonSize = 60.0  // fallback value
            leftRightSpacing = 20.0  // fallback value
            spacing = 10.0  // fallback value
            return
        }
        
        otherButtonSize = (70.0 / 430.0) * deviceWidth
        leftRightSpacing = (20.0 / 430.0) * deviceWidth
        spacing = (10.0 / 430.0) * deviceWidth
        
        // Validate calculated values
        guard otherButtonSize.isFinite && leftRightSpacing.isFinite && spacing.isFinite else {
            NSLog("VideoViewController - Invalid calculated dimensions")
            otherButtonSize = 60.0  // fallback value
            leftRightSpacing = 20.0  // fallback value
            spacing = 10.0  // fallback value
            // Continue with initialization even with fallback values
            mSoundService = SoundService()
            initVideoViews()
            initButtons()
            hideButtons()
            initCallingLabel()
            return
        }
        
        mSoundService = SoundService()
        initVideoViews()
        initButtons()
        hideButtons()
        initCallingLabel()
    }
    
    func initVideoViews() {
        DispatchQueue.main.async {
            self.viewLocalVideo?.removeFromSuperview()
            self.viewLocalVideo?.isHidden = true
            ///Khởi tạo với isVideoCall = true
            let appDelegate = MptCallkitPlugin.shared
            NSLog("isVideoCall init: \(appDelegate.isVideoCall)")
            if (appDelegate.isVideoCall) {
                self.viewRemoteVideo = PortSIPVideoRenderView()
                self.viewRemoteVideo.translatesAutoresizingMaskIntoConstraints = false
                self.viewRemoteVideo.backgroundColor = .black
                self.view.addSubview(self.viewRemoteVideo)
                self.viewLocalVideo = PortSIPVideoRenderView()
                self.viewLocalVideo.translatesAutoresizingMaskIntoConstraints = false
                self.viewLocalVideo.backgroundColor = .darkGray
                self.viewLocalVideo.layer.cornerRadius = 10
                self.viewLocalVideo.layer.masksToBounds = true
                self.view.addSubview(self.viewLocalVideo)
                // viewRemoteVideoSmall = PortSIPVideoRenderView()
                // viewRemoteVideoSmall.translatesAutoresizingMaskIntoConstraints = false
                // self.view.addSubview(viewRemoteVideoSmall)
                
                NSLayoutConstraint.activate([
                    // Constraints for the remote video (full screen)
                    self.viewRemoteVideo.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
                    self.viewRemoteVideo.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor),
                    self.viewRemoteVideo.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor),
                    self.viewRemoteVideo.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor),
                    
                    // Constraints for the local video (custom size) - change the size here
                    self.viewLocalVideo.widthAnchor.constraint(equalToConstant: 130),
                    self.viewLocalVideo.heightAnchor.constraint(equalToConstant: 180),
                    self.viewLocalVideo.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: (-70 / 430) * self.deviceWidth - self.otherButtonSize),
                    self.viewLocalVideo.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -10),
                    
                    // Constraints for the small remote video (top right corner)
                    // viewRemoteVideoSmall.widthAnchor.constraint(equalToConstant: 144),
                    // viewRemoteVideoSmall.heightAnchor.constraint(equalTo: viewRemoteVideoSmall.widthAnchor),
                    // viewRemoteVideoSmall.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
                    // viewRemoteVideoSmall.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10)
                ])
                // Check if the outlets are properly initialized
                self.isInitVideo = true
                
                self.viewLocalVideo.initVideoRender()
                self.viewRemoteVideo.initVideoRender()
                self.viewRemoteVideo.contentMode = .scaleAspectFit
                // viewRemoteVideoSmall.initVideoRender()
                self.updateLocalVideoPosition(UIScreen.main.bounds.size)

                self.portSIPSDK.displayLocalVideo(true, mirror: self.mCameraDeviceId == 1, localVideoWindow: self.viewLocalVideo)
                
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.onSwichShareScreenClick(action:)))
                // viewRemoteVideoSmall.addGestureRecognizer(tapGesture)
                
                self.updateLocalVideoPosition(UIScreen.main.bounds.size)
                return;
            } else {
                self.viewLocalVideo?.releaseVideoRender()
                self.viewLocalVideo?.removeFromSuperview()
                self.viewLocalVideo?.isHidden = true
            }
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
            // viewRemoteVideoSmall = PortSIPVideoRenderView()
            // viewRemoteVideoSmall.translatesAutoresizingMaskIntoConstraints = false
            // self.view.addSubview(viewRemoteVideoSmall)
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
                // viewRemoteVideoSmall.widthAnchor.constraint(equalToConstant: 144),
                // viewRemoteVideoSmall.heightAnchor.constraint(equalTo: viewRemoteVideoSmall.widthAnchor),
                // viewRemoteVideoSmall.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
                // viewRemoteVideoSmall.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10)
            ])
            // Check if the outlets are properly initialized
            isInitVideo = true
            
            viewRemoteVideo.initVideoRender()
            viewRemoteVideo.contentMode = .scaleAspectFit
            // viewRemoteVideoSmall.initVideoRender()
            updateLocalVideoPosition(UIScreen.main.bounds.size)
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onSwichShareScreenClick(action:)))
            // viewRemoteVideoSmall.addGestureRecognizer(tapGesture)
            
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
        DispatchQueue.main.async {
            self.hangupButton?.removeFromSuperview()

            self.hangupButton = UIButton(type: .system)
            self.hangupButton.setImage(UIImage(systemName: "phone.down.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
            self.hangupButton.tintColor = .white
            self.hangupButton.backgroundColor = .red
            
            self.hangupButton.frame = CGRect(x: 0, y: 0, width: self.otherButtonSize, height: self.otherButtonSize)
            self.hangupButton.layer.cornerRadius = self.otherButtonSize / 2
            self.hangupButton.translatesAutoresizingMaskIntoConstraints = false
            self.hangupButton.widthAnchor.constraint(equalToConstant: CGFloat(self.otherButtonSize)).isActive = true
            self.hangupButton.heightAnchor.constraint(equalToConstant: self.otherButtonSize).isActive = true
            self.hangupButton.imageView?.contentMode = .scaleAspectFit
            self.hangupButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
            self.hangupButton.addTarget(self, action: #selector(self.hangup(_:)), for: .touchUpInside)
        }
    }
    
    func swapUIButton() {
        DispatchQueue.main.async {
            self.swapButton?.removeFromSuperview()

            self.swapButton = UIButton(type: .system)
            self.swapButton.setImage(UIImage(systemName: "camera.rotate.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
            self.swapButton.tintColor = .white
            self.swapButton.backgroundColor = UIColor.white.withAlphaComponent(0.3)
            
            self.swapButton.frame = CGRect(x: 0, y: 0, width: self.otherButtonSize, height: self.otherButtonSize)
            self.swapButton.layer.cornerRadius = (50 / 430) * self.deviceWidth / 2
            self.swapButton.addTarget(self, action: #selector(self.onSwitchCameraClick(_:)), for: .touchUpInside)
            
            self.swapButton.translatesAutoresizingMaskIntoConstraints = false
            self.swapButton.widthAnchor.constraint(equalToConstant: self.otherButtonSize).isActive = true
            self.swapButton.heightAnchor.constraint(equalToConstant: self.otherButtonSize).isActive = true
            self.swapButton.imageView?.contentMode = .scaleAspectFit
            self.swapButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        }
    }
    
    func videoCallButton() {
        DispatchQueue.main.async {
            self.smallVideoCallButton?.removeFromSuperview()

            self.smallVideoCallButton = UIButton(type: .system)
            self.smallVideoCallButton.setImage(UIImage(systemName: "video.badge.plus.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
            self.smallVideoCallButton.tintColor = .white
            self.smallVideoCallButton.backgroundColor = UIColor.white.withAlphaComponent(0.5)
            
            self.smallVideoCallButton.frame = CGRect(x: 0, y: 0, width: self.otherButtonSize, height: self.otherButtonSize)
            self.smallVideoCallButton.layer.cornerRadius = self.otherButtonSize / 2
            self.smallVideoCallButton.addTarget(self, action: #selector(self.activeVideoCall(_:)), for: .touchUpInside)
            
            self.smallVideoCallButton.translatesAutoresizingMaskIntoConstraints = false
            self.smallVideoCallButton.widthAnchor.constraint(equalToConstant: self.otherButtonSize).isActive = true
            self.smallVideoCallButton.heightAnchor.constraint(equalToConstant: self.otherButtonSize).isActive = true
            self.smallVideoCallButton.imageView?.contentMode = .scaleAspectFit
            self.smallVideoCallButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        }
    }

    func hideButtons() {
        DispatchQueue.main.async {
            self.swapButton.isHidden = true
            self.hangupButton.isHidden = true
            self.smallVideoCallButton.isHidden = true
            self.muteButton.isHidden = true
            self.buttonSpeaker.isHidden = true
            self.buttonSendingVideo.isHidden = true
        }
    }

    func showButtons() {
        
    }
    
    func initMuteButton() {
        DispatchQueue.main.async {
            self.muteButton?.removeFromSuperview()
            self.muteButton = UIButton(type: .system)
            if self.speakState == 0{
                self.portSIPSDK.setLoudspeakerStatus(true)
                self.muteButton.setImage(UIImage(systemName: "speaker.3.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
            } else{
                self.portSIPSDK.setLoudspeakerStatus(false)
                self.muteButton.setImage(UIImage(systemName: "speaker.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
            }
            self.muteButton.tintColor = .white
            self.muteButton.backgroundColor = UIColor.gray.withAlphaComponent(0.5)
            
            self.muteButton.frame = CGRect(x: 0, y: 0, width: self.otherButtonSize, height: self.otherButtonSize)
            self.muteButton.layer.cornerRadius = self.otherButtonSize / 2
            self.muteButton.addTarget(self, action: #selector(self.onMuteClick(_:)), for: .touchUpInside)
            
            self.muteButton.translatesAutoresizingMaskIntoConstraints = false
            self.muteButton.widthAnchor.constraint(equalToConstant: self.otherButtonSize).isActive = true
            self.muteButton.heightAnchor.constraint(equalToConstant: self.otherButtonSize).isActive = true
            self.muteButton.imageView?.contentMode = .scaleAspectFit
            self.muteButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        }
    }
    
    func speakButton() {
        DispatchQueue.main.async {
            self.buttonSpeaker?.removeFromSuperview()
            self.buttonSpeaker = UIButton(type: .system)
            if self.muteMic {
                self.portSIPSDK.muteSession(self.sessionId, muteIncomingAudio: false, muteOutgoingAudio: false, muteIncomingVideo: false, muteOutgoingVideo: false)
                self.buttonSpeaker.setImage(UIImage(systemName: "mic.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
            } else {
                self.portSIPSDK.muteSession(self.sessionId, muteIncomingAudio: false, muteOutgoingAudio: true, muteIncomingVideo: false, muteOutgoingVideo: false)
                self.buttonSpeaker.setImage(UIImage(systemName: "mic.slash.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
            }

            self.buttonSpeaker.tintColor = .white
            self.buttonSpeaker.backgroundColor = UIColor.gray.withAlphaComponent(0.5)
            
            self.buttonSpeaker.frame = CGRect(x: 0, y: 0, width: self.otherButtonSize, height: self.otherButtonSize)
            self.buttonSpeaker.layer.cornerRadius = self.otherButtonSize / 2
            self.buttonSpeaker.addTarget(self, action: #selector(self.onSwitchSpeakerClick(_:)), for: .touchUpInside)
            
            self.buttonSpeaker.translatesAutoresizingMaskIntoConstraints = false
            self.buttonSpeaker.widthAnchor.constraint(equalToConstant: self.otherButtonSize).isActive = true
            self.buttonSpeaker.heightAnchor.constraint(equalToConstant: self.otherButtonSize).isActive = true
            self.buttonSpeaker.imageView?.contentMode = .scaleAspectFit
            self.buttonSpeaker.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        }
    }
    
    func sendingVideo() {
        DispatchQueue.main.async {
            self.buttonSendingVideo?.removeFromSuperview()
            self.buttonSendingVideo = UIButton(type: .system)
            self.buttonSendingVideo.setImage(UIImage(systemName: "video.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
            self.buttonSendingVideo.tintColor = .white
            self.buttonSendingVideo.backgroundColor = UIColor.gray.withAlphaComponent(0.5)
            
            self.buttonSendingVideo.frame = CGRect(x: 0, y: 0, width: self.otherButtonSize, height: self.otherButtonSize)
            self.buttonSendingVideo.layer.cornerRadius = self.otherButtonSize / 2
            self.buttonSendingVideo.addTarget(self, action: #selector(self.onSendingVideoClick(_:)), for: .touchUpInside)
            
            self.buttonSendingVideo.translatesAutoresizingMaskIntoConstraints = false
            self.buttonSendingVideo.widthAnchor.constraint(equalToConstant: self.otherButtonSize).isActive = true
            self.buttonSendingVideo.heightAnchor.constraint(equalToConstant: self.otherButtonSize).isActive = true
            self.buttonSendingVideo.imageView?.contentMode = .scaleAspectFit
            self.buttonSendingVideo.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        }
    }
    
    @objc func onSwitchSpeakerClick(_ sender: AnyObject) {
        let plugin = MptCallkitPlugin.shared
        let sessionId = plugin.activeSessionid
        
        if sessionId == nil || sessionId == 0 {
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
        let customAction = UIAlertAction(title: "OK", style: .destructive) { [weak self] action in
            guard let self = self else { return }
            
            // Fix: Properly dismiss keyboard and end editing to prevent RTIInputSystemClient warnings
            self.view.endEditing(true)
            
            self.onClearState()
            MptCallkitPlugin.shared.hangUpCall()
            MptCallkitPlugin.shared.loginViewController.unRegister()
            
            // Fix: Add delay to ensure cleanup completes before dismissal
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.dismiss(animated: true, completion: nil)
            }
        }
        alert.addAction(customAction)
        // Fix: Only present alert if view controller is in window hierarchy
        if view.window != nil && presentedViewController == nil {
            present(alert, animated: true, completion: nil)
        }
    }
    
    @objc func onSwitchCameraClick(_ sender: AnyObject) {
        if mCameraDeviceId == 0 {
            if portSIPSDK.setVideoDeviceId(1) == 0 {
                mCameraDeviceId = 1
                // Khi chuyển sang camera trước, bật mirror
                portSIPSDK.displayLocalVideo(true, mirror: true, localVideoWindow: viewLocalVideo)
                swapButton.setImage(UIImage(systemName: "camera.rotate.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large)), for: .normal)
            }
        } else {
            if portSIPSDK.setVideoDeviceId(0) == 0 {
                mCameraDeviceId = 0
                // Khi chuyển sang camera sau, tắt mirror
                portSIPSDK.displayLocalVideo(true, mirror: false, localVideoWindow: viewLocalVideo)
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
        let plugin = MptCallkitPlugin.shared
        let sessionId = plugin.activeSessionid
        if sessionId == nil || sessionId == 0 {
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
            
            // Validate video dimensions to prevent NaN calculations
            guard self.mLocalVideoWidth > 0 && self.mLocalVideoHeight > 0 else {
                NSLog("VideoViewController - Invalid video dimensions: width=\(self.mLocalVideoWidth), height=\(self.mLocalVideoHeight)")
                return
            }
            
            // Validate screen size to prevent NaN calculations
            guard screenSize.width > 0 && screenSize.height > 0 && 
                  screenSize.width.isFinite && screenSize.height.isFinite else {
                NSLog("VideoViewController - Invalid screen size: \(screenSize)")
                return
            }
            
            if screenSize.width > screenSize.height {
                // Landscape
                var rectLocal: CGRect = self.viewLocalVideo.frame
                rectLocal.size.width = 176
                
                // Safe calculation to prevent NaN
                let aspectRatio = CGFloat(self.mLocalVideoHeight) / CGFloat(self.mLocalVideoWidth)
                rectLocal.size.height = rectLocal.size.width * aspectRatio
                
                // Validate calculated values
                guard rectLocal.size.height.isFinite && rectLocal.size.height > 0 else {
                    NSLog("VideoViewController - Invalid calculated height in landscape: \(rectLocal.size.height)")
                    return
                }
                
                rectLocal.origin.x = screenSize.width - rectLocal.size.width - 10
                rectLocal.origin.y = 10
                
                // Final safety check before setting frame
                if rectLocal.isSafe {
                    self.viewLocalVideo.frame = rectLocal
                } else {
                    NSLog("VideoViewController - Unsafe frame calculated for landscape: \(rectLocal)")
                    self.viewLocalVideo.frame = rectLocal.safeRect
                }
            } else {
                // Portrait
                var rectLocal: CGRect = self.viewLocalVideo.frame
                rectLocal.size.width = 144
                
                // Safe calculation to prevent NaN
                let aspectRatio = CGFloat.safeDivision(CGFloat(self.mLocalVideoWidth), CGFloat(self.mLocalVideoHeight))
                rectLocal.size.height = rectLocal.size.width * aspectRatio
                
                // Validate calculated values
                guard rectLocal.size.height.isFinite && rectLocal.size.height > 0 else {
                    NSLog("VideoViewController - Invalid calculated height in portrait: \(rectLocal.size.height)")
                    return
                }
                
                rectLocal.origin.x = screenSize.width - rectLocal.size.width - 10
                rectLocal.origin.y = 30
                
                // Final safety check before setting frame
                if rectLocal.isSafe {
                    self.viewLocalVideo.frame = rectLocal
                } else {
                    NSLog("VideoViewController - Unsafe frame calculated for portrait: \(rectLocal)")
                    self.viewLocalVideo.frame = rectLocal.safeRect
                }
            }
        }
    }
    
    func checkDisplayVideo() {
        let appDelegate = MptCallkitPlugin.shared
        guard let result = appDelegate._callManager.findCallBySessionID(sessionId) else {
            return
        }
        
        if self.isInitVideo {
            if self.isStartVideo {
                // self.viewRemoteVideoSmall.isHidden = !result.session.screenShare
                if self.shareInSmallWindow {
                    portSIPSDK.setRemoteScreenWindow(sessionId, remoteScreenWindow: viewRemoteVideo)
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
                        portSIPSDK.setConferenceVideoWindow(viewRemoteVideo)
                    } else {
                        portSIPSDK.setRemoteVideoWindow(sessionId, remoteVideoWindow: viewRemoteVideo)
                        portSIPSDK.setConferenceVideoWindow(nil)
                    }
                }
                portSIPSDK.sendVideo(sessionId, sendState: true)
            } else {
                // self.viewRemoteVideoSmall?.isHidden = true
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
            // self.viewRemoteVideoSmall.isHidden = false
            
            self.initializeVideoViews()
            self.viewRemoteVideo.initVideoRender()
            // self.viewRemoteVideoSmall.initVideoRender()
            
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
        
        // Fix: Dismiss keyboard before rotation to prevent RTIInputSystemClient warnings
        view.endEditing(true)
        
        coordinator.animate(alongsideTransition: { _ in
            // Fix: Only update video position if view is still in window hierarchy
            if self.view.window != nil {
                self.updateLocalVideoPosition(size)
            }
        })
    }
    
    @objc func hangup(_ sender: AnyObject) {
        // Fix: Properly dismiss keyboard and end editing to prevent RTIInputSystemClient warnings
        view.endEditing(true)
        
        MptCallkitPlugin.shared.hangUpCall()
        MptCallkitPlugin.shared.loginViewController.unRegister()
        onClearState()
        
        // Fix: Add delay to ensure cleanup completes before dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    func initializeVideoViews() {
        // Remove previous views if they exist (in case cleanup wasn't complete)
        viewRemoteVideo?.removeFromSuperview()
        // viewRemoteVideoSmall?.removeFromSuperview()
        
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
            // viewRemoteVideoSmall.initVideoRender()
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onSwichShareScreenClick(action:)))
            viewRemoteVideo.isHidden = false
            // viewRemoteVideoSmall.isHidden = false
        }
    }
    
    func onClearState() {
        DispatchQueue.main.async {
            self.stopCallTimer()
            
            // Cleanup audio
            self.speakState = 0
            self.portSIPSDK.setLoudspeakerStatus(true)
            self.muteState = true
            self.muteMic = true
            
            // Cleanup video resources
            // if let appDelegate = MptCallkitPlugin.shared,
            //    appDelegate.isVideoCall {
            let plugin = MptCallkitPlugin.shared
            if plugin.isVideoCall{
                self.portSIPSDK.displayLocalVideo(false, mirror: true, localVideoWindow: nil)
                self.viewLocalVideo?.releaseVideoRender()
                
                if self.isStartVideo {
                    self.portSIPSDK.setRemoteVideoWindow(self.sessionId, remoteVideoWindow: nil)
                    self.portSIPSDK.setRemoteScreenWindow(self.sessionId, remoteScreenWindow: nil)
                    
                    self.viewRemoteVideo?.releaseVideoRender()
                    self.viewRemoteVideo?.removeFromSuperview()
                }
                
                self.portSIPSDK.sendVideo(self.sessionId, sendState: false)
            }
            
            // Reset session
            self.isStartVideo = false
            self.sessionId = 0
            
//            // Force unregister SIP
//            MptCallkitPlugin.shared.loginViewController.offLine()
        }
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
