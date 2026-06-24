/* global axios */

import ApiClient from './ApiClient';

class Agents extends ApiClient {
  constructor() {
    super('agents', { accountScoped: true });
  }

  bulkInvite({ emails }) {
    return axios.post(`${this.url}/bulk_create`, {
      emails,
    });
  }

  getActiveClients(id) {
    return axios.get(`${this.url}/${id}/active_clients`);
  }

  deleteActiveClient(id, clientId) {
    return axios.delete(
      `${this.url}/${id}/active_clients/${encodeURIComponent(clientId)}`
    );
  }
}

export default new Agents();
