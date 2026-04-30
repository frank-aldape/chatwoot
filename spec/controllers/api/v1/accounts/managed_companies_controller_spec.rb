require 'rails_helper'

RSpec.describe 'Managed Companies API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }

  describe 'POST /api/v1/accounts/{account.id}/managed_companies' do
    it 'creates a managed company with an authorized domain' do
      post "/api/v1/accounts/#{account.id}/managed_companies",
           params: {
             managed_company: {
               name: 'ACME',
               authorized_domain: 'acme.com',
               status: 'active'
             }
           },
           headers: administrator.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['authorized_domain']).to eq('acme.com')
      expect(response.parsed_body['status']).to eq('active')
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/managed_companies/:id' do
    let(:managed_company) { create(:managed_company, account: account, status: :inactive, authorized_domain: 'old.com') }

    it 'updates the stored authorized domain and status' do
      patch "/api/v1/accounts/#{account.id}/managed_companies/#{managed_company.id}",
            params: {
              managed_company: {
                authorized_domain: 'new.com',
                status: 'active'
              }
            },
            headers: administrator.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(managed_company.reload.authorized_domain).to eq('new.com')
      expect(managed_company.status).to eq('active')
    end
  end
end
