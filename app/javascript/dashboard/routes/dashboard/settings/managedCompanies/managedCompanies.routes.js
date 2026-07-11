import { frontendURL } from '../../../../helper/URLHelper';
import { ROLES } from 'dashboard/constants/permissions.js';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/managed-companies'),
      component: () => import('../SettingsWrapper.vue'),
      children: [
        {
          path: '',
          name: 'settings_managed_companies_list',
          component: () => import('./Index.vue'),
          meta: {
            // Agents get read-only access (Index.vue hides create/edit/delete
            // for non-administrators) so they can look up a company's
            // authorized_domain without needing admin rights.
            permissions: [...ROLES],
          },
        },
      ],
    },
  ],
};
