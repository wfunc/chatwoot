json.array! @active_clients do |client|
  json.client client[:client]
  json.created_at client[:created_at]
  json.last_seen_at client[:last_seen_at]
  json.ip client[:ip]
  json.user_agent client[:user_agent]
end
