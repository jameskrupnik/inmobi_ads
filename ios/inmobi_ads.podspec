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
  s.author           = { 'James Krupnik' => 'jameskrupnik@gmail.com' }
  s.source           = { :path => '.' }
  # Shared with Swift Package Manager; see inmobi_ads/Package.swift.
  s.source_files     = 'inmobi_ads/Sources/inmobi_ads/**/*.swift'

  s.dependency 'Flutter'
  # 11.4.x, the API surface the native code is written against. Keep in step
  # with the range in inmobi_ads/Package.swift.
  s.dependency 'InMobiSDK', '~> 11.4.1'

  s.platform = :ios, '13.0'
  s.static_framework = true

  # Flutter.framework does not contain an i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end
