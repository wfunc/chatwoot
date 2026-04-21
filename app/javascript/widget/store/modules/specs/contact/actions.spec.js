import { API } from 'widget/helpers/axios';
import { sendMessage } from 'widget/helpers/utils';
import ActionCableConnector from 'widget/helpers/actionCable';
import { actions } from '../../contacts';

const commit = vi.fn();
const dispatch = vi.fn();

vi.mock('widget/helpers/axios');
vi.mock('widget/helpers/utils', () => ({
  sendMessage: vi.fn(),
}));
vi.mock('widget/helpers/actionCable', () => ({
  default: {
    refreshConnector: vi.fn(),
  },
}));

beforeEach(() => {
  vi.clearAllMocks();
});

describe('#actions', () => {
  describe('#setUser', () => {
    it('sends correct actions if contact object is refreshed ', async () => {
      const user = {
        email: 'thoma@sphadikam.com',
        name: 'Adu Thoma',
        avatar_url: '',
      };
      vi.spyOn(API, 'patch').mockResolvedValue({
        data: { widget_auth_token: 'token', pubsub_token: 'pubsub-token' },
      });
      await actions.setUser({ commit, dispatch }, { identifier: 1, user });
      expect(sendMessage.mock.calls).toEqual([
        [{ data: { widgetAuthToken: 'token' }, event: 'setAuthCookie' }],
      ]);
      expect(ActionCableConnector.refreshConnector).toHaveBeenCalledWith(
        'pubsub-token'
      );
      expect(commit.mock.calls).toEqual([]);
      expect(dispatch.mock.calls).toEqual([
        ['get'],
        ['conversation/clearConversations', {}, { root: true }],
        ['conversation/fetchOldConversations', {}, { root: true }],
        ['conversationAttributes/getAttributes', {}, { root: true }],
      ]);
    });

    it('sends correct actions if identifierHash is passed ', async () => {
      const user = {
        email: 'thoma@sphadikam.com',
        name: 'Adu Thoma',
        avatar_url: '',
        identifier_hash: '12345',
      };
      vi.spyOn(API, 'patch').mockResolvedValue({ data: { id: 1 } });
      await actions.setUser({ commit, dispatch }, { identifier: 1, user });
      expect(sendMessage.mock.calls).toEqual([]);
      expect(ActionCableConnector.refreshConnector).not.toHaveBeenCalled();
      expect(commit.mock.calls).toEqual([]);
      expect(dispatch.mock.calls).toEqual([
        ['get'],
        ['conversation/clearConversations', {}, { root: true }],
        ['conversation/fetchOldConversations', {}, { root: true }],
        ['conversationAttributes/getAttributes', {}, { root: true }],
      ]);
    });

    it('does not call sendMessage if contact object is not refreshed ', async () => {
      const user = {
        email: 'thoma@sphadikam.com',
        name: 'Adu Thoma',
        avatar_url: '',
      };
      API.patch.mockResolvedValue({ data: { id: 1 } });
      await actions.setUser({ commit, dispatch }, { identifier: 1, user });
      expect(sendMessage.mock.calls).toEqual([]);
      expect(ActionCableConnector.refreshConnector).not.toHaveBeenCalled();
      expect(commit.mock.calls).toEqual([]);
      expect(dispatch.mock.calls).toEqual([['get']]);
    });
  });

  describe('#update', () => {
    it('sends correct actions', async () => {
      const user = {
        email: 'thoma@sphadikam.com',
        name: 'Adu Thoma',
        avatar_url: '',
        identifier_hash: 'random_hex_identifier_hash',
      };
      API.patch.mockResolvedValue({ data: { id: 1 } });
      await actions.update({ commit, dispatch }, { identifier: 1, user });
      expect(commit.mock.calls).toEqual([]);
      expect(dispatch.mock.calls).toEqual([['get']]);
    });
  });
});
