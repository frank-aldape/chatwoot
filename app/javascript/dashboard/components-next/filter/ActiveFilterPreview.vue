<script setup>
import { useI18n } from 'vue-i18n';
import { replaceUnderscoreWithSpace } from './helper/filterHelper.js';

import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  appliedFilters: { type: Array, default: () => [] },
  maxVisibleFilters: { type: Number, default: 2 },
  clearButtonLabel: { type: String, default: '' },
  moreFiltersLabel: { type: String, default: '' },
  showClearButton: { type: Boolean, default: true },
  // Maps an attributeKey to the human readable name shown in the filter form,
  // so the chip reads the same as the condition the agent built.
  attributeLabels: { type: Object, default: () => ({}) },
});

const emit = defineEmits(['clearFilters', 'openFilter']);

const { t, te } = useI18n();

const shouldCapitalizeFirstLetter = key => {
  const lowercaseKeys = ['email'];
  return !lowercaseKeys.includes(key);
};

const formatAttributeLabel = key =>
  props.attributeLabels[key] || replaceUnderscoreWithSpace(key);

const formatOperatorLabel = operator => {
  const key = `FILTER.OPERATOR_LABELS.${operator}`;
  return te(key) ? t(key) : replaceUnderscoreWithSpace(operator);
};

const formatFilterValue = value => {
  // Case 1: null, undefined, empty string
  if (!value) return '';

  // Case 2: array → map each item, use name if present, else the item itself
  if (Array.isArray(value)) {
    return value.map(item => item?.name ?? item).join(', ');
  }

  // Case 3: object with a "name" property → return name
  // Case 4: primitive (string, number, etc.) → return as is
  return value?.name ?? value;
};
</script>

<template>
  <div class="flex flex-wrap items-center w-full gap-2 mx-auto">
    <template v-for="(filter, index) in appliedFilters" :key="index">
      <div
        v-if="index < maxVisibleFilters"
        class="inline-flex items-center gap-2 h-7"
      >
        <div
          class="flex items-center h-full min-w-0 gap-1 px-2 py-1 text-xs border rounded-lg hover:bg-n-solid-2 max-w-72 border-n-weak hover:cursor-pointer"
          @click="emit('openFilter')"
        >
          <span
            class="lowercase whitespace-nowrap first-letter:capitalize text-n-slate-12"
          >
            {{ formatAttributeLabel(filter.attributeKey) }}
          </span>
          <span class="px-1 text-xs text-n-slate-10 whitespace-nowrap">
            {{ formatOperatorLabel(filter.filterOperator) }}
          </span>
          <span
            v-if="filter.values"
            :title="formatFilterValue(filter.values)"
            class="lowercase truncate text-n-slate-12"
            :class="{
              'first-letter:capitalize': shouldCapitalizeFirstLetter(
                filter.attributeKey
              ),
            }"
          >
            {{ formatFilterValue(filter.values) }}
          </span>
        </div>
        <template
          v-if="
            index < maxVisibleFilters - 1 && index < appliedFilters.length - 1
          "
        >
          <span
            class="content-center h-full px-1 text-xs font-medium uppercase rounded-lg text-n-slate-10"
          >
            {{ filter.queryOperator }}
          </span>
        </template>
      </div>
    </template>
    <div
      v-if="appliedFilters.length > maxVisibleFilters"
      class="inline-flex items-center content-center px-1 text-xs rounded-lg text-n-slate-10 hover:text-n-slate-11 h-7 hover:cursor-pointer"
      @click="emit('openFilter')"
    >
      {{ moreFiltersLabel }}
    </div>
    <div v-if="showClearButton" class="w-px h-3 rounded-lg bg-n-strong" />
    <Button
      v-if="showClearButton"
      :label="clearButtonLabel"
      size="xs"
      class="!px-1"
      variant="ghost"
      @click="emit('clearFilters')"
    />
  </div>
</template>
