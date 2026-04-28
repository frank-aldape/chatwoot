import { computed, ref } from 'vue';

export const useSettingsSearchState = ({ sourceRecords, filteredRecords }) => {
  const searchQuery = ref('');

  const hasActiveSearch = computed(() => searchQuery.value.trim().length > 0);
  const hasRecords = computed(() => (sourceRecords.value || []).length > 0);

  const showNoRecordsFound = computed(
    () => !hasRecords.value && !hasActiveSearch.value
  );

  const showEmptySearchResults = computed(
    () => hasActiveSearch.value && (filteredRecords.value || []).length === 0
  );

  return {
    searchQuery,
    hasActiveSearch,
    hasRecords,
    showNoRecordsFound,
    showEmptySearchResults,
  };
};
