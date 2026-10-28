require 'json'
require 'xcodeproj'

state = JSON.parse(File.read(ARGV.fetch(0)))
project = Xcodeproj::Project.open(ARGV.fetch(1, 'ios/Runner.xcodeproj'))
runner = project.targets.find { |target| target.name == 'Runner' }
raise 'Runner target missing' unless runner

runner.build_configurations.each do |configuration|
  settings = configuration.build_settings
  raise 'Unexpected app identifier' unless settings['PRODUCT_BUNDLE_IDENTIFIER'] == state.fetch('bundle_id')
  settings['CODE_SIGN_STYLE'] = 'Manual'
  settings['DEVELOPMENT_TEAM'] = state.fetch('team_id')
  settings['CODE_SIGN_IDENTITY'] = state.fetch('identity_sha1')
  settings['CODE_SIGN_IDENTITY[sdk=iphoneos*]'] = state.fetch('identity_sha1')
  settings['PROVISIONING_PROFILE_SPECIFIER'] = state.fetch('profile_uuid')
end
project.save
puts 'Configured Runner signing for this CI checkout.'
