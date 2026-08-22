<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useConversationFilterContext } from './provider.js';

import ActiveFilterPreview from './ActiveFilterPreview.vue';

defineProps({
  showClearButton: { type: Boolean, default: true },
});

const emit = defineEmits(['clearFilters', 'openFilter']);

const { t } = useI18n();
const { filterTypes } = useConversationFilterContext();

const appliedFilters = useMapGetter('getAppliedConversationFiltersV2');

// Chips show the same wording as the filter form instead of the raw column name.
const attributeLabels = computed(() =>
  Object.fromEntries(
    filterTypes.value.map(({ attributeKey, attributeName }) => [
      attributeKey,
      attributeName,
    ])
  )
);
</script>

<template>
  <ActiveFilterPreview
    :applied-filters="appliedFilters"
    :attribute-labels="attributeLabels"
    :max-visible-filters="2"
    :show-clear-button="showClearButton"
    :more-filters-label="
      t('FILTER.ACTIVE_FILTERS.MORE_FILTERS', {
        count: appliedFilters.length - 2,
      })
    "
    :clear-button-label="t('FILTER.ACTIVE_FILTERS.CLEAR_FILTERS')"
    @open-filter="emit('openFilter')"
    @clear-filters="emit('clearFilters')"
  />
</template>
