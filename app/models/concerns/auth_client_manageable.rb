# frozen_string_literal: true

module AuthClientManageable
  extend ActiveSupport::Concern

  prepended do
    attr_reader :revoked_auth_clients

    validates :max_active_clients,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 1,
                less_than_or_equal_to: DeviseTokenAuth.max_number_of_devices
              },
              allow_nil: true
  end

  def active_client_limit
    max_active_clients.presence || DeviseTokenAuth.max_number_of_devices
  end

  def create_token(client: nil, lifespan: nil, cost: nil, **token_extras)
    now = Time.current.to_f
    self.tokens ||= {}
    existing_token_data = client.present? ? tokens[client] : nil
    token_extras[:created_at] ||= token_value(existing_token_data || {}, :created_at) || now
    token_extras[:last_seen_at] ||= now

    super(client: client, lifespan: lifespan, cost: cost, **token_extras)
  end

  def active_auth_clients
    sorted_auth_tokens.filter_map { |client, token_data| auth_client_payload(client, token_data) unless auth_token_expired?(token_data) }
  end

  def touch_auth_client!(client, request)
    return if client.blank?

    with_lock do
      token_data = tokens&.[](client)
      next if token_data.blank? || auth_client_touched_recently?(token_data)

      touch_auth_client_token(token_data, request)
      save!(validate: false)
    end
  end

  def revoke_auth_client!(client)
    return [] if client.blank?

    revoked_clients = []
    with_lock do
      if tokens.present? && tokens[client].present?
        tokens.delete(client)
        tokens_will_change!
        revoked_clients << client
        save!(validate: false)
      end
    end

    Auth::ClientRevocationNotifier.call(self, revoked_clients, reason: 'manual_revocation')
    revoked_clients
  end

  def prune_auth_clients_to_limit!
    with_lock do
      clean_old_tokens
      save!(validate: false) if changed? || revoked_auth_clients.present?
    end

    flush_revoked_auth_clients
  end

  def flush_revoked_auth_clients
    clients = Array(@revoked_auth_clients).uniq
    @revoked_auth_clients = []
    clients
  end

  protected

  def max_client_tokens_exceeded?
    tokens.length > active_client_limit
  end

  def clean_old_tokens
    return if tokens.blank? || !max_client_tokens_exceeded?

    self.tokens = sorted_auth_tokens.to_h
    @revoked_auth_clients ||= []
    @revoked_auth_clients << tokens.shift.first while max_client_tokens_exceeded?
    tokens_will_change!
  end

  private

  def sorted_auth_tokens
    return {} if tokens.blank?

    tokens.sort_by { |_client, token_data| auth_token_sort_key(token_data) }.to_h
  end

  def auth_client_payload(client, token_data)
    {
      client: client,
      created_at: token_timestamp(token_data, :created_at),
      last_seen_at: token_timestamp(token_data, :last_seen_at),
      ip: token_value(token_data, :ip),
      user_agent: token_value(token_data, :user_agent)
    }
  end

  def auth_token_expired?(token_data)
    expiry = token_timestamp(token_data, :expiry)
    expiry.present? && Time.zone.at(expiry) < Time.current
  end

  def auth_token_sort_key(token_data)
    [
      token_timestamp(token_data, :created_at) || token_timestamp(token_data, :expiry) || 0,
      token_timestamp(token_data, :expiry) || 0
    ]
  end

  def auth_client_touched_recently?(token_data)
    token_timestamp(token_data, :last_seen_at).to_f > 5.minutes.ago.to_f
  end

  def touch_auth_client_token(token_data, request)
    token_data['last_seen_at'] = Time.current.to_f
    token_data['ip'] = request.remote_ip if request.remote_ip.present?
    token_data['user_agent'] = request.user_agent.to_s.first(255) if request.user_agent.present?
    tokens_will_change!
  end

  def token_timestamp(token_data, key)
    token_value(token_data, key)&.to_f
  end

  def token_value(token_data, key)
    token_data[key.to_s] || token_data[key]
  end
end
