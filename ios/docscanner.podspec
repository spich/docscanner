#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint docscanner.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'docscanner'
  s.version          = '1.0.0'
  s.summary          = 'Flutter plugin for scanning documents, optimized for POS receipts.'
  s.description      = <<-DESC
Flutter plugin for scanning documents and receipts with OCR text extraction.
Uses VisionKit for document scanning and Vision framework for text recognition.
                       DESC
  s.homepage         = 'https://github.com/spich/docscanner'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  
  # Required frameworks
  s.frameworks = 'VisionKit', 'Vision', 'UIKit'
end
