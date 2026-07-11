import { frontendURL } from '../../../../helper/URLHelper';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/inbox-assignment'),
      component: () => import('../SettingsWrapper.vue'),
      children: [
        {
          path: '',
          name: 'settings_inbox_assignment_list',
          component: () => import('./Index.vue'),
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
