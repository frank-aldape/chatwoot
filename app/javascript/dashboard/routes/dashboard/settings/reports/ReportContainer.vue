<script>
import { mapGetters } from 'vuex';
import { useReportMetrics } from 'dashboard/composables/useReportMetrics';
import { GROUP_BY_FILTER, METRIC_CHART } from './constants';
import { getChartSeriesColors } from 'dashboard/helper/chartColors';
import fromUnixTime from 'date-fns/fromUnixTime';
import format from 'date-fns/format';
import { formatTime } from '@chatwoot/utils';
import ChartStats from './components/ChartElements/ChartStats.vue';
import BarChart from 'shared/components/charts/BarChart.vue';
import Skeleton from 'dashboard/components-next/skeleton/Skeleton.vue';

export default {
  components: { ChartStats, BarChart, Skeleton },
  props: {
    groupBy: {
      type: Object,
      default: () => ({}),
    },
    accountSummaryKey: {
      type: String,
      default: 'getAccountSummary',
    },
    summaryFetchingKey: {
      type: String,
      default: 'getAccountSummaryFetchingStatus',
    },
    reportKeys: {
      type: Object,
      default: () => ({
        CONVERSATIONS: 'conversations_count',
        INCOMING_MESSAGES: 'incoming_messages_count',
        OUTGOING_MESSAGES: 'outgoing_messages_count',
        FIRST_RESPONSE_TIME: 'avg_first_response_time',
        RESOLUTION_TIME: 'avg_resolution_time',
        RESOLUTION_COUNT: 'resolutions_count',
        REPLY_TIME: 'reply_time',
      }),
    },
  },
  setup(props) {
    const { calculateTrend, isAverageMetricType } = useReportMetrics(
      props.accountSummaryKey
    );
    return { calculateTrend, isAverageMetricType };
  },
  computed: {
    ...mapGetters({
      accountReport: 'getAccountReports',
    }),
    metrics() {
      const reportKeys = Object.keys(this.reportKeys);
      const infoText = {
        FIRST_RESPONSE_TIME: this.$t(
          `REPORT.METRICS.FIRST_RESPONSE_TIME.INFO_TEXT`
        ),
        RESOLUTION_TIME: this.$t(`REPORT.METRICS.RESOLUTION_TIME.INFO_TEXT`),
      };
      return reportKeys.map(key => ({
        NAME: this.$t(`REPORT.METRICS.${key}.NAME`),
        KEY: this.reportKeys[key],
        DESC: this.$t(`REPORT.METRICS.${key}.DESC`),
        INFO_TEXT: infoText[key],
        TOOLTIP_TEXT: `REPORT.METRICS.${key}.TOOLTIP_TEXT`,
        trend: this.calculateTrend(this.reportKeys[key]),
      }));
    },
  },
  methods: {
    getCollection(metric) {
      if (!this.accountReport.data[metric.KEY]) {
        return {};
      }
      const data = this.accountReport.data[metric.KEY];
      const labels = data.map(element => {
        if (this.groupBy?.period === GROUP_BY_FILTER[2].period) {
          let week_date = new Date(fromUnixTime(element.timestamp));
          const first_day = week_date.getDate() - week_date.getDay();
          const last_day = first_day + 6;
          const week_first_date = new Date(week_date.setDate(first_day));
          const week_last_date = new Date(week_date.setDate(last_day));
          return `${format(week_first_date, 'dd-MMM')} - ${format(
            week_last_date,
            'dd-MMM'
          )}`;
        }
        if (this.groupBy?.period === GROUP_BY_FILTER[3].period) {
          return format(fromUnixTime(element.timestamp), 'MMM-yyyy');
        }
        if (this.groupBy?.period === GROUP_BY_FILTER[4].period) {
          return format(fromUnixTime(element.timestamp), 'yyyy');
        }
        return format(fromUnixTime(element.timestamp), 'dd-MMM');
      });
      const seriesColors = getChartSeriesColors();
      const datasets = METRIC_CHART[metric.KEY].datasets.map(dataset => {
        switch (dataset.type) {
          case 'bar':
            return {
              ...dataset,
              backgroundColor: seriesColors.bar,
              yAxisID: 'y',
              label: metric.NAME,
              data: data.map(element => element.value),
            };
          case 'line':
            return {
              ...dataset,
              borderColor: seriesColors.line,
              pointBackgroundColor: seriesColors.point,
              yAxisID: 'y',
              label: this.metrics[0].NAME,
              data: data.map(element => element.count),
            };
          default:
            return dataset;
        }
      });
      return {
        labels,
        datasets,
      };
    },
    getChartOptions(metric) {
      const options = {
        scales: METRIC_CHART[metric.KEY].scales,
      };

      // Only add tooltip configuration for time-based metrics
      if (this.isAverageMetricType(metric.KEY)) {
        options.plugins = {
          tooltip: {
            callbacks: {
              label: ({ raw, dataIndex }) => {
                return this.$t(metric.TOOLTIP_TEXT, {
                  metricValue: formatTime(raw || 0),
                  conversationCount:
                    this.accountReport.data[metric.KEY][dataIndex]?.count || 0,
                });
              },
            },
          },
        };
      }

      return options;
    },
  },
};
</script>

<template>
  <div
    class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-2 px-6 py-5 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
  >
    <div
      v-for="metric in metrics"
      :key="metric.KEY"
      class="p-4 mb-3 rounded-md"
    >
      <ChartStats
        :metric="metric"
        :account-summary-key="accountSummaryKey"
        :summary-fetching-key="summaryFetchingKey"
      />
      <div class="mt-4 h-72">
        <div
          v-if="accountReport.isFetching[metric.KEY]"
          class="flex items-end h-full gap-2 px-1 pb-1"
          aria-hidden="true"
        >
          <Skeleton width="w-full" height="h-24" rounded="rounded-t-md" />
          <Skeleton width="w-full" height="h-40" rounded="rounded-t-md" />
          <Skeleton width="w-full" height="h-32" rounded="rounded-t-md" />
          <Skeleton width="w-full" height="h-52" rounded="rounded-t-md" />
          <Skeleton width="w-full" height="h-36" rounded="rounded-t-md" />
          <Skeleton width="w-full" height="h-44" rounded="rounded-t-md" />
          <Skeleton width="w-full" height="h-28" rounded="rounded-t-md" />
        </div>
        <div v-else class="flex items-center justify-center h-72">
          <BarChart
            v-if="accountReport.data[metric.KEY].length"
            :collection="getCollection(metric)"
            :chart-options="getChartOptions(metric)"
          />
          <span v-else class="text-sm text-n-slate-10">
            {{ $t('REPORT.NO_ENOUGH_DATA') }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>
