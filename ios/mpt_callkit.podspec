#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint mpt_callkit.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'mpt_callkit'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*.{h,m,mm,swift}'
  s.resources    = ['Assets/**.*']
  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'
  s.static_framework = true

  # System frameworks - these are frameworks provided by Apple that you want to link with
  s.frameworks = ['Network', 'GLKit', 'MetalKit', 'CoreAudio', 'VideoToolbox', 'AVFoundation', 'Vision', 'CoreImage', 'Accelerate']

  # Libraries to link (in this case, C++ and resolv libraries)
  s.libraries = ['c++', 'resolv']

  # Additional linker flags
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }

  s.preserve_paths = 'SDK/PortSIPVoIPSDK.xcframework/**/*'
  s.xcconfig = { 'OTHER_LDFLAGS' => '-framework PortSIPVoIPSDK' }
  s.vendored_frameworks = 'SDK/PortSIPVoIPSDK.xcframework'
  s.prepare_command = <<-CMD
    mkdir -p SDK
    if [ ! -d "SDK/PortSIPVoIPSDK.xcframework" ]; then
      echo "PortSIPVoIPSDK.xcframework not found in SDK. Downloading..."
      curl -L -o SDK/PortSIPVoIPSDK.xcframework.zip https://github.com/mpt-hienhh/PortSIPVoiPSDK/raw/main/PortSIPVoIPSDK.xcframework.zip
      unzip SDK/PortSIPVoIPSDK.xcframework.zip -d SDK
      rm SDK/PortSIPVoIPSDK.xcframework.zip
    else
      echo "PortSIPVoIPSDK.xcframework already exists in SDK."
    fi
  CMD

  s.info_plist = {
  'NSCameraUsageDescription' => 'For video call',
  'NSMicrophoneUsageDescription' => 'For audio call',
  }

  s.swift_version = '5.0'
end
