##
#

Pod::Spec.new do |s|

  s.name         = "Bender"
  s.version      = "1.2.0"
  s.summary      = "JSON validating and binding library written in Swift"
  s.description  = "Not just yet another JSON mapping library, but library for validating 
  input by set of recursive rules and binding JSON structures to your models without 
  any additional dependecies."
  s.homepage     = "https://github.com/ptiz/bender"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { "Evgeny Kamyshanov" => "ptiz@live.ru" }
  s.platform     = :ios

  s.ios.deployment_target = "8.0"
  # s.osx.deployment_target = "10.7"
  # s.watchos.deployment_target = "2.0"
  # s.tvos.deployment_target = "9.0"

  s.source       = { :git => "https://github.com/ptiz/bender.git", :tag => "1.2.0" }
  s.source_files  = "Bender", "Bender/**/*.{swift}"

end
