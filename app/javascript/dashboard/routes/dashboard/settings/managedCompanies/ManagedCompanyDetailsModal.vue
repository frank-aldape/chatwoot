<script setup>
import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  managedCompany: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['close']);

const handleClose = () => {
  emit('close');
};
</script>

<template>
  <woot-modal :show="show" :on-close="handleClose">
    <div class="flex flex-col w-full max-w-3xl p-6">
      <woot-modal-header
        :header-title="$t('MANAGED_COMPANIES_SETTINGS.DETAILS.TITLE')"
      />

      <div class="grid gap-6">
        <div class="grid gap-1">
          <span class="text-sm text-n-slate-11">
            {{ $t('MANAGED_COMPANIES_SETTINGS.TABLE.COMPANY') }}
          </span>
          <span class="text-lg font-medium text-n-slate-12">
            {{ managedCompany.name }}
          </span>
          <span class="text-sm text-n-slate-11">
            {{ managedCompany.authorized_domain }}
          </span>
        </div>

        <div class="grid gap-2">
          <div class="flex items-center justify-between gap-3">
            <span class="text-sm font-medium text-n-slate-12">
              {{ $t('MANAGED_COMPANIES_SETTINGS.LIST.INBOXES_LABEL') }}
            </span>
            <span class="text-xs text-n-slate-11">
              {{
                $t('MANAGED_COMPANIES_SETTINGS.LIST.INBOX_COUNT', {
                  count: managedCompany.inbox_ids?.length || 0,
                })
              }}
            </span>
          </div>
          <div
            v-if="managedCompany.inboxNames?.length"
            class="flex flex-wrap gap-2"
          >
            <span
              v-for="inboxName in managedCompany.inboxNames"
              :key="inboxName"
              class="rounded-full bg-n-alpha-2 px-2 py-1 text-xs text-n-slate-12"
            >
              {{ inboxName }}
            </span>
          </div>
          <p v-else class="mb-0 text-sm text-n-slate-11">
            {{ $t('MANAGED_COMPANIES_SETTINGS.LIST.NO_INBOXES_ASSIGNED') }}
          </p>
        </div>

        <div class="grid gap-2">
          <div class="flex items-center justify-between gap-3">
            <span class="text-sm font-medium text-n-slate-12">
              {{ $t('MANAGED_COMPANIES_SETTINGS.LIST.TEAMS_LABEL') }}
            </span>
            <span class="text-xs text-n-slate-11">
              {{
                $t('MANAGED_COMPANIES_SETTINGS.LIST.TEAM_COUNT', {
                  count: managedCompany.team_ids?.length || 0,
                })
              }}
            </span>
          </div>
          <div
            v-if="managedCompany.teamNames?.length"
            class="flex flex-wrap gap-2"
          >
            <span
              v-for="teamName in managedCompany.teamNames"
              :key="teamName"
              class="rounded-full bg-n-alpha-2 px-2 py-1 text-xs text-n-slate-12"
            >
              {{ teamName }}
            </span>
          </div>
          <p v-else class="mb-0 text-sm text-n-slate-11">
            {{ $t('MANAGED_COMPANIES_SETTINGS.LIST.NO_TEAMS_ASSIGNED') }}
          </p>
        </div>

        <div class="flex justify-end pt-2">
          <Button
            slate
            :label="$t('MANAGED_COMPANIES_SETTINGS.DETAILS.CLOSE')"
            @click="handleClose"
          />
        </div>
      </div>
    </div>
  </woot-modal>
</template>
