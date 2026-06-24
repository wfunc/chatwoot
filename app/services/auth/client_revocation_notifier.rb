class Auth::ClientRevocationNotifier
  EVENT = 'auth.client.revoked'.freeze

  pattr_initialize [:user!, :clients!, { reason: 'client_limit_exceeded' }]

  def self.call(user, clients, reason: 'client_limit_exceeded')
    new(user: user, clients: clients, reason: reason).call
  end

  def call
    Array(clients).compact_blank.uniq.each do |client|
      ActionCable.server.broadcast(stream_name(user.id, client), payload)
    end
  end

  def self.stream_name(user_id, client)
    "user_#{user_id}_auth_client_#{client}"
  end

  private

  def stream_name(user_id, client)
    self.class.stream_name(user_id, client)
  end

  def payload
    {
      event: EVENT,
      data: {
        reason: reason
      }
    }
  end
end
