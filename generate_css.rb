require 'rouge'

formatter = Rouge::Formatters::HTML.new
theme = Rouge::Themes::Github.render(scope: '.highlight')

File.open('github.css', 'w') do |file|
  file.write(theme)
end