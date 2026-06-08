class AddWidgetConversationHistoryRetentionToChannelWebWidgets < ActiveRecord::Migration[7.1]
  def up
    add_column :channel_web_widgets, :widget_conversation_history_retention, :integer, default: 0, null: false

    execute <<~SQL.squish
      UPDATE channel_web_widgets
      SET widget_conversation_history_retention = 10000
      WHERE enable_widget_conversation_history = TRUE
    SQL
  end

  def down
    remove_column :channel_web_widgets, :widget_conversation_history_retention
  end
end
