require 'bundler/setup'
require 'logger'
require 'erb'
require 'ostruct'
require 'json'
require 'mail'

RECEIVER = String(ENV["WIKI_UPDATE_RECEIVER_EMAIL"])

if RECEIVER.empty?
  raise "WIKI_UPDATE_RECEIVER_EMAIL must be specified!"
end

SENDER = String(ENV["WIKI_UPDATE_SENDER_EMAIL"])

if SENDER.empty?
  raise "WIKI_UPDATE_SENDER_EMAIL must be specified!"
end

Mail.defaults do
  delivery_method :smtp, { address:   'smtp.sendgrid.net',
                           port:      587,
                           domain:    'heroku.com',
                           user_name: ENV['SENDGRID_USERNAME'],
                           password:  ENV['SENDGRID_PASSWORD'],
                           authentication: :plain,
                           enable_starttls_auto: true }
end

log = Logger.new(STDOUT)

class ErbTpl < OpenStruct
  def render(tpl); ERB.new(tpl).result(binding); end
end

TEMPLATE = <<-TPL
<html>
<body>
  <h1>
    The following WIKI pages have been updated in the <%= repo %> repo:
  </h1>
  <ul>
  <% updates.each do |title, url| %>
    <li><a href="<%= url %>"><%= title %></a></li>
  <% end %>
  </ul>
</body>
</html>
TPL

app = proc do |env|
  log.debug(env)

  if env['HTTP_USER_AGENT'] !~ /^GitHub-Hookshot/
    log.debug('Not github. Rejecting.')
    return [403, { 'Content-Type' => 'text/plain' }, ['Nope.']]
  end

  req = Rack::Request.new(env)
  request_data = JSON.parse(req.body.read)

  result = { repo: Hash(request_data['repository']).fetch('name'), updates: {} }
  Array(request_data['pages']).each_with_object(result[:updates]) do |page, result|
    result[page.fetch('title')] = page.fetch('html_url')
  end

  rendered = ErbTpl.new(result).render(TEMPLATE)

  log.debug("Sending email to #{RECEIVER}, content: #{rendered}")

  Mail.deliver do
    to      RECEIVER
    from    SENDER
    subject "#{result[:repo]} wiki has been updated!"

    text_part do
      body rendered
    end

    html_part do
      content_type 'text/html; charset=UTF-8'
      body rendered
    end
  end

  [200, { 'Content-Type' => 'text/plain' }, ['ok']]
end

run app
