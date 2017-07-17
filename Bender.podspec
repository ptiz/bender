##
#

Pod::Spec.new do |s|

  s.name         = "Bender"
  s.version      = "1.5.2"
  s.summary      = "JSON declarative validating and binding library written in Swift"
  s.description  = "A declarative JSON mapping library which does not pollute your models with ridiculous initializers and stuff. Describes JSON for your classes, does not dress your classes for JSON. Swift 3 ready."
  s.homepage     = "https://github.com/ptiz/bender"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { "Evgeny Kamyshanov" => "ptiz@live.ru" }
  s.platform     = :ios, :osx

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.9"
  # s.watchos.deployment_target = "2.0"
  # s.tvos.deployment_target = "9.0"

  s.source       = { :git => "https://github.com/ptiz/bender.git", :tag => "1.5.2" }
  s.source_files  = "Bender", "Bender/**/*.{swift}"

end
