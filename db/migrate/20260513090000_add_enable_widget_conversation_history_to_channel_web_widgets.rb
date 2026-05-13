class AddEnableWidgetConversationHistoryToChannelWebWidgets < ActiveRecord::Migration[7.1]
  def change
    add_column :channel_web_widgets, :enable_widget_conversation_history, :boolean, default: false, null: false
  end
end
