import { frontendURL } from '../../../../helper/URLHelper';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

const meta = {
  featureFlag: FEATURE_FLAGS.REPORTS,
  permissions: ['administrator', 'report_manage'],
};

const revisedReportRoutes = [
  {
    path: 'agents_overview',
    name: 'agent_reports_index',
    meta: {
      permissions: ['administrator', 'report_manage'],
    },
    component: () => import('./AgentReportsIndex.vue'),
  },
  {
    path: 'agents/:id',
    name: 'agent_reports_show',
    meta: {
      permissions: ['administrator', 'report_manage'],
    },
    component: () => import('./AgentReportsShow.vue'),
  },

  {
    path: 'inboxes_overview',
    name: 'inbox_reports_index',
    meta: {
      permissions: ['administrator', 'report_manage'],
    },
    component: () => import('./InboxReportsIndex.vue'),
  },
  {
    path: 'inboxes/:id',
    name: 'inbox_reports_show',
    meta: {
      permissions: ['administrator', 'report_manage'],
    },
    component: () => import('./InboxReportsShow.vue'),
  },
  {
    path: 'teams_overview',
    name: 'team_reports_index',
    meta: {
      permissions: ['administrator', 'report_manage'],
    },
    component: () => import('./TeamReportsIndex.vue'),
  },
  {
    path: 'teams/:id',
    name: 'team_reports_show',
    meta: {
      permissions: ['administrator', 'report_manage'],
    },
    component: () => import('./TeamReportsShow.vue'),
  },
  {
    path: 'labels_overview',
    name: 'label_reports_index',
    meta: {
      permissions: ['administrator', 'report_manage'],
    },
    component: () => import('./LabelReportsIndex.vue'),
  },
  {
    path: 'labels/:id',
    name: 'label_reports_show',
    meta: {
      permissions: ['administrator', 'report_manage'],
    },
    component: () => import('./LabelReportsShow.vue'),
  },
];

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/reports'),
      component: () => import('./components/ReportsWrapper.vue'),
      children: [
        {
          path: '',
          redirect: to => {
            return { name: 'account_overview_reports', params: to.params };
          },
        },
        {
          path: 'overview',
          name: 'account_overview_reports',
          meta,
          component: () => import('./LiveReports.vue'),
        },
        {
          path: 'conversation',
          name: 'conversation_reports',
          meta,
          component: () => import('./Index.vue'),
        },
        ...revisedReportRoutes,
        {
          path: 'sla',
          name: 'sla_reports',
          meta,
          component: () => import('./SLAReports.vue'),
        },
        {
          path: 'csat',
          name: 'csat_reports',
          meta,
          component: () => import('./CsatResponses.vue'),
        },
        {
          path: 'bot',
          name: 'bot_reports',
          meta,
          component: () => import('./BotReports.vue'),
        },
      ],
    },
  ],
};
