Pod::Spec.new do |s|
  s.name             = 'inmobi_ads'
  s.version          = '0.1.0'
  s.summary          = 'Direct Flutter integration for the InMobi advertising SDK.'
  s.description      = <<-DESC
Rewarded video, interstitial and banner ads from InMobi on Android and iOS,
integrated directly against the native SDKs with no mediation layer.
                       DESC
  s.homepage         = 'https://github.com/jameskrupnik/inmobi_ads'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Illumination Development' => 'james.krupnik@illuminationdevelopment.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'

  s.dependency 'Flutter'
  s.dependency 'InMobiSDK', '~> 11.4'

  s.platform = :ios, '13.0'
  s.static_framework = true

  # Flutter.framework does not contain an i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end
