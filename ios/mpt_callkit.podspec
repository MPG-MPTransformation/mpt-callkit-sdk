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
  s.source           = { :path => '.', :http => 'file:///SDK/PortSIPVoIPSDK.xcframework.zip', :flatten => false}
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'

  # System frameworks - these are frameworks provided by Apple that you want to link with
  s.frameworks = ['Network', 'GLKit', 'MetalKit', 'CoreAudio', 'VideoToolbox']

  # Libraries to link (in this case, C++ and resolv libraries)
  s.libraries = ['c++', 'resolv']

  # Additional linker flags
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }

  s.info_plist = {
  'NSCameraUsageDescription' => 'For video call',
  'NSMicrophoneUsageDescription' => 'For audio call',
  }

  s.swift_version = '5.0'
end
