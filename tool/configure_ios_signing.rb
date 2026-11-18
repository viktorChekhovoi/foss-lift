require 'json'
require 'xcodeproj'

state = JSON.parse(File.read(ARGV.fetch(0)))
project = Xcodeproj::Project.open(ARGV.fetch(1, 'ios/Runner.xcodeproj'))
bundle_ids = { 'Runner' => 'com.fosslift.fosslift', 'WorkoutActivity' => 'com.fosslift.fosslift.WorkoutActivity' }
bundle_ids.each do |name, bundle_id|
  target = project.targets.find { |item| item.name == name }
  raise "Missing signing target #{name}" unless target
  profile = state.fetch('profiles').fetch(bundle_id)
  target.build_configurations.each do |configuration|
    settings = configuration.build_settings
    raise "Unexpected identifier for #{name}" unless settings['PRODUCT_BUNDLE_IDENTIFIER'] == bundle_id
    settings['CODE_SIGN_STYLE'] = 'Manual'
    settings['DEVELOPMENT_TEAM'] = state.fetch('team_id')
    settings['CODE_SIGN_IDENTITY'] = state.fetch('identity_sha1')
    settings['CODE_SIGN_IDENTITY[sdk=iphoneos*]'] = state.fetch('identity_sha1')
    settings['PROVISIONING_PROFILE_SPECIFIER'] = profile.fetch('profile_uuid')
  end
end
project.save
puts 'Configured app and workout widget signing for this CI checkout.'
