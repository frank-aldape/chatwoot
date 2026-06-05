# frozen_string_literal: true

require 'json'
require 'openssl'
require 'resolv'
require 'socket'
require 'timeout'

CONNECT_TIMEOUT_SECONDS = ENV.fetch('EMAIL_DIAGNOSTIC_TIMEOUT_SECONDS', 5).to_i

def tcp_reachable?(host, port)
  Timeout.timeout(CONNECT_TIMEOUT_SECONDS) do
    socket = TCPSocket.new(host, port)
    socket.close
  end
  true
rescue StandardError => e
  e
end

def ssl_result(host, port)
  tcp_socket = nil
  ssl_socket = nil

  Timeout.timeout(CONNECT_TIMEOUT_SECONDS) do
    tcp_socket = TCPSocket.new(host, port)
    context = OpenSSL::SSL::SSLContext.new
    context.verify_mode = OpenSSL::SSL::VERIFY_PEER
    context.set_params
    ssl_socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, context)
    ssl_socket.hostname = host
    ssl_socket.connect
    ssl_socket.post_connection_check(host)
  end

  'ok'
rescue StandardError => e
  "#{e.class}: #{e.message}"
ensure
  ssl_socket&.close
  tcp_socket&.close
end

def host_ips(host)
  Resolv.getaddresses(host)
rescue StandardError
  []
end

def diagnostic_for(channel)
  warnings = []
  imap_host = channel.imap_address.to_s.strip
  smtp_host = channel.smtp_address.to_s.strip

  imap = {
    enabled: channel.imap_enabled?,
    host: imap_host,
    port: channel.imap_port,
    ssl: channel.imap_enable_ssl?,
    login_present: channel.imap_login.present?,
    password_present: channel.imap_password.present?
  }

  if channel.imap_enabled?
    warnings << 'imap host is blank' if imap_host.blank?
    warnings << 'imap port is blank' if channel.imap_port.to_i.zero?
    warnings << 'imap login is blank' if channel.imap_login.blank?
    warnings << 'imap password is blank' if channel.imap_password.blank?

    if imap_host.present?
      imap[:resolved_ips] = host_ips(imap_host)
      warnings << 'imap host does not resolve' if imap[:resolved_ips].empty?
    end

    if imap_host.present? && channel.imap_port.to_i.positive?
      tcp_result = tcp_reachable?(imap_host, channel.imap_port)
      imap[:tcp] = tcp_result == true ? 'ok' : "#{tcp_result.class}: #{tcp_result.message}"
      warnings << "imap tcp failed: #{imap[:tcp]}" unless tcp_result == true

      if channel.imap_enable_ssl?
        imap[:ssl] = ssl_result(imap_host, channel.imap_port)
        warnings << "imap ssl failed: #{imap[:ssl]}" unless imap[:ssl] == 'ok'
      end
    end
  end

  smtp = {
    enabled: channel.smtp_enabled?,
    host: smtp_host,
    port: channel.smtp_port,
    ssl_tls: channel.smtp_enable_ssl_tls?,
    starttls_auto: channel.smtp_enable_starttls_auto?,
    openssl_verify_mode: channel.smtp_openssl_verify_mode,
    login_present: channel.smtp_login.present?,
    password_present: channel.smtp_password.present?
  }

  if channel.smtp_enabled?
    warnings << 'smtp host is blank' if smtp_host.blank?
    warnings << 'smtp port is blank' if channel.smtp_port.to_i.zero?
    warnings << 'smtp login is blank' if channel.smtp_login.blank?
    warnings << 'smtp password is blank' if channel.smtp_password.blank?

    if smtp_host.present?
      smtp[:resolved_ips] = host_ips(smtp_host)
      warnings << 'smtp host does not resolve' if smtp[:resolved_ips].empty?
    end

    if smtp_host.present? && channel.smtp_port.to_i.positive?
      tcp_result = tcp_reachable?(smtp_host, channel.smtp_port)
      smtp[:tcp] = tcp_result == true ? 'ok' : "#{tcp_result.class}: #{tcp_result.message}"
      warnings << "smtp tcp failed: #{smtp[:tcp]}" unless tcp_result == true
    end
  end

  {
    id: channel.id,
    account_id: channel.account_id,
    email: channel.email,
    provider: channel.provider,
    imap: imap,
    smtp: smtp,
    warnings: warnings
  }
end

channels = Channel::Email.where(imap_enabled: true).or(Channel::Email.where(smtp_enabled: true)).order(:id)
results = channels.map { |channel| diagnostic_for(channel) }
problem_channels = results.select { |result| result[:warnings].any? }

puts JSON.pretty_generate(
  generated_at: Time.current.iso8601,
  checked_channels: results.size,
  problem_channels: problem_channels.size,
  results: results
)

exit(problem_channels.empty? ? 0 : 1)
