import { frontendURL } from '../../../../helper/URLHelper';

import Index from './Index.vue';
import SettingsWrapper from '../SettingsWrapper.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/managed-companies'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'settings_managed_companies_list',
          component: Index,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
