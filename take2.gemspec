require File.expand_path("../lib/newgem/version", __FILE__)

Gem::Specification.new do |s|
  s.name        = "take2"
  s.version     = Take2::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Anton Magids"]
  s.email       = ["evnomadx@gmail.com"]
  s.homepage    = "https://github.com/restaurant-cheetah/take2"
  s.summary     = "Provides Take2 for your APIs calls"
  s.description = "Easily define Take2 / retry behavior for API wrappers, service objects or a single method."

   s.post_install_message = "Getting Take2 is dead easy!"

  all_files = `git ls-files`.split("\n")
  test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  
  s.files         = all_files - test_files
  s.test_files    = test_files
  s.require_paths = ['lib']
end