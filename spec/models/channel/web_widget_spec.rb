# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Channel::WebWidget do
  context 'when
  web widget channel' do
    let!(:channel_widget) { create(:channel_widget) }

    it 'pre chat options' do
      expect(channel_widget.pre_chat_form_options['pre_chat_message']).to eq 'Share your queries or comments here.'
      expect(channel_widget.pre_chat_form_options['pre_chat_fields'].length).to eq 3
    end

    it 'keeps legacy widget conversation history flag in sync with retention' do
      channel_widget.update!(widget_conversation_history_retention: :forever)
      expect(channel_widget.enable_widget_conversation_history).to be true

      channel_widget.update!(widget_conversation_history_retention: :none)
      expect(channel_widget.enable_widget_conversation_history).to be false
    end

    it 'maps legacy widget conversation history flag to retention' do
      channel_widget.update!(enable_widget_conversation_history: true)
      expect(channel_widget.widget_conversation_history_retention).to eq 'forever'

      channel_widget.update!(enable_widget_conversation_history: false)
      expect(channel_widget.widget_conversation_history_retention).to eq 'none'
    end

    it 'returns calendar-day retention boundaries for widget conversation history' do
      travel_to Time.zone.parse('2026-06-08 10:00:00') do
        channel_widget.update!(widget_conversation_history_retention: :none)
        expect(channel_widget.widget_conversation_history_since).to be_nil

        channel_widget.update!(widget_conversation_history_retention: :forever)
        expect(channel_widget.widget_conversation_history_since).to be_nil

        channel_widget.update!(widget_conversation_history_retention: :one_day)
        expect(channel_widget.widget_conversation_history_since).to eq Time.zone.parse('2026-06-08 00:00:00')

        channel_widget.update!(widget_conversation_history_retention: :three_days)
        expect(channel_widget.widget_conversation_history_since).to eq Time.zone.parse('2026-06-06 00:00:00')

        channel_widget.update!(widget_conversation_history_retention: :seven_days)
        expect(channel_widget.widget_conversation_history_since).to eq Time.zone.parse('2026-06-02 00:00:00')
      end
    end
  end
end
