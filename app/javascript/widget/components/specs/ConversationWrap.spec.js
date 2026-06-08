import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import ConversationWrap from '../ConversationWrap.vue';

describe('ConversationWrap', () => {
  const createWrapper = ({ groupedMessages = [] } = {}) => {
    const store = createStore({
      modules: {
        conversation: {
          namespaced: true,
          getters: {
            getEarliestMessage: () => ({}),
            getLastMessage: () => ({}),
            getAllMessagesLoaded: () => true,
            getIsFetchingList: () => false,
            getConversationSize: () => 0,
            getIsAgentTyping: () => false,
          },
          actions: {
            fetchOldConversations: vi.fn(),
          },
        },
        conversationAttributes: {
          namespaced: true,
          getters: {
            getConversationParams: () => ({}),
          },
        },
      },
    });

    return shallowMount(ConversationWrap, {
      global: {
        plugins: [store],
        stubs: {
          ChatMessage: {
            props: ['message'],
            template: '<div class="chat-message">{{ message.content }}</div>',
          },
          DateSeparator: true,
          AgentTypingBubble: true,
          Spinner: true,
        },
      },
      props: {
        groupedMessages,
      },
    });
  };

  beforeEach(() => {
    window.history.pushState({}, '', '/widget?standalone=true');
    window.chatwootWebChannel = {
      greetingEnabled: true,
      greetingMessage: 'Hello! How can we help?',
    };
  });

  afterEach(() => {
    delete window.chatwootWebChannel;
  });

  it('does not render the greeting before the visitor sends a message', () => {
    const wrapper = createWrapper();

    expect(wrapper.text()).not.toContain('Hello! How can we help?');
    expect(wrapper.findAll('.chat-message')).toHaveLength(0);
  });

  it('renders messages from the conversation history', () => {
    const wrapper = createWrapper({
      groupedMessages: [
        {
          date: 'Jun 8, 2026',
          messages: [
            {
              id: 1,
              content: 'Hello! How can we help?',
              created_at: 1780920000,
              message_type: 2,
            },
          ],
        },
      ],
    });

    expect(wrapper.text()).toContain('Hello! How can we help?');
    expect(wrapper.findAll('.chat-message')).toHaveLength(1);
  });
});
