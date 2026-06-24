json.id resource.id
json.account_user_id resource.current_account_user&.id
# could be nil for a deleted agent hence the safe operator before account id
json.account_id Current.account&.id
json.availability_status resource.availability_status
json.auto_offline resource.auto_offline
json.confirmed resource.confirmed?
json.email resource.email
json.provider resource.provider
json.available_name resource.available_name
json.custom_attributes resource.custom_attributes if resource.custom_attributes.present?
json.name resource.name
json.role resource.role
json.thumbnail resource.avatar_url
json.merchant_status resource.current_account_user&.merchant_status
json.merchant_expires_at resource.current_account_user&.merchant_expires_at
json.agent_limit resource.current_account_user&.agent_limit
json.max_active_clients resource.max_active_clients
json.parent_merchant_id resource.current_account_user&.parent_merchant_id
json.custom_role_id resource.current_account_user&.custom_role_id if ChatwootApp.enterprise?
