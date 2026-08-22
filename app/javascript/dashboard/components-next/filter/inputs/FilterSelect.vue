<script setup>
import { computed, ref } from 'vue';
import { useElementBounding, useWindowSize } from '@vueuse/core';
import DropdownContainer from 'next/dropdown-menu/base/DropdownContainer.vue';
import DropdownSection from 'next/dropdown-menu/base/DropdownSection.vue';
import DropdownBody from 'next/dropdown-menu/base/DropdownBody.vue';
import DropdownItem from 'next/dropdown-menu/base/DropdownItem.vue';

import Button from 'next/button/Button.vue';

// [{label, icon, value}]
const props = defineProps({
  options: {
    type: Array,
    required: true,
  },
  hideLabel: {
    type: Boolean,
    default: false,
  },
  hideIcon: {
    type: Boolean,
    default: false,
  },
  variant: {
    type: String,
    default: 'faded',
  },
  label: {
    type: String,
    default: null,
  },
  // Shows a search box above the options. Use it when the list is long enough
  // that scanning it is slower than typing.
  searchable: {
    type: Boolean,
    default: false,
  },
  searchPlaceholder: {
    type: String,
    default: '',
  },
});

const selected = defineModel({
  type: [String, Number],
  required: true,
});

const triggerRef = ref(null);
const dropdownRef = ref(null);

const { top } = useElementBounding(triggerRef);
const { height } = useWindowSize();
const { height: dropdownHeight } = useElementBounding(dropdownRef);

const selectedOption = computed(() => {
  return props.options.find(o => o.value === selected.value) || {};
});

const iconToRender = computed(() => {
  if (props.hideIcon) return null;
  return selectedOption.value.icon || 'i-lucide-chevron-down';
});

const dropdownPosition = computed(() => {
  const DROPDOWN_MAX_HEIGHT = 340;
  // Get actual height if available or use default
  const menuHeight = dropdownHeight.value
    ? dropdownHeight.value + 20
    : DROPDOWN_MAX_HEIGHT;
  const spaceBelow = height.value - top.value;
  return spaceBelow < menuHeight ? 'bottom-0' : 'top-0';
});

const searchQuery = ref('');

const filteredOptions = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();
  if (!query) return props.options;
  return props.options.filter(option =>
    (option.label || '').toLowerCase().includes(query)
  );
});

// Options carrying a `group` are rendered under a section heading, so related
// attributes stay together instead of forming one long flat list.
const optionGroups = computed(() => {
  const groups = new Map();
  filteredOptions.value.forEach(option => {
    const title = option.group || '';
    if (!groups.has(title)) groups.set(title, []);
    groups.get(title).push(option);
  });
  return Array.from(groups, ([title, options]) => ({ title, options }));
});

const updateSelected = newValue => {
  selected.value = newValue;
  searchQuery.value = '';
};
</script>

<template>
  <DropdownContainer>
    <template #trigger="{ toggle }">
      <slot name="trigger" :toggle="toggle">
        <Button
          ref="triggerRef"
          type="button"
          sm
          slate
          :variant
          :icon="iconToRender"
          :trailing-icon="selectedOption.icon ? false : true"
          :label="label || (hideLabel ? null : selectedOption.label)"
          @click="toggle"
        />
      </slot>
    </template>
    <DropdownBody
      ref="dropdownRef"
      class="min-w-48 z-50"
      :class="dropdownPosition"
      strong
    >
      <div v-if="searchable" class="px-2 pt-1 pb-2">
        <div
          class="flex h-8 items-center gap-2 rounded-lg bg-n-alpha-black2 px-2 text-n-slate-11 outline outline-1 outline-n-weak focus-within:outline-n-brand"
        >
          <span class="i-lucide-search size-3.5 flex-shrink-0" />
          <input
            v-model="searchQuery"
            type="search"
            class="reset-base min-w-0 flex-1 appearance-none border-0 bg-transparent p-0 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-10 focus:border-0 focus:outline-none focus:ring-0"
            :placeholder="searchPlaceholder"
            :aria-label="searchPlaceholder"
          />
        </div>
      </div>
      <DropdownSection
        v-for="group in optionGroups"
        :key="group.title"
        :title="group.title"
        class="[&>ul]:max-h-80"
      >
        <DropdownItem
          v-for="option in group.options"
          :key="option.value"
          :label="option.label"
          :icon="option.icon"
          @click="updateSelected(option.value)"
        />
      </DropdownSection>
    </DropdownBody>
  </DropdownContainer>
</template>
