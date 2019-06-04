# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

source 'https://cdn.cocoapods.org/'

target 'Construct' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  pod 'GRDB.swift'
  pod 'AppCenter'
end

post_install do |installer|
  installer.pods_project.targets.select { |target| target.name == "GRDB.swift" }.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['OTHER_SWIFT_FLAGS'] = "$(inherited) -D SQLITE_ENABLE_FTS5"
    end
  end
end
