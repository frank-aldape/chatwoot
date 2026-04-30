import ApiClient from './ApiClient';

class ManagedCompaniesAPI extends ApiClient {
  constructor() {
    super('managed_companies', { accountScoped: true });
  }
}

export default new ManagedCompaniesAPI();
