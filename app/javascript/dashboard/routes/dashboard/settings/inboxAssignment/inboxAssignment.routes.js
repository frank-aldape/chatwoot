import { frontendURL } from '../../../../helper/URLHelper';

import Index from './Index.vue';
import SettingsWrapper from '../SettingsWrapper.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/inbox-assignment'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'settings_inbox_assignment_list',
          component: Index,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
